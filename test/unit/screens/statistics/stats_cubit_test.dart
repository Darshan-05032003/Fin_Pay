import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/screens/statistics/stats_cubit.dart';
import 'package:fin_pay/screens/statistics/stats_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock
    implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repo;
  final clock = Clock.fixed(DateTime.utc(2026, 10, 31, 12));
  DateTime utcAsLocal(DateTime utc) =>
      DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute);

  Transaction tx(String id, int paise, DateTime utc) => Transaction(
    id: id,
    title: 'T $id',
    amount: Money.paise(paise),
    date: utc,
    type: paise < 0 ? TransactionType.payment : TransactionType.receiveMoney,
    icon: 'cart',
  );

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() => repo = MockTransactionRepository());

  StatsCubit build() =>
      StatsCubit(repository: repo, clock: clock, toLocal: utcAsLocal);

  void ledger(List<Transaction> rows) {
    when(() => repo.getTransactionsBetween(any(), any())).thenAnswer((
      inv,
    ) async {
      final from = inv.positionalArguments[0] as DateTime;
      final to = inv.positionalArguments[1] as DateTime;
      return Success(
        rows
            .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
            .toList(),
      );
    });
  }

  blocTest<StatsCubit, StatsState>(
    'load asks storage for the week range and summarises',
    build: () {
      ledger([
        tx('a', -1000, DateTime.utc(2026, 10, 31, 8)),
        tx('b', 5000, DateTime.utc(2026, 10, 29, 8)),
        tx('old', -999, DateTime.utc(2026, 10)),
      ]);
      return build();
    },
    act: (c) => c.load(),
    expect: () => [
      const StatsState(),
      isA<StatsState>()
          .having((s) => s.status, 'status', StatsStatus.content)
          .having((s) => s.revision, 'revision', 1)
          .having((s) => s.summary!.count, 'count', 2)
          .having((s) => s.summary!.spend, 'spend', const Money.paise(1000))
          .having((s) => s.summary!.income, 'income', const Money.paise(5000)),
    ],
    verify: (_) => verify(
      () => repo.getTransactionsBetween(
        DateTime.utc(2026, 10, 25),
        DateTime.utc(2026, 11),
      ),
    ).called(1),
  );

  blocTest<StatsCubit, StatsState>(
    'empty range → empty state',
    build: () {
      ledger(const []);
      return build();
    },
    act: (c) => c.load(),
    expect: () => [
      const StatsState(),
      isA<StatsState>()
          .having((s) => s.status, 'status', StatsStatus.empty)
          .having((s) => s.summary!.isEmpty, 'empty', isTrue),
    ],
  );

  blocTest<StatsCubit, StatsState>(
    'setPeriod reloads with the new range and bumps the revision; the same '
    'period is a no-op',
    build: () {
      ledger([tx('a', -1000, DateTime.utc(2026, 3))]);
      return build();
    },
    act: (c) async {
      await c.load();
      await c.setPeriod(StatsPeriod.year);
      await c.setPeriod(StatsPeriod.year);
    },
    skip: 2,
    expect: () => [
      // The period flips first (the switcher moves at once), then loading.
      isA<StatsState>()
          .having((s) => s.period, 'period', StatsPeriod.year)
          .having((s) => s.status, 'status', StatsStatus.empty),
      isA<StatsState>()
          .having((s) => s.period, 'period', StatsPeriod.year)
          .having((s) => s.status, 'status', StatsStatus.loading),
      isA<StatsState>()
          .having((s) => s.status, 'status', StatsStatus.content)
          .having((s) => s.revision, 'revision', 2)
          .having((s) => s.summary!.series.length, 'points', 365)
          .having((s) => s.summary!.buckets.length, 'buckets', 12),
    ],
    verify: (_) {
      verify(
        () => repo.getTransactionsBetween(
          DateTime.utc(2025, 11),
          DateTime.utc(2026, 11),
        ),
      ).called(1);
      verify(() => repo.getTransactionsBetween(any(), any())).called(1);
    },
  );

  blocTest<StatsCubit, StatsState>(
    'storage failure → error; retry → content',
    build: () {
      var first = true;
      when(() => repo.getTransactionsBetween(any(), any())).thenAnswer((
        _,
      ) async {
        if (first) {
          first = false;
          return const Failure('db');
        }
        return Success([tx('a', -1, DateTime.utc(2026, 10, 31, 1))]);
      });
      return build();
    },
    act: (c) async {
      await c.load();
      await c.retry();
    },
    expect: () => [
      const StatsState(),
      const StatsState(status: StatsStatus.error, message: 'db'),
      const StatsState(),
      isA<StatsState>()
          .having((s) => s.status, 'status', StatsStatus.content)
          .having((s) => s.message, 'message', isNull),
    ],
  );

  blocTest<StatsCubit, StatsState>(
    'an int64 overflow in the sums is an error state, not a crash',
    build: () {
      ledger([
        tx('a', -(Money.max.paise - 1), DateTime.utc(2026, 10, 31, 8)),
        tx('b', -5, DateTime.utc(2026, 10, 31, 9)),
      ]);
      return build();
    },
    act: (c) => c.load(),
    expect: () => [
      const StatsState(),
      const StatsState(
        status: StatsStatus.error,
        message: 'Amounts out of range',
      ),
    ],
  );

  blocTest<StatsCubit, StatsState>(
    'refresh keeps the content while reloading and bumps the revision',
    build: () {
      ledger([tx('a', -1000, DateTime.utc(2026, 10, 31, 8))]);
      return build();
    },
    act: (c) async {
      await c.load();
      await c.refresh();
    },
    skip: 2,
    expect: () => [
      isA<StatsState>()
          .having((s) => s.status, 'status', StatsStatus.content)
          .having((s) => s.revision, 'revision', 2),
    ],
  );

  test('a stale answer is dropped when the period changed meanwhile', () async {
    final slow = Completer<Result<List<Transaction>>>();
    var calls = 0;
    when(() => repo.getTransactionsBetween(any(), any())).thenAnswer((_) {
      calls++;
      if (calls == 1) return slow.future;
      return Future.value(Success([tx('m', -7, DateTime.utc(2026, 5, 2))]));
    });
    final c = build();
    final first = c.load();
    await c.setPeriod(StatsPeriod.year);
    slow.complete(Success([tx('w', -1, DateTime.utc(2026, 10, 31, 8))]));
    await first;
    expect(c.state.period, StatsPeriod.year);
    expect(c.state.summary!.spend, const Money.paise(7));
    expect(c.state.revision, 1);
    await c.close();
  });

  test('toString carries no amounts', () {
    final s = StatsState(
      status: StatsStatus.content,
      summary: StatsMath.summarise(
        [tx('a', -123456, DateTime.utc(2026, 10, 31, 8))],
        period: StatsPeriod.week,
        now: DateTime(2026, 10, 31, 12),
        toLocal: utcAsLocal,
      ),
    );
    expect(s.toString(), isNot(contains('1,234')));
    expect(s.summary.toString(), isNot(contains('1,234')));
  });
}
