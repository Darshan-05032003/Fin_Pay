import 'dart:async';

import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/repositories/demo_contact_repository.dart';
import 'package:fin_pay/domain/repositories/contact_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'home_cards_fixtures.dart';
import 'screen_harness.dart';

class MockContactRepository extends Mock implements IContactRepository {}

/// The draft every review / success test starts from.
const TransferDraft fixtureDraft = TransferDraft(
  recipientName: 'Priya Raghavan',
  recipientAccount: 'priya.r@okaxis',
  amount: Money.paise(125000),
  idempotencyKey: 'transfer-1-abcdef01',
  note: 'chai',
);

/// The receipt the success screen shows.
final PaymentReceipt fixtureReceipt = PaymentReceipt(
  draft: fixtureDraft,
  reference: 'FPTEST000001',
  paidAt: DateTime.utc(2026, 10, 31, 4),
);

/// Home/cards repositories plus contacts and a fake bank, stubbed for the
/// transfer flow: the ledger records once per key and reports duplicates,
/// and "Meera Kulkarni" was paid most recently.
class TransferRepos extends HomeCardsRepos {
  TransferRepos({FakePaymentGateway? gateway, super.now})
    : gateway = gateway ?? FakePaymentGateway() {
    when(
      contacts.getContacts,
    ).thenAnswer((_) async => const Success(demoContacts));
    when(
      () => txns.getRecentTransactions(limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Success([
        Transaction(
          id: 'recent-1',
          title: 'Sent to Meera Kulkarni',
          amount: const Money.paise(-50000),
          date: DateTime.utc(2026, 10, 30),
          type: TransactionType.sendMoney,
          icon: 'send',
          recipient: 'Meera Kulkarni',
        ),
        ...transactions.take(4),
      ]),
    );
    when(() => txns.addTransaction(any())).thenAnswer((invocation) async {
      final t = invocation.positionalArguments.first as Transaction;
      ledgerCalls.add(t);
      if (ledgerGate != null) await ledgerGate!.future;
      if (!recordedKeys.add(t.idempotencyKey)) {
        return const Success(TransactionOutcome.duplicate);
      }
      return Success(ledgerOutcome);
    });
  }

  final MockContactRepository contacts = MockContactRepository();
  final FakePaymentGateway gateway;

  /// Every `addTransaction` call, in order.
  final List<Transaction> ledgerCalls = [];
  final Set<String> recordedKeys = {};

  /// Outcome of the first write per key (duplicates are automatic).
  TransactionOutcome ledgerOutcome = TransactionOutcome.recorded;

  /// When set, every ledger write waits for it.
  Completer<void>? ledgerGate;

  @override
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
    contactRepository: contacts,
    paymentGateway: gateway,
  );
}

/// Installs a fake platform clipboard. [text] is what `getData` returns;
/// everything set through `setData` lands in [copied].
class FakeClipboard {
  FakeClipboard(WidgetTester tester, {this.text = ''}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.getData':
            return {'text': text};
          case 'Clipboard.setData':
            copied.add((call.arguments as Map)['text'] as String);
            return null;
          case 'Clipboard.hasStrings':
            return {'value': text.isNotEmpty};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  String text;
  final List<String> copied = [];
}
