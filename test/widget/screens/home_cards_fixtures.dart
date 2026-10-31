import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'screen_harness.dart';

class MockCardRepository extends Mock implements ICardRepository {}

class MockTransactionRepository extends Mock
    implements ITransactionRepository {}

class MockUserRepository extends Mock implements IUserRepository {}

/// Three demo cards (one per supported network), newest first.
const List<PaymentCard> fixtureCards = [
  PaymentCard(
    id: 'c1',
    cardNumber: '4111 1111 1111 1111',
    cardHolderName: 'AARAV MEHTA',
    expireDate: '12/28',
    cvv: '987',
    cardType: CardType.visa,
    balance: Money.zero,
  ),
  PaymentCard(
    id: 'c2',
    cardNumber: '5555 5555 5555 4444',
    cardHolderName: 'AARAV MEHTA',
    expireDate: '03/27',
    cvv: '123',
    cardType: CardType.mastercard,
    balance: Money.zero,
  ),
  PaymentCard(
    id: 'c3',
    cardNumber: '6521 0200 0000 0005',
    cardHolderName: 'AARAV MEHTA',
    expireDate: '09/29',
    cvv: '456',
    cardType: CardType.rupay,
    balance: Money.zero,
  ),
];

/// Seven transactions spread over the last days, newest first.
List<Transaction> fixtureTransactions(DateTime now) => [
  Transaction(
    id: 't1',
    title: 'Grocery run',
    amount: const Money.paise(-184900),
    date: now.subtract(const Duration(hours: 2)),
    type: TransactionType.payment,
    icon: 'cart',
  ),
  Transaction(
    id: 't2',
    title: 'Salary',
    amount: const Money.paise(12500000),
    date: now.subtract(const Duration(days: 1, hours: 3)),
    type: TransactionType.receiveMoney,
    icon: 'bank',
  ),
  Transaction(
    id: 't3',
    title: 'Coffee',
    amount: const Money.paise(-32000),
    date: now.subtract(const Duration(days: 1, hours: 6)),
    type: TransactionType.payment,
    icon: 'cup',
  ),
  Transaction(
    id: 't4',
    title: 'Sent to Priya',
    amount: const Money.paise(-250000),
    date: now.subtract(const Duration(days: 3)),
    type: TransactionType.sendMoney,
    icon: 'send',
    recipient: 'Priya',
  ),
  Transaction(
    id: 't5',
    title: 'Wallet top-up',
    amount: const Money.paise(500000),
    date: now.subtract(const Duration(days: 4)),
    type: TransactionType.topUp,
    icon: 'plus',
  ),
  Transaction(
    id: 't6',
    title: 'Electricity bill',
    amount: const Money.paise(-212050),
    date: now.subtract(const Duration(days: 6)),
    type: TransactionType.payment,
    icon: 'bolt',
  ),
  Transaction(
    id: 't7',
    title: 'Cinema',
    amount: const Money.paise(-89000),
    date: now.subtract(const Duration(days: 9)),
    type: TransactionType.payment,
    icon: 'film',
  ),
];

/// Mocked repositories pre-stubbed with the fixtures. Replace a stub to
/// drive a loading (gated future) or error state.
class HomeCardsRepos {
  HomeCardsRepos({DateTime? now}) {
    final at = now ?? DateTime.utc(2026, 10, 31, 12);
    transactions = fixtureTransactions(at);
    registerFallbackValue(fixtureCards.first);
    registerFallbackValue(transactions.first);
    registerFallbackValue(harnessUser);
    registerFallbackValue(at);
    when(cards.getCards).thenAnswer((_) async => const Success(fixtureCards));
    when(
      () => cards.addCard(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => cards.deleteCard(any()),
    ).thenAnswer((_) async => const Success(null));
    when(() => cards.readCvv(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      final card = fixtureCards.where((c) => c.id == id).firstOrNull;
      return Success(card?.cvv);
    });
    when(
      () => txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Success(transactions));
    when(
      () => txns.getRecentTransactions(limit: any(named: 'limit')),
    ).thenAnswer((_) async => Success(transactions.take(5).toList()));
    // The Stats tab (mounted with the shell) reads a date range (F6).
    when(
      () => txns.getTransactionsBetween(any(), any()),
    ).thenAnswer((_) async => Success(transactions));
    when(
      () => txns.addTransaction(any()),
    ).thenAnswer((_) async => const Success(TransactionOutcome.recorded));
    when(users.getCurrentUser).thenAnswer((_) async => Success(harnessUser));
    when(
      () => users.updateUser(any()),
    ).thenAnswer((_) async => const Success(null));
  }

  final MockCardRepository cards = MockCardRepository();
  final MockTransactionRepository txns = MockTransactionRepository();
  final MockUserRepository users = MockUserRepository();
  late final List<Transaction> transactions;

  /// Boots the harness with these repositories.
  Future<void> init(
    ScreenHarness h, {
    required WidgetTester tester,
    bool signedIn = true,
  }) => h.init(
    tester,
    signedIn: signedIn,
    cardRepository: cards,
    transactionRepository: txns,
    userRepository: users,
  );
}

/// A user with no transactions and no cards.
User get emptyUser => harnessUser.copyWith(balance: Money.zero);
