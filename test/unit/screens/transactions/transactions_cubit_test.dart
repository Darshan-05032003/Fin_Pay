// `type: null` is spelled out in the verifies on purpose: the cubit passes
// the filter's type explicitly, so the invocation carries the named argument
// and mocktail matches it only when the stub spells it too.
// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/screens/transactions/transactions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock
    implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repo;
  late int ledgerChanges;

  final base = DateTime.utc(2026, 10, 31, 12);

  Transaction tx(int i, {TransactionType type = TransactionType.payment}) =>
      Transaction(
        id: 'p${i.toString().padLeft(6, '0')}',
        title: 'Row $i',
        amount: Money.paise(-100 * (i + 1)),
        date: base.subtract(Duration(minutes: i)),
        type: type,
        icon: 'x',
      );

  List<Transaction> rows(int from, int count) => [
    for (var i = from; i < from + count; i++) tx(i),
  ];

  setUpAll(() => registerFallbackValue(tx(0)));

  setUp(() {
    repo = MockTransactionRepository();
    ledgerChanges = 0;
    when(
      () => repo.deleteTransaction(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.addTransactions(any()),
    ).thenAnswer((_) async => const Success(null));
  });

  /// Stubs `getTransactions` so page [offset] of size [limit] comes from a
  /// ledger of [total] rows.
  void ledgerOf(int total, {TransactionType? type}) {
    when(
      () => repo.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((inv) async {
      final limit = inv.namedArguments[#limit] as int;
      final offset = inv.namedArguments[#offset] as int;
      final wanted = inv.namedArguments[#type] as TransactionType?;
      // Every fixture row is a payment, so any other filter is empty.
      if (wanted != null && wanted != TransactionType.payment) {
        return const Success([]);
      }
      final end = (offset + limit).clamp(0, total);
      return Success(
        offset >= total ? const <Transaction>[] : rows(offset, end - offset),
      );
    });
  }

  TransactionsCubit build({int pageSize = 50}) => TransactionsCubit(
    repository: repo,
    pageSize: pageSize,
    debounce: const Duration(milliseconds: 10),
    onLedgerChanged: () => ledgerChanges++,
  );

  group('first page', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'loads one page and reports hasMore when it is full',
      build: () {
        ledgerOf(120);
        return build();
      },
      act: (c) => c.load(),
      expect: () => [
        const TransactionsState(),
        isA<TransactionsState>()
            .having((s) => s.status, 'status', TransactionsStatus.content)
            .having((s) => s.items.length, 'rows', 50)
            .having((s) => s.hasMore, 'hasMore', isTrue),
      ],
      verify: (_) => verify(
        () => repo.getTransactions(limit: 50, offset: 0, type: null),
      ).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'a short ledger has no further page',
      build: () {
        ledgerOf(7);
        return build();
      },
      act: (c) => c.load(),
      expect: () => [
        const TransactionsState(),
        isA<TransactionsState>()
            .having((s) => s.items.length, 'rows', 7)
            .having((s) => s.hasMore, 'hasMore', isFalse),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'empty ledger → empty',
      build: () {
        ledgerOf(0);
        return build();
      },
      act: (c) => c.load(),
      expect: () => [
        const TransactionsState(),
        const TransactionsState(status: TransactionsStatus.empty),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'error → error, retry → content',
      build: () {
        var first = true;
        when(
          () => repo.getTransactions(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async {
          if (first) {
            first = false;
            return const Failure('db down');
          }
          return Success(rows(0, 3));
        });
        return build();
      },
      act: (c) async {
        await c.load();
        await c.retry();
      },
      expect: () => [
        const TransactionsState(),
        const TransactionsState(
          status: TransactionsStatus.error,
          errorMessage: 'db down',
        ),
        const TransactionsState(),
        isA<TransactionsState>()
            .having((s) => s.status, 'status', TransactionsStatus.content)
            .having((s) => s.errorMessage, 'error', isNull)
            .having((s) => s.items.length, 'rows', 3),
      ],
    );
  });

  group('load more', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'appends the next page at the right offset and stops at the end',
      build: () {
        ledgerOf(120);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.loadMore();
        await c.loadMore();
        await c.loadMore();
      },
      skip: 2,
      expect: () => [
        isA<TransactionsState>().having((s) => s.loadingMore, 'more', isTrue),
        isA<TransactionsState>()
            .having((s) => s.items.length, 'rows', 100)
            .having((s) => s.hasMore, 'hasMore', isTrue)
            .having((s) => s.loadingMore, 'more', isFalse),
        isA<TransactionsState>().having((s) => s.loadingMore, 'more', isTrue),
        isA<TransactionsState>()
            .having((s) => s.items.length, 'rows', 120)
            .having((s) => s.hasMore, 'hasMore', isFalse),
      ],
      verify: (c) {
        verify(
          () => repo.getTransactions(limit: 50, offset: 50, type: null),
        ).called(1);
        verify(
          () => repo.getTransactions(limit: 50, offset: 100, type: null),
        ).called(1);
        verifyNever(
          () => repo.getTransactions(limit: 50, offset: 120, type: null),
        );
        expect(c.state.items.map((t) => t.id).toSet().length, 120);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'duplicate page guard: concurrent loadMore calls fetch once',
      build: () {
        ledgerOf(120);
        return build();
      },
      act: (c) async {
        await c.load();
        await Future.wait([c.loadMore(), c.loadMore(), c.loadMore()]);
      },
      verify: (c) {
        verify(
          () => repo.getTransactions(limit: 50, offset: 50, type: null),
        ).called(1);
        expect(c.state.items.length, 100);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'a failing page keeps the rows, reports the error and can be retried',
      build: () {
        var calls = 0;
        when(
          () => repo.getTransactions(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            type: any(named: 'type'),
          ),
        ).thenAnswer((inv) async {
          calls++;
          if (calls == 2) return const Failure('timeout');
          final offset = inv.namedArguments[#offset] as int;
          return Success(rows(offset, 50));
        });
        return build();
      },
      act: (c) async {
        await c.load();
        await c.loadMore();
        await c.loadMore();
      },
      verify: (c) {
        expect(c.state.items.length, 100);
        expect(c.state.hasMore, isTrue);
        expect(c.state.status, TransactionsStatus.content);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'no paging while searching or before content',
      build: () {
        ledgerOf(120);
        when(
          () => repo.searchTransactions(any(), type: any(named: 'type')),
        ).thenAnswer((_) async => Success(rows(0, 50)));
        return build();
      },
      act: (c) async {
        await c.loadMore();
        await c.load();
        c.search('row');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await c.loadMore();
      },
      verify: (c) {
        expect(c.state.isSearching, isTrue);
        expect(c.state.hasMore, isFalse);
        verifyNever(
          () => repo.getTransactions(limit: 50, offset: 50, type: null),
        );
      },
    );
  });

  group('search', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'is debounced, trimmed, bounded to 200 characters and not paged',
      build: () {
        ledgerOf(120);
        when(
          () => repo.searchTransactions(any(), type: any(named: 'type')),
        ).thenAnswer((_) async => Success(rows(0, 2)));
        return build();
      },
      act: (c) async {
        await c.load();
        c
          ..search('c')
          ..search('co')
          ..search('  cof${'x' * 300}  ');
        await Future<void>.delayed(const Duration(milliseconds: 40));
      },
      verify: (c) {
        final captured = verify(
          () => repo.searchTransactions(captureAny(), type: null),
        ).captured;
        expect(captured.length, 1);
        expect((captured.single as String).length, 200);
        expect(captured.single, startsWith('cofxxx'));
        expect(c.state.query.length, 200);
        expect(c.state.items.length, 2);
        expect(c.state.hasMore, isFalse);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'clearing the query returns to the paged list; hostile strings are '
      'passed through as data',
      build: () {
        ledgerOf(120);
        when(
          () => repo.searchTransactions(any(), type: any(named: 'type')),
        ).thenAnswer((_) async => const Success([]));
        return build();
      },
      act: (c) async {
        await c.load();
        for (final q in [
          "' OR 1=1 --",
          '\u202Eabc',
          '🙂🙂🙂',
          'مرحبا',
          '\u0000',
        ]) {
          c.search(q);
          await Future<void>.delayed(const Duration(milliseconds: 40));
          expect(c.state.status, TransactionsStatus.empty, reason: q);
        }
        c.search('   ');
        await Future<void>.delayed(const Duration(milliseconds: 40));
      },
      verify: (c) {
        expect(c.state.isSearching, isFalse);
        expect(c.state.items.length, 50);
        expect(c.state.hasMore, isTrue);
        verify(
          () => repo.getTransactions(limit: 50, offset: 0, type: null),
        ).called(2);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'a stale answer (query changed meanwhile) is dropped',
      build: () {
        ledgerOf(10);
        final slow = Completer<Result<List<Transaction>>>();
        when(
          () => repo.searchTransactions('slow', type: null),
        ).thenAnswer((_) => slow.future);
        when(() => repo.searchTransactions('fast', type: null)).thenAnswer((
          _,
        ) async {
          scheduleMicrotask(() => slow.complete(Success(rows(0, 9))));
          return Success(rows(0, 1));
        });
        return build();
      },
      act: (c) async {
        await c.load();
        c.search('slow');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        c.search('fast');
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (c) {
        expect(c.state.query, 'fast');
        expect(c.state.items.length, 1);
      },
    );
  });

  group('filter', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'reloads the first page with the chip type; same chip is a no-op',
      build: () {
        ledgerOf(120);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.setFilter(TransactionsFilter.sent);
        await c.setFilter(TransactionsFilter.sent);
      },
      verify: (c) {
        verify(
          () => repo.getTransactions(
            limit: 50,
            offset: 0,
            type: TransactionType.sendMoney,
          ),
        ).called(1);
        expect(c.state.filter, TransactionsFilter.sent);
      },
    );

    test('every chip maps to a distinct type (or none)', () {
      final types = TransactionsFilter.values.map((f) => f.type).toList();
      expect(types.first, isNull);
      expect(types.skip(1).toSet().length, TransactionType.values.length);
    });
  });

  group('delete and undo', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'delete removes the row at once, undo restores it in order, a second '
      'undo is a no-op, and the ledger listener fires for both',
      build: () {
        ledgerOf(5);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.delete('p000002');
        expect(c.state.items.map((t) => t.id), isNot(contains('p000002')));
        expect(c.pendingUndo, ['p000002']);
        await c.undo('p000002');
        await c.undo('p000002');
      },
      verify: (c) {
        expect(c.state.items.map((t) => t.id).toList(), [
          'p000000',
          'p000001',
          'p000002',
          'p000003',
          'p000004',
        ]);
        expect(c.pendingUndo, isEmpty);
        verify(() => repo.deleteTransaction('p000002')).called(1);
        verify(() => repo.addTransactions(any())).called(1);
        expect(ledgerChanges, 2);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'the next page offset accounts for deletes (no skipped row)',
      build: () {
        ledgerOf(120);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.delete('p000003');
        await c.loadMore();
      },
      verify: (_) => verify(
        () => repo.getTransactions(limit: 50, offset: 49, type: null),
      ).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'a failed delete puts the row back and reports',
      build: () {
        ledgerOf(3);
        when(
          () => repo.deleteTransaction(any()),
        ).thenAnswer((_) async => const Failure('locked'));
        return build();
      },
      act: (c) async {
        await c.load();
        await c.delete('p000001');
      },
      verify: (c) {
        expect(c.state.items.length, 3);
        expect(c.state.errorMessage, 'locked');
        expect(c.pendingUndo, isEmpty);
        expect(ledgerChanges, 0);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'deleting the last row shows the empty state; forget drops the undo',
      build: () {
        ledgerOf(1);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.delete('p000000');
        c.forget('p000000');
        await c.undo('p000000');
      },
      verify: (c) {
        expect(c.state.status, TransactionsStatus.empty);
        expect(c.state.items, isEmpty);
        verifyNever(() => repo.addTransactions(any()));
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'deleting an unknown id or a row already pending is ignored',
      build: () {
        ledgerOf(2);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.delete('ghost');
        await c.delete('p000000');
        await c.delete('p000000');
      },
      verify: (_) => verify(() => repo.deleteTransaction(any())).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'undo of a row that no longer matches the filter stays hidden',
      build: () {
        ledgerOf(3);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.delete('p000001');
        await c.setFilter(TransactionsFilter.sent);
        await c.undo('p000001');
      },
      verify: (c) {
        expect(c.state.items.map((t) => t.id), isNot(contains('p000001')));
        verify(() => repo.addTransactions(any())).called(1);
      },
    );
  });

  group('refresh', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'keeps the content on screen while the first page reloads',
      build: () {
        ledgerOf(10);
        return build();
      },
      act: (c) async {
        await c.load();
        await c.refresh();
      },
      skip: 2,
      expect: () => [
        isA<TransactionsState>()
            .having((s) => s.status, 'status', TransactionsStatus.content)
            .having((s) => s.refreshing, 'refreshing', isTrue),
        isA<TransactionsState>()
            .having((s) => s.refreshing, 'refreshing', isFalse)
            .having((s) => s.items.length, 'rows', 10),
      ],
    );
  });

  test('state toString carries counts only', () {
    final state = TransactionsState(
      status: TransactionsStatus.content,
      items: [tx(1)],
      query: 'priya',
    );
    expect(state.toString(), isNot(contains('Row 1')));
    expect(state.toString(), isNot(contains('priya')));
    expect(state.toString(), isNot(contains('₹')));
    expect(state.toString(), contains('1 rows'));
  });

  test('a closed cubit ignores late answers and pending searches', () async {
    final slow = Completer<Result<List<Transaction>>>();
    when(
      () => repo.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) => slow.future);
    final c = build()..search('x');
    final loading = c.load();
    await c.close();
    slow.complete(Success(rows(0, 3)));
    await loading;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(c.state.items, isEmpty);
  });
}
