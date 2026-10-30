import 'package:clock/clock.dart';
import 'package:fin_pay/data/database/app_database.dart';
import 'package:fin_pay/data/database/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/v1_schema.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late DatabaseFactory factory;
  late String path;

  setUp(() async {
    factory = databaseFactoryFfi;
    // A named in-memory database survives close/reopen within the process
    // only while at least one connection is open, so use a temp file.
    path = await factory.getDatabasesPath();
    path = '$path/finpay_test_${DateTime.now().microsecondsSinceEpoch}.db';
    await factory.deleteDatabase(path);
  });

  tearDown(() async {
    await factory.deleteDatabase(path);
  });

  group('fresh install (onCreate)', () {
    test(
      'creates the v2 schema with INTEGER paise and no password column',
      () async {
        final app = AppDatabase(factory: factory, path: path);
        final db = await app.database;
        expect(await db.getVersion(), AppDatabase.schemaVersion);

        final users = await db.rawQuery('PRAGMA table_info(users)');
        final userColumns = {for (final c in users) c['name']: c['type']};
        expect(userColumns.containsKey('password'), isFalse);
        expect(userColumns['balance'], 'INTEGER');

        final tx = await db.rawQuery('PRAGMA table_info(transactions)');
        final txColumns = {for (final c in tx) c['name']: c['type']};
        expect(txColumns['amount'], 'INTEGER');
        expect(txColumns['idempotencyKey'], 'TEXT');

        final cards = await db.rawQuery('PRAGMA table_info(cards)');
        final cardColumns = {for (final c in cards) c['name']: c['type']};
        expect(cardColumns['balance'], 'INTEGER');
        expect(cardColumns.containsKey('cardNumber'), isFalse);
        expect(cardColumns.containsKey('cvv'), isFalse);

        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index'",
        );
        final names = indexes.map((r) => r['name']).toSet();
        expect(names, contains('idx_transactions_date'));
        expect(names, contains('idx_transactions_idempotency'));
        expect(names, contains('idx_notifications_time'));
        await app.close();
      },
    );

    test('the same AppDatabase returns one shared connection', () async {
      final app = AppDatabase(factory: factory, path: path);
      final a = await app.database;
      final b = await app.database;
      expect(identical(a, b), isTrue);
      await app.close();
    });
  });

  group('v1 → v2 migration', () {
    test(
      'converts REAL rupees to INTEGER paise and drops the password',
      () async {
        await createV1Database(factory, path);

        final app = AppDatabase(factory: factory, path: path);
        final db = await app.database;
        expect(await db.getVersion(), 2);

        final users = await db.query('users');
        expect(users, hasLength(1));
        expect(users.first['balance'], 5624690);
        expect(users.first.containsKey('password'), isFalse);
        expect(users.first['email'], 'user@finpay.com');

        final tx = await db.query('transactions', orderBy: 'id');
        expect(tx, hasLength(4));
        final byId = {for (final r in tx) r['id']: r};
        expect(byId['t1']!['amount'], -42090); // -420.90
        expect(byId['t2']!['amount'], 100005); // 1000.05 (binary 1000.0499…)
        expect(byId['t3']!['amount'], 1); // 0.01
        expect(byId['t4']!['amount'], -1234567891); // -12345678.91
        expect(byId['t1']!['type'], 'sendMoney');
        expect(byId['t1']!['idempotencyKey'], 't1');
        expect(byId['t1']!['amount'], isA<int>());

        final cards = await db.query('cards');
        expect(cards, hasLength(1));
        expect(cards.first['balance'], 1000000);
        expect(cards.first['maskedNumber'], '**** **** **** 1234');
        expect(cards.first['cardType'], 'visa');
        expect(cards.first.containsKey('cardNumber'), isFalse);
        expect(cards.first.containsKey('cvv'), isFalse);

        final notifications = await db.query('notifications');
        expect(notifications, hasLength(1));
        expect(notifications.first['type'], 'cashback');
        expect(notifications.first['isRead'], 0);

        // Nothing from the v1 schema is left behind.
        final leftovers = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name LIKE '%_v1' "
          "OR name LIKE '%_old' OR name LIKE '%_new'",
        );
        expect(leftovers, isEmpty);
        await app.close();
      },
    );

    test('rounds half-up at the paisa boundary', () async {
      await createV1Database(
        factory,
        path,
        transactions: [
          v1Transaction('r1', 0.005),
          v1Transaction('r2', 0.015),
          v1Transaction('r3', -0.005),
          v1Transaction('r4', 2.675),
        ],
      );
      final app = AppDatabase(factory: factory, path: path);
      final db = await app.database;
      final rows = await db.query('transactions', orderBy: 'id');
      final amounts = rows.map((r) => r['amount']).toList();
      // SQLite ROUND() rounds half away from zero on the decimal expansion
      // of the stored double; these are the values a user would expect.
      expect(amounts, [1, 2, -1, 268]);
      await app.close();
    });

    test('keeps a NULL balance as zero', () async {
      await createV1Database(factory, path, userBalance: null);
      final app = AppDatabase(factory: factory, path: path);
      final db = await app.database;
      final users = await db.query('users');
      expect(users.first['balance'], 0);
      await app.close();
    });

    test('is idempotent: a crash mid-migration leaves v1 intact and the '
        'next open completes it', () async {
      await createV1Database(factory, path);

      var crashed = false;
      final crashing = AppDatabase(
        factory: factory,
        path: path,
        onMigrationStep: (step) {
          if (step == MigrationStep.transactionsConverted) {
            crashed = true;
            throw StateError('simulated process death');
          }
        },
      );
      await expectLater(crashing.database, throwsStateError);
      expect(crashed, isTrue);
      await crashing.close();

      // The interrupted open rolled back: still version 1, data untouched.
      final raw = await factory.openDatabase(path);
      expect(await raw.getVersion(), 1);
      final v1Rows = await raw.query('transactions');
      expect(v1Rows, hasLength(4));
      expect(v1Rows.first['amount'], isA<double>());
      await raw.close();

      final app = AppDatabase(factory: factory, path: path);
      final db = await app.database;
      expect(await db.getVersion(), 2);
      final rows = await db.query('transactions');
      expect(rows, hasLength(4));
      expect(rows.first['amount'], isA<int>());
      await app.close();
    });

    test('opening an already migrated database is a no-op', () async {
      await createV1Database(factory, path);
      final first = AppDatabase(factory: factory, path: path);
      await first.database;
      await first.close();

      var steps = 0;
      final second = AppDatabase(
        factory: factory,
        path: path,
        onMigrationStep: (_) => steps++,
      );
      final db = await second.database;
      expect(steps, 0);
      expect((await db.query('transactions')).length, 4);
      await second.close();
    });

    test('createdAt is written by the injected clock', () async {
      final fixed = Clock.fixed(DateTime.utc(2030));
      final app = AppDatabase(factory: factory, path: path, clock: fixed);
      final db = await app.database;
      await db.insert('transactions', {
        'id': 'x',
        'title': 'x',
        'amount': 1,
        'date': '2030-01-01T00:00:00.000Z',
        'type': 'payment',
        'icon': 'x',
        'idempotencyKey': 'x',
        'createdAt': app.clock.now().toUtc().toIso8601String(),
      });
      final row = (await db.query('transactions')).first;
      expect(row['createdAt'], '2030-01-01T00:00:00.000Z');
      await app.close();
    });
  });
}
