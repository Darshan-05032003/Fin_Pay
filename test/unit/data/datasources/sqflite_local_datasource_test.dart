import 'package:clock/clock.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/database/app_database.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/data/datasources/sqflite_local_datasource.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase app;
  late SqfliteLocalDataSource ds;
  final fixedNow = DateTime.utc(2026, 10, 31, 12);

  final user = User(
    id: 'u1',
    fullName: 'John Doe',
    email: 'user@finpay.com',
    balance: const Money.paise(100000),
    createdAt: fixedNow,
  );

  Transaction tx(String id, int paise, {String? key, DateTime? date}) =>
      Transaction(
        id: id,
        title: 'Tx $id',
        amount: Money.paise(paise),
        date: date ?? fixedNow,
        type: paise < 0 ? TransactionType.payment : TransactionType.topUp,
        icon: 'T',
        idempotencyKey: key,
      );

  setUp(() async {
    app = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      clock: Clock.fixed(fixedNow),
    );
    ds = SqfliteLocalDataSource(app);
  });

  tearDown(() => app.close());

  T unwrap<T>(Result<T> result) => switch (result) {
    Success(data: final d) => d,
    Failure(message: final m) => throw StateError('unexpected failure: $m'),
  };

  group('users', () {
    test('getUser is null on an empty database', () async {
      expect(unwrap(await ds.getUser()), isNull);
    });

    test('save, read, update and delete round-trip', () async {
      unwrap(await ds.saveUser(user));
      expect(unwrap(await ds.getUser()), user);

      final updated = user.copyWith(fullName: 'Jane', phone: '+91 98');
      unwrap(await ds.updateUser(updated));
      expect(unwrap(await ds.getUser()), updated);

      unwrap(await ds.deleteUser());
      expect(unwrap(await ds.getUser()), isNull);
    });

    test('saveUser replaces an existing row with the same id', () async {
      unwrap(await ds.saveUser(user));
      unwrap(await ds.saveUser(user.copyWith(fullName: 'Replaced')));
      expect(unwrap(await ds.getUser())!.fullName, 'Replaced');
    });
  });

  group('transactions', () {
    setUp(() async => unwrap(await ds.saveUser(user)));

    test(
      'saveTransaction records the row and applies it to the balance',
      () async {
        final outcome = unwrap(await ds.saveTransaction(tx('t1', -25000)));
        expect(outcome, TransactionOutcome.recorded);
        expect(unwrap(await ds.getUser())!.balance, const Money.paise(75000));
        expect(unwrap(await ds.getTransactions()), [tx('t1', -25000)]);
      },
    );

    test('the same idempotencyKey twice creates exactly one row and one '
        'balance change', () async {
      final first = tx('t1', -25000, key: 'pay-abc');
      final second = tx('t2', -25000, key: 'pay-abc');
      expect(
        unwrap(await ds.saveTransaction(first)),
        TransactionOutcome.recorded,
      );
      expect(
        unwrap(await ds.saveTransaction(second)),
        TransactionOutcome.duplicate,
      );
      expect(unwrap(await ds.countTransactions()), 1);
      expect(unwrap(await ds.getUser())!.balance, const Money.paise(75000));
    });

    test(
      'rapid concurrent submits with one key still produce one row',
      () async {
        final submits = List.generate(
          20,
          (i) => ds.saveTransaction(tx('t$i', -1000, key: 'same-key')),
        );
        final outcomes = (await Future.wait(submits)).map(unwrap).toList();
        expect(
          outcomes.where((o) => o == TransactionOutcome.recorded).length,
          1,
        );
        expect(
          outcomes.where((o) => o == TransactionOutcome.duplicate).length,
          19,
        );
        expect(unwrap(await ds.countTransactions()), 1);
        expect(unwrap(await ds.getUser())!.balance, const Money.paise(99000));
      },
    );

    test(
      'a debit beyond the balance is refused and nothing is written',
      () async {
        expect(
          unwrap(await ds.saveTransaction(tx('t1', -100001))),
          TransactionOutcome.insufficientBalance,
        );
        expect(unwrap(await ds.countTransactions()), 0);
        expect(unwrap(await ds.getUser())!.balance, const Money.paise(100000));
      },
    );

    test('a debit of exactly the balance is allowed', () async {
      expect(
        unwrap(await ds.saveTransaction(tx('t1', -100000))),
        TransactionOutcome.recorded,
      );
      expect(unwrap(await ds.getUser())!.balance, Money.zero);
    });

    test('credits are always accepted', () async {
      expect(
        unwrap(await ds.saveTransaction(tx('t1', 500000))),
        TransactionOutcome.recorded,
      );
      expect(unwrap(await ds.getUser())!.balance, const Money.paise(600000));
    });

    test('without a user row the transaction is refused', () async {
      unwrap(await ds.deleteUser());
      expect(
        unwrap(await ds.saveTransaction(tx('t1', 1))),
        TransactionOutcome.noUser,
      );
      expect(unwrap(await ds.countTransactions()), 0);
    });

    test('a balance that would overflow int64 is refused', () async {
      unwrap(await ds.updateUser(user.copyWith(balance: Money.max)));
      final result = await ds.saveTransaction(tx('t1', 1));
      expect(result.isFailure, isTrue);
      expect(unwrap(await ds.countTransactions()), 0);
      expect(unwrap(await ds.getUser())!.balance, Money.max);
    });

    test('getTransactions orders newest first with limit and offset', () async {
      for (var i = 0; i < 5; i++) {
        unwrap(
          await ds.saveTransaction(
            tx('t$i', 100, date: fixedNow.add(Duration(days: i))),
          ),
        );
      }
      final all = unwrap(await ds.getTransactions());
      expect(all.map((t) => t.id), ['t4', 't3', 't2', 't1', 't0']);
      final page = unwrap(await ds.getTransactions(limit: 2, offset: 1));
      expect(page.map((t) => t.id), ['t3', 't2']);
    });

    test('dates round-trip as UTC instants', () async {
      final local = DateTime(2026, 6, 1, 23, 30);
      unwrap(await ds.saveTransaction(tx('t1', 1, date: local)));
      final stored = unwrap(await ds.getTransactions()).single;
      expect(stored.date.isUtc, isTrue);
      expect(stored.date, local.toUtc());
      expect(stored.localDate, local);
    });

    test(
      'searchTransactions matches title and recipient, case-insensitive',
      () async {
        unwrap(
          await ds.saveTransaction(
            tx('t1', -1).copyWith(title: 'Coffee', recipient: 'Blue Tokai'),
          ),
        );
        unwrap(await ds.saveTransaction(tx('t2', -1).copyWith(title: 'Rent')));
        expect(unwrap(await ds.searchTransactions('coff')).single.id, 't1');
        expect(unwrap(await ds.searchTransactions('tokai')).single.id, 't1');
        expect(unwrap(await ds.searchTransactions('zzz')), isEmpty);
      },
    );

    test('searchTransactions escapes LIKE wildcards', () async {
      unwrap(
        await ds.saveTransaction(tx('t1', -1).copyWith(title: '100% off')),
      );
      unwrap(await ds.saveTransaction(tx('t2', -1).copyWith(title: 'Rent')));
      expect(unwrap(await ds.searchTransactions('%')).single.id, 't1');
      expect(unwrap(await ds.searchTransactions('_')), isEmpty);
    });

    test(
      'getTransactionsBetween and getDailyTotals group by UTC day',
      () async {
        unwrap(
          await ds.saveTransactions([
            tx('a', -100, date: DateTime.utc(2026, 1, 1, 1)),
            tx('b', -200, date: DateTime.utc(2026, 1, 1, 23)),
            tx('c', 500, date: DateTime.utc(2026, 1, 2, 5)),
            tx('d', 1, date: DateTime.utc(2026, 1, 3)),
          ]),
        );
        final between = unwrap(
          await ds.getTransactionsBetween(
            DateTime.utc(2026),
            DateTime.utc(2026, 1, 2),
          ),
        );
        expect(between.map((t) => t.id), ['b', 'a']);

        final totals = unwrap(await ds.getDailyTotals());
        expect(totals.keys.toList(), [
          DateTime.utc(2026, 1, 3),
          DateTime.utc(2026, 1, 2),
          DateTime.utc(2026),
        ]);
        expect(totals[DateTime.utc(2026)], const Money.paise(-300));
        expect(totals[DateTime.utc(2026, 1, 2)], const Money.paise(500));
        expect(unwrap(await ds.getDailyTotals(limitDays: 1)).length, 1);
        // Bulk insert never touches the balance.
        expect(unwrap(await ds.getUser())!.balance, const Money.paise(100000));
      },
    );

    test('saveTransactions skips duplicates', () async {
      unwrap(await ds.saveTransactions([tx('a', 1), tx('b', 1)]));
      unwrap(await ds.saveTransactions([tx('a', 1), tx('c', 1)]));
      expect(unwrap(await ds.countTransactions()), 3);
    });

    test(
      'deleteTransaction removes the row without touching the balance',
      () async {
        unwrap(await ds.saveTransaction(tx('t1', -100)));
        unwrap(await ds.deleteTransaction('t1'));
        expect(unwrap(await ds.countTransactions()), 0);
        expect(unwrap(await ds.getUser())!.balance, const Money.paise(99900));
      },
    );
  });

  group('cards', () {
    const card = PaymentCard(
      id: 'c1',
      cardNumber: '4111 1111 1111 1234',
      cardHolderName: 'John',
      expireDate: '12/28',
      cvv: '987',
      cardType: CardType.rupay,
      balance: Money.paise(5000),
    );

    test('stores only the masked number, never the PAN or CVV', () async {
      unwrap(await ds.saveCard(card));
      final db = await app.database;
      final row = (await db.query('cards')).single;
      expect(row.values.join(' '), isNot(contains('4111 1111')));
      expect(row.values.join(' '), isNot(contains('987')));
      expect(row['maskedNumber'], '**** **** **** 1234');

      final read = unwrap(await ds.getCards()).single;
      expect(read.cardNumber, '**** **** **** 1234');
      expect(read.cvv, '');
      expect(read.cardType, CardType.rupay);
      expect(read.balance, const Money.paise(5000));
      expect(read.hasFullDetails, isFalse);
    });

    test('lists every card and deletes by id', () async {
      unwrap(await ds.saveCard(card));
      unwrap(await ds.saveCard(card.copyWith(id: 'c2')));
      final cards = unwrap(await ds.getCards());
      expect(cards.map((c) => c.id), containsAll(['c1', 'c2']));
      unwrap(await ds.deleteCard('c1'));
      expect(unwrap(await ds.getCards()).map((c) => c.id), ['c2']);
    });
  });

  group('notifications', () {
    test('save, list newest first, delete', () async {
      final n1 = NotificationItem(
        id: 'n1',
        title: 'A',
        message: 'a',
        time: fixedNow,
        type: NotificationType.cashback,
      );
      final n2 = n1.copyWith(
        id: 'n2',
        time: fixedNow.add(const Duration(hours: 1)),
        type: NotificationType.billDue,
        isRead: true,
      );
      unwrap(await ds.saveNotification(n1));
      unwrap(await ds.saveNotification(n2));
      expect(unwrap(await ds.getNotifications()), [n2, n1]);
      expect(unwrap(await ds.getNotifications(limit: 1)), [n2]);
      unwrap(await ds.deleteNotification('n2'));
      expect(unwrap(await ds.getNotifications()), [n1]);
    });
  });

  group('clearAll', () {
    test('empties every table', () async {
      unwrap(await ds.saveUser(user));
      unwrap(await ds.saveTransaction(tx('t', 1)));
      unwrap(await ds.clearAll());
      expect(unwrap(await ds.getUser()), isNull);
      expect(unwrap(await ds.countTransactions()), 0);
    });
  });

  group('failures', () {
    test('a closed database yields Failure, not an exception', () async {
      await app.close();
      final broken = SqfliteLocalDataSource(
        AppDatabase(
          factory: databaseFactoryFfi,
          path: '/nonexistent-dir/\u0000/finpay.db',
        ),
      );
      final result = await broken.getUser();
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isNotEmpty);
    });
  });
}
