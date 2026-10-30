@Tags(['stress'])
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_state.dart';
import 'package:fin_pay/core/auth/password_hasher.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/database/app_database.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/data/datasources/sqflite_local_datasource.dart';
import 'package:fin_pay/data/repositories/transaction_repository_impl.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/domain/usecases/get_transactions_usecase.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import '../helpers/v1_schema.dart';
import 'stress_guard.dart';

/// Run with:
///   flutter test --tags stress --dart-define=FINPAY_STRESS=true \
///     --concurrency=1 test/stress
///
/// Numbers are printed as `STRESS <scenario> <metric>=<value>` lines and
/// copied into docs/LOAD_TEST_REPORT.md.
void main() {
  if (!stressGuard()) return;

  setUpAll(sqfliteFfiInit);

  late String path;
  final base = DateTime.utc(2026);

  setUp(() async {
    final dir = await databaseFactoryFfi.getDatabasesPath();
    path = '$dir/finpay_stress_${DateTime.now().microsecondsSinceEpoch}.db';
    await databaseFactoryFfi.deleteDatabase(path);
  });

  tearDown(() => databaseFactoryFfi.deleteDatabase(path));

  Transaction tx(int i) => Transaction(
    id: 'tx-$i',
    title: 'Merchant ${i % 997} order $i',
    amount: Money.paise(i.isEven ? -(i % 50000 + 1) : i % 90000 + 1),
    date: base.add(Duration(minutes: i)),
    type: i.isEven ? TransactionType.payment : TransactionType.receiveMoney,
    icon: 'M',
    recipient: i % 3 == 0 ? 'Contact ${i % 101}' : null,
  );

  T unwrap<T>(Result<T> r) => switch (r) {
    Success(data: final d) => d,
    Failure(message: final m) => throw StateError(m),
  };

  void report(String scenario, Map<String, Object> metrics) {
    final line = metrics.entries.map((e) => '${e.key}=${e.value}').join(' ');
    // The stress report is read from the console output.
    // ignore: avoid_print
    print('STRESS $scenario $line');
  }

  Future<int> timed(Future<void> Function() body) async {
    final sw = Stopwatch()..start();
    await body();
    return sw.elapsedMilliseconds;
  }

  Future<void> insertRows(
    SqfliteLocalDataSource ds,
    int from,
    int to, {
    int batch = 5000,
  }) async {
    for (var start = from; start < to; start += batch) {
      final end = start + batch > to ? to : start + batch;
      unwrap(
        await ds.saveTransactions([for (var i = start; i < end; i++) tx(i)]),
      );
    }
  }

  test(
    '100k transactions: insert, page, search, date range, daily totals',
    () async {
      final app = AppDatabase(factory: databaseFactoryFfi, path: path);
      final ds = SqfliteLocalDataSource(app);
      unwrap(
        await ds.saveUser(
          User(
            id: 'u',
            fullName: 'U',
            email: 'u@x.com',
            balance: const Money.paise(1 << 40),
            createdAt: base,
          ),
        ),
      );

      const n = 100000;
      final insertMs = await timed(() => insertRows(ds, 0, n));
      expect(unwrap(await ds.countTransactions()), n);

      final pageMs = await timed(() async {
        final page = unwrap(await ds.getTransactions(limit: 50));
        expect(page, hasLength(50));
        expect(page.first.id, 'tx-${n - 1}');
      });
      final deepPageMs = await timed(() async {
        final page = unwrap(await ds.getTransactions(limit: 50, offset: 50000));
        expect(page, hasLength(50));
      });
      final searchMs = await timed(() async {
        final hits = unwrap(await ds.searchTransactions('Merchant 42 '));
        expect(hits, isNotEmpty);
      });
      final recipientSearchMs = await timed(() async {
        final hits = unwrap(await ds.searchTransactions('contact 7'));
        expect(hits, isNotEmpty);
      });
      final rangeMs = await timed(() async {
        final rows = unwrap(
          await ds.getTransactionsBetween(
            base.add(const Duration(days: 10)),
            base.add(const Duration(days: 11)),
          ),
        );
        expect(rows, hasLength(1440));
      });
      final totalsMs = await timed(() async {
        final totals = unwrap(await ds.getDailyTotals());
        expect(totals.length, (n / 1440).ceil());
      });
      final totals30Ms = await timed(() async {
        final totals = unwrap(await ds.getDailyTotals(limitDays: 30));
        expect(totals, hasLength(30));
      });
      final fullScanMs = await timed(() async {
        final all = unwrap(await ds.getTransactions());
        expect(all, hasLength(n));
      });
      final idempotentMs = await timed(() async {
        final outcome = unwrap(await ds.saveTransaction(tx(5)));
        expect(outcome, TransactionOutcome.duplicate);
      });

      report('100k-datasource', {
        'insert_ms': insertMs,
        'insert_rows_per_s': (n * 1000 / (insertMs == 0 ? 1 : insertMs))
            .round(),
        'page50_ms': pageMs,
        'page50_offset50k_ms': deepPageMs,
        'search_title_ms': searchMs,
        'search_recipient_ms': recipientSearchMs,
        'date_range_1day_ms': rangeMs,
        'daily_totals_all_ms': totalsMs,
        'daily_totals_30_ms': totals30Ms,
        'full_scan_100k_ms': fullScanMs,
        'duplicate_check_ms': idempotentMs,
      });

      expect(pageMs, lessThan(100));
      expect(deepPageMs, lessThan(200));
      expect(rangeMs, lessThan(200));
      expect(totals30Ms, lessThan(500));
      await app.close();
    },
  );

  test('100k v1 rows migrate to v2', () async {
    final rows = [
      for (var i = 0; i < 100000; i++)
        v1Transaction(
          'v1-$i',
          (i % 100000) / 100 * (i.isEven ? -1 : 1),
          date: base.add(Duration(minutes: i)).toIso8601String(),
        ),
    ];
    final seedMs = await timed(
      () => createV1Database(databaseFactoryFfi, path, transactions: rows),
    );
    final app = AppDatabase(factory: databaseFactoryFfi, path: path);
    final migrateMs = await timed(() async {
      final db = await app.database;
      expect(await db.getVersion(), 2);
    });
    final ds = SqfliteLocalDataSource(app);
    expect(unwrap(await ds.countTransactions()), 100000);
    final sample = unwrap(await ds.getTransactions(limit: 1)).single;
    expect(sample.amount.paise, isA<int>());
    report('100k-migration', {
      'seed_v1_ms': seedMs,
      'migrate_v1_to_v2_ms': migrateMs,
    });
    expect(migrateMs, lessThan(10000));
    await app.close();
  });

  test('1,000 sequential AddTransaction events through the BLoC', () async {
    final app = AppDatabase(factory: databaseFactoryFfi, path: path);
    final ds = SqfliteLocalDataSource(app);
    unwrap(
      await ds.saveUser(
        User(
          id: 'u',
          fullName: 'U',
          email: 'u@x.com',
          balance: const Money.paise(100000000),
          createdAt: base,
        ),
      ),
    );
    final repo = TransactionRepositoryImpl(ds);
    final bloc = TransactionBloc(
      getTransactionsUseCase: GetTransactionsUseCase(repo),
      addTransactionUseCase: AddTransactionUseCase(repo),
      transactionRepository: repo,
    );
    var added = 0;
    var duplicates = 0;
    final sub = bloc.effects.listen((e) {
      if (e is TransactionAdded) added++;
      if (e is TransactionDuplicate) duplicates++;
    });
    bloc.add(const LoadTransactionsEvent(limit: 5));
    await bloc.stream.firstWhere((s) => s is! TransactionLoading);

    final rssBefore = ProcessInfo.currentRss;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      bloc.add(
        AddTransactionEvent(
          tx(i).copyWith(
            amount: const Money.paise(-100),
            idempotencyKey: 'pay-${i ~/ 2}', // every key submitted twice
          ),
        ),
      );
    }
    // Wait until every event has been processed.
    while (added + duplicates < 1000) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final elapsed = sw.elapsedMilliseconds;
    final rssAfter = ProcessInfo.currentRss;

    expect(added, 500);
    expect(duplicates, 500);
    expect(unwrap(await ds.countTransactions()), 500);
    expect(
      unwrap(await ds.getUser())!.balance,
      const Money.paise(100000000 - 500 * 100),
    );
    expect(bloc.hasEffectListeners, isTrue);
    final state = bloc.state as TransactionContent;
    expect(state.transactions, hasLength(5));

    report('1000-bloc-adds', {
      'total_ms': elapsed,
      'per_event_ms': (elapsed / 1000).toStringAsFixed(2),
      'rows': 500,
      'rss_before_mb': (rssBefore / 1048576).toStringAsFixed(1),
      'rss_after_mb': (rssAfter / 1048576).toStringAsFixed(1),
      'rss_growth_mb': ((rssAfter - rssBefore) / 1048576).toStringAsFixed(1),
    });
    // RSS may fluctuate with GC; what must not grow is the tracked state.
    expect(state.transactions.length, 5);
    await sub.cancel();
    expect(bloc.hasEffectListeners, isFalse);
    await bloc.close();
    await app.close();
  });

  test('breaking point: where does a query exceed 100 ms?', () async {
    final app = AppDatabase(factory: databaseFactoryFfi, path: path);
    final ds = SqfliteLocalDataSource(app);
    var rows = 0;
    final steps = [10000, 50000, 100000, 200000, 400000];
    final results = <String, Object>{};
    String? pageBreak;
    String? searchBreak;
    String? totalsBreak;
    for (final target in steps) {
      await insertRows(ds, rows, target);
      rows = target;
      final page = await timed(() => ds.getTransactions(limit: 50));
      final deep = await timed(
        () => ds.getTransactions(limit: 50, offset: rows - 50),
      );
      final search = await timed(() => ds.searchTransactions('order 4242'));
      final totals = await timed(ds.getDailyTotals);
      final totals30 = await timed(() => ds.getDailyTotals(limitDays: 30));
      results['${rows}_page50_ms'] = page;
      results['${rows}_page50_last_ms'] = deep;
      results['${rows}_search_ms'] = search;
      results['${rows}_daily_totals_all_ms'] = totals;
      results['${rows}_daily_totals_30_ms'] = totals30;
      pageBreak ??= deep > 100 ? '$rows' : null;
      searchBreak ??= search > 100 ? '$rows' : null;
      totalsBreak ??= totals > 100 ? '$rows' : null;
    }
    results['first_page_over_100ms_at_rows'] = pageBreak ?? 'none up to 400k';
    results['search_over_100ms_at_rows'] = searchBreak ?? 'none up to 400k';
    results['daily_totals_over_100ms_at_rows'] =
        totalsBreak ?? 'none up to 400k';
    report('breaking-point', results);
    await app.close();
  });

  test('Money.parse and format throughput', () {
    const n = 200000;
    final sw = Stopwatch()..start();
    var acc = Money.zero;
    for (var i = 0; i < n; i++) {
      acc = acc + Money.parse('${i % 1000},${(i % 900) + 100}.${i % 100}');
    }
    final parseMs = sw.elapsedMilliseconds;
    sw.reset();
    var length = 0;
    for (var i = 0; i < n; i++) {
      length += Money.paise(i * 7919).format().length;
    }
    final formatMs = sw.elapsedMilliseconds;
    expect(length, greaterThan(0));
    expect(acc.isPositive, isTrue);
    report('money', {
      'parse_200k_ms': parseMs,
      'format_200k_ms': formatMs,
      'parse_us_each': (parseMs * 1000 / n).toStringAsFixed(2),
      'format_us_each': (formatMs * 1000 / n).toStringAsFixed(2),
    });
  });

  test('PBKDF2 cost at the production iteration count', () {
    const hasher = PasswordHasher();
    final stored = hasher.hash('demo-password-for-timing');
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      expect(hasher.verify('demo-password-for-timing', stored), isTrue);
    }
    final verifyMs = sw.elapsedMilliseconds / 10;
    report('pbkdf2', {'verify_10k_iterations_ms': verifyMs.toStringAsFixed(1)});
    // A lockout of 5 attempts per 30 s makes brute force on-device moot;
    // the hash just needs to stay well under a second.
    expect(verifyMs, lessThan(1000));
  });

  test('clock/timezone: dates round-trip regardless of the zone', () async {
    final app = AppDatabase(
      factory: databaseFactoryFfi,
      path: path,
      clock: Clock.fixed(DateTime.utc(2030)),
    );
    final ds = SqfliteLocalDataSource(app);
    final local = DateTime(2026, 3, 29, 2, 30); // DST gap in many zones
    unwrap(await ds.saveTransactions([tx(1).copyWith(date: local)]));
    final stored = unwrap(await ds.getTransactions()).single;
    expect(stored.date, local.toUtc());
    expect(stored.date.isUtc, isTrue);
    await app.close();
  });
}
