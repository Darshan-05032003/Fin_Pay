import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/repositories/demo_contact_repository.dart';
import 'package:fin_pay/domain/repositories/contact_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/screens/transfer/transfer/amount_input.dart';
import 'package:fin_pay/screens/transfer/transfer/transfer_cubit.dart';
import 'package:fin_pay/screens/transfer/transfer/transfer_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockContactRepository extends Mock implements IContactRepository {}

class MockUserRepository extends Mock implements IUserRepository {}

class MockTransactionRepository extends Mock
    implements ITransactionRepository {}

void main() {
  late MockContactRepository contacts;
  late MockUserRepository users;
  late MockTransactionRepository transactions;
  final clock = Clock.fixed(DateTime.utc(2026, 10, 31, 12));
  final user = User(
    id: 'u1',
    fullName: 'Aarav Mehta',
    email: 'user@finpay.com',
    balance: const Money.paise(5624690),
    createdAt: DateTime.utc(2026),
  );
  final sentToMeera = Transaction(
    id: 't1',
    title: 'Sent to Meera Kulkarni',
    amount: const Money.paise(-100),
    date: DateTime.utc(2026, 10, 30),
    type: TransactionType.sendMoney,
    icon: 'send',
    recipient: 'Meera Kulkarni',
  );

  setUp(() {
    contacts = MockContactRepository();
    users = MockUserRepository();
    transactions = MockTransactionRepository();
    when(
      contacts.getContacts,
    ).thenAnswer((_) async => const Success(demoContacts));
    when(users.getCurrentUser).thenAnswer((_) async => Success(user));
    when(
      () => transactions.getRecentTransactions(limit: any(named: 'limit')),
    ).thenAnswer((_) async => Success([sentToMeera]));
  });

  TransferCubit build() => TransferCubit(
    contacts: contacts,
    users: users,
    transactions: transactions,
    clock: clock,
    random: Random(7),
  );

  Future<TransferCubit> loaded() async {
    final c = build();
    await c.load();
    return c;
  }

  group('load', () {
    blocTest<TransferCubit, TransferState>(
      'goes loading → content with contacts, balance and recent names',
      build: build,
      act: (c) => c.load(),
      expect: () => [
        const TransferState(),
        isA<TransferState>()
            .having((s) => s.status, 'status', TransferStatus.content)
            .having((s) => s.contacts, 'contacts', demoContacts)
            .having((s) => s.balance, 'balance', const Money.paise(5624690))
            .having((s) => s.recentRecipients, 'recent', ['Meera Kulkarni']),
      ],
    );

    blocTest<TransferCubit, TransferState>(
      'puts recently paid contacts first',
      build: build,
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.visibleContacts.first.name, 'Meera Kulkarni');
        expect(c.state.visibleContacts.length, demoContacts.length);
      },
    );

    blocTest<TransferCubit, TransferState>(
      'reports a contact failure',
      build: build,
      setUp: () => when(
        contacts.getContacts,
      ).thenAnswer((_) async => const Failure('boom')),
      act: (c) => c.load(),
      expect: () => [
        const TransferState(),
        const TransferState(status: TransferStatus.error, message: 'boom'),
      ],
    );

    blocTest<TransferCubit, TransferState>(
      'reports a balance failure',
      build: build,
      setUp: () => when(
        users.getCurrentUser,
      ).thenAnswer((_) async => const Failure('db')),
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.status, TransferStatus.error);
        expect(c.state.message, 'Could not read your balance');
      },
    );

    blocTest<TransferCubit, TransferState>(
      'a missing user or ledger failure still shows the form with ₹0',
      build: build,
      setUp: () {
        when(users.getCurrentUser).thenAnswer((_) async => const Success(null));
        when(
          () => transactions.getRecentTransactions(limit: any(named: 'limit')),
        ).thenAnswer((_) async => const Failure('ledger'));
      },
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.status, TransferStatus.content);
        expect(c.state.balance, Money.zero);
        expect(c.state.recentRecipients, isEmpty);
      },
    );

    test(
      'a retry keeps what was typed and only the newest load wins',
      () async {
        final c = build()
          ..digit(5)
          ..noteChanged('rent');
        await c.load();
        c.selectContact('c-priya');
        await c.load();
        expect(c.state.amount.text, '5');
        expect(c.state.note, 'rent');
        expect(c.state.selectedId, 'c-priya');
        await c.close();
      },
    );
  });

  group('contacts', () {
    test('selecting an unknown id is ignored', () async {
      final c = await loaded();
      c.selectContact('nope');
      expect(c.state.selected, isNull);
      c.selectContact('c-rohan');
      expect(c.state.selected?.name, 'Rohan Iyer');
      await c.close();
    });

    test(
      'the query filters visible contacts without touching the list',
      () async {
        final c = await loaded();
        c.queryChanged('ok');
        expect(c.state.visibleContacts.map((x) => x.id), [
          'c-meera',
          'c-priya',
          'c-sneha',
          'c-ananya',
        ]);
        expect(c.state.contacts.length, demoContacts.length);
        c.queryChanged('zzz');
        expect(c.state.visibleContacts, isEmpty);
        await c.close();
      },
    );
  });

  group('amount', () {
    test('keys, decimal and backspace edit the amount', () async {
      final c = await loaded();
      c
        ..digit(1)
        ..digit(2)
        ..decimal()
        ..digit(5);
      expect(c.state.amount.text, '12.5');
      c.backspace();
      expect(c.state.amount.text, '12.');
      expect(c.state.amountError, isNull);
      await c.close();
    });

    test('a quick chip replaces the amount', () async {
      final c = await loaded();
      c
        ..digit(7)
        ..quickAmount(AmountRules.quickAmounts[1]);
      expect(c.state.amount.text, '1000');
      await c.close();
    });

    test(
      'crossing into an error shakes once, staying in error does not',
      () async {
        final c = await loaded();
        for (var i = 0; i < 5; i++) {
          c.digit(9);
        }
        expect(c.state.amount.text, '99999');
        expect(c.state.amountError, AmountError.overBalance);
        expect(c.state.shakes, 1);
        c.digit(9);
        expect(c.state.shakes, 1);
        c.digit(9);
        expect(c.state.amountError, AmountError.overMax);
        expect(c.state.shakes, 1);
        c
          ..backspace()
          ..backspace()
          ..backspace();
        expect(c.state.amountError, isNull);
        c.digit(9);
        expect(c.state.shakes, 2);
        await c.close();
      },
    );

    test('a valid paste replaces the amount; an invalid one shakes', () async {
      final c = await loaded();
      expect(c.pasteAmount('１,２３４.５'), isTrue);
      expect(c.state.amount.text, '1234.5');
      expect(c.state.shakes, 0);
      expect(c.pasteAmount('-5'), isFalse);
      expect(c.pasteAmount('abc'), isFalse);
      expect(c.pasteAmount('9' * 100000), isFalse);
      expect(c.state.amount.text, '1234.5');
      expect(c.state.shakes, 3);
      await c.close();
    });

    test(
      'a pasted amount over the balance shakes through the error path',
      () async {
        final c = await loaded();
        expect(c.pasteAmount('99,999'), isTrue);
        expect(c.state.amountError, AmountError.overBalance);
        expect(c.state.shakes, 1);
        await c.close();
      },
    );

    test('the note is sanitised', () async {
      final c = await loaded();
      c.noteChanged('  rent \u202E for\u0000 may  ');
      expect(c.state.note, 'rent for may');
      await c.close();
    });
  });

  group('createDraft', () {
    test('is null until a contact and a valid amount exist', () async {
      final c = await loaded();
      expect(c.state.canContinue, isFalse);
      expect(c.createDraft(), isNull);
      c.digit(5);
      expect(c.createDraft(), isNull);
      c.selectContact('c-priya');
      expect(c.state.canContinue, isTrue);
      expect(c.createDraft(), isNotNull);
      await c.close();
    });

    test('is null while loading or in error', () async {
      final c = build()
        ..digit(5)
        ..selectContact('c-priya');
      expect(c.createDraft(), isNull);
      await c.close();
    });

    test('carries recipient, VPA, amount, note and a fresh key', () async {
      final c = await loaded();
      c
        ..selectContact('c-priya')
        ..digit(1)
        ..digit(2)
        ..decimal()
        ..digit(5)
        ..noteChanged('chai');
      final a = c.createDraft()!;
      expect(a.recipientName, 'Priya Raghavan');
      expect(a.recipientAccount, 'priya.r@okaxis');
      expect(a.amount, const Money.paise(1250));
      expect(a.note, 'chai');
      expect(a.idempotencyKey, startsWith('transfer-'));
      expect(a.idempotencyKey, matches(RegExp(r'^transfer-\d+-[0-9a-f]{8}$')));
      final b = c.createDraft()!;
      expect(b.idempotencyKey, isNot(a.idempotencyKey));
      expect(b.copyWith(idempotencyKey: a.idempotencyKey), a);
      await c.close();
    });

    test('an empty note becomes null', () async {
      final c = await loaded();
      c
        ..selectContact('c-priya')
        ..digit(5)
        ..noteChanged('   ');
      expect(c.createDraft()!.note, isNull);
      await c.close();
    });

    test('keys are unique across 10,000 drafts on a fixed clock', () async {
      final c = await loaded();
      c
        ..selectContact('c-priya')
        ..digit(5);
      final keys = {for (var i = 0; i < 10000; i++) c.newIdempotencyKey()};
      expect(keys.length, 10000);
      await c.close();
    });

    test('over-balance and over-max amounts never produce a draft', () async {
      final c = await loaded();
      c.selectContact('c-priya');
      expect(c.pasteAmount('56,246.91'), isTrue);
      expect(c.createDraft(), isNull);
      expect(c.pasteAmount('56,246.90'), isTrue);
      expect(c.createDraft(), isNotNull);
      await c.close();
    });
  });

  test('state toString carries neither the balance nor the amount', () async {
    final c = await loaded();
    c.digit(7);
    final text = c.state.toString();
    expect(text, 'TransferState(content)');
    expect(text, isNot(contains('5624690')));
    expect(AmountInput.empty.digit(7).toString(), isNot(contains('7')));
    await c.close();
  });
}
