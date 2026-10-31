import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/payments/payment_gateway.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:fin_pay/screens/transfer/widgets/drawn_cross.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'screen_harness.dart';
import 'transfer_fixtures.dart';

Finder get _thumb => find.byKey(const ValueKey('fp-swipe-thumb'));
Finder get _slider => find.byKey(const ValueKey('review-swipe'));
Finder get _summary => find.byKey(const ValueKey('review-summary'));
Finder get _processing => find.byKey(const ValueKey('review-processing'));
Finder get _failure => find.byKey(const ValueKey('review-failure'));

void main() {
  late ScreenHarness h;
  late TransferRepos repos;

  setUp(() {
    h = ScreenHarness();
    repos = TransferRepos();
  });

  Future<void> open(
    WidgetTester tester, {
    TransferDraft draft = fixtureDraft,
    FakePaymentGateway? gateway,
    double scale = 1,
    bool rm = false,
  }) async {
    if (gateway != null) repos = TransferRepos(gateway: gateway);
    await repos.init(h, tester: tester);
    await h.pump(
      tester,
      AppRoutes.transferReview,
      extra: draft,
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
  }

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(_thumb, const Offset(420, 0));
    await tester.pump();
    await h.settle(tester);
  }

  group('content', () {
    testWidgets('shows payee, VPA, amount, note, fee and total; protected; '
        'slider idle', (tester) async {
      await open(tester);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Priya Raghavan'), findsOneWidget);
      expect(find.text('priya.r@okaxis'), findsOneWidget);
      expect(find.bySemanticsLabel('Amount ₹1,250.00'), findsOneWidget);
      expect(find.text('chai'), findsOneWidget);
      expect(find.text('₹0.00'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('SWIPE TO PAY ₹1,250.00'), findsOneWidget);
      expect(h.protector.enabled, isTrue);
      expect(_summary, findsOneWidget);
      expect(_processing, findsNothing);
    });

    testWidgets('a draft without a note omits the note line', (tester) async {
      await open(tester, draft: fixtureDraft.copyWith(note: ''));
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('without a typed draft the guard screen shows', (tester) async {
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.transferReview, extra: {'amount': '1'});
      await h.settle(tester);
      expect(
        find.text('Start a transfer from the home screen.'),
        findsOneWidget,
      );
      expect(_slider, findsNothing);
    });
  });

  group('swipe', () {
    testWidgets('below the threshold snaps back and pays nothing', (
      tester,
    ) async {
      await open(tester);
      h.haptics.reset();
      final rest = tester.getCenter(_thumb).dx;
      await tester.drag(_thumb, const Offset(90, 0));
      await tester.pump();
      await h.settle(tester);
      expect(tester.getCenter(_thumb).dx, closeTo(rest, 0.5));
      expect(repos.gateway.authorizeCalls, isEmpty);
      expect(repos.ledgerCalls, isEmpty);
      expect(h.haptics.calls, [HapticType.selection]);
      expect(h.location, AppRoutes.transferReview);
    });

    testWidgets('past the threshold: ticks, heavy haptic, processing ring, '
        'then success with the receipt', (tester) async {
      final gateway = FakePaymentGateway(gated: true);
      await open(tester, gateway: gateway);
      h.haptics.reset();
      await tester.drag(_thumb, const Offset(420, 0));
      await tester.pump();
      await tester.pump();
      expect(
        h.haptics.calls,
        containsAllInOrder([
          HapticType.selection,
          HapticType.selection,
          HapticType.selection,
          HapticType.heavy,
        ]),
      );
      await h.settle(tester);
      expect(_processing, findsOneWidget);
      expect(find.byType(FpProcessingRing), findsWidgets);
      expect(find.text('Contacting your bank'), findsOneWidget);
      expect(_summary, findsNothing);
      expect(repos.ledgerCalls, isEmpty);
      gateway.release();
      await h.settle(tester);
      expect(h.location, AppRoutes.transferSuccess);
      final receipt = h.extra! as PaymentReceipt;
      expect(receipt.draft, fixtureDraft);
      expect(receipt.reference, 'FPTEST000001');
      expect(receipt.alreadyPaid, isFalse);
      expect(repos.ledgerCalls, hasLength(1));
      expect(repos.ledgerCalls.single.amount, const Money.paise(-125000));
      expect(
        repos.ledgerCalls.single.idempotencyKey,
        fixtureDraft.idempotencyKey,
      );
      expect(find.text('Payment sent'), findsOneWidget);
      // The review screen was replaced: back from success goes home.
      expect(find.byType(DrawnCross), findsNothing);
    });

    testWidgets('fifty rapid swipes, taps and a multi-touch drag while the '
        'bank is slow → one ledger write', (tester) async {
      final gateway = FakePaymentGateway(gated: true);
      await open(tester, gateway: gateway);
      final a = await tester.startGesture(tester.getCenter(_thumb));
      final b = await tester.startGesture(
        tester.getCenter(_thumb) + const Offset(0, 8),
        pointer: 2,
      );
      await a.moveBy(const Offset(420, 0));
      await b.moveBy(const Offset(420, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();
      for (var i = 0; i < 50; i++) {
        final g = await tester.startGesture(
          tester.getCenter(_thumb),
          pointer: 10 + i,
        );
        await g.moveBy(const Offset(420, 0));
        await g.up();
        await tester.tap(_slider, warnIfMissed: false);
      }
      await h.settle(tester);
      expect(gateway.authorizeCalls, hasLength(1));
      gateway.release();
      await h.settle(tester);
      expect(repos.ledgerCalls, hasLength(1));
      expect(h.location, AppRoutes.transferSuccess);
    });

    testWidgets('the semantics button pays once for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      tester.semantics.performAction(
        find.semantics.byLabel('Swipe to pay ₹1,250.00'),
        SemanticsAction.tap,
      );
      await h.settle(tester);
      expect(repos.ledgerCalls, hasLength(1));
      expect(h.location, AppRoutes.transferSuccess);
      handle.dispose();
    });
  });

  group('mid-payment', () {
    testWidgets('back is blocked with a toast while processing, then the '
        'payment completes', (tester) async {
      final gateway = FakePaymentGateway(gated: true);
      await open(tester, gateway: gateway);
      await swipe(tester);
      expect(_processing, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back'), warnIfMissed: false);
      await tester.pump();
      expect(h.location, AppRoutes.transferReview);
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pump();
      expect(h.location, AppRoutes.transferReview);
      expect(find.text('Payment in progress. Please wait.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      gateway.release();
      await h.settle(tester);
      expect(h.location, AppRoutes.transferSuccess);
      expect(repos.ledgerCalls, hasLength(1));
    });

    testWidgets('backgrounding mid-payment neither duplicates nor sticks', (
      tester,
    ) async {
      final gateway = FakePaymentGateway(gated: true);
      await open(tester, gateway: gateway);
      await swipe(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_processing, findsOneWidget);
      await tester.drag(_thumb, const Offset(-300, 0));
      await tester.pump();
      gateway.release();
      await h.settle(tester);
      expect(h.location, AppRoutes.transferSuccess);
      expect(repos.ledgerCalls, hasLength(1));
    });

    testWidgets('leaving the app while a slow ledger writes still records '
        'once and the next visit is already paid', (tester) async {
      repos.ledgerGate = Completer<void>();
      await open(tester);
      await swipe(tester);
      expect(find.text('Recording the payment'), findsOneWidget);
      // Simulate a process restore: a new review for the same draft.
      repos.ledgerGate!.complete();
      await h.settle(tester);
      expect(h.location, AppRoutes.transferSuccess);
      await h.pump(tester, AppRoutes.transferReview, extra: fixtureDraft);
      await h.settle(tester);
      await swipe(tester);
      expect(h.location, AppRoutes.transferSuccess);
      expect((h.extra! as PaymentReceipt).alreadyPaid, isTrue);
      expect(find.text('Already paid'), findsWidgets);
      expect(repos.recordedKeys, hasLength(1));
    });
  });

  group('failure', () {
    testWidgets('a declined bank: cross, shake, error haptic, edit payment '
        'and back to home; nothing written', (tester) async {
      await open(
        tester,
        gateway: FakePaymentGateway(
          authorizeResults: const [GatewayDeclined('Your bank said no.')],
        ),
      );
      h.haptics.reset();
      await swipe(tester);
      expect(_failure, findsOneWidget);
      expect(find.byType(DrawnCross), findsOneWidget);
      expect(find.text('Payment declined'), findsOneWidget);
      expect(find.textContaining('Your bank said no.'), findsOneWidget);
      expect(find.byKey(const ValueKey('failure-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('failure-retry')), findsNothing);
      expect(h.haptics.calls, contains(HapticType.error));
      expect(repos.ledgerCalls, isEmpty);
      expect(h.protector.enabled, isTrue);
      await tapButton(tester, 'Back to home');
      await h.settle(tester);
      expect(h.location, AppRoutes.home);
      await h.flush(tester);
    });

    testWidgets('a settlement timeout offers Retry; the retry is already '
        'paid and writes nothing new', (tester) async {
      await open(
        tester,
        gateway: FakePaymentGateway(settleResults: const [GatewayTimedOut()]),
      );
      await swipe(tester);
      expect(find.text('Bank did not confirm'), findsOneWidget);
      expect(find.byKey(const ValueKey('failure-retry')), findsOneWidget);
      expect(repos.ledgerCalls, hasLength(1));
      h.haptics.reset();
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(h.location, AppRoutes.transferSuccess);
      final receipt = h.extra! as PaymentReceipt;
      expect(receipt.alreadyPaid, isTrue);
      expect(repos.ledgerCalls, hasLength(2));
      expect(repos.recordedKeys, hasLength(1));
      expect(find.text('Already paid'), findsWidgets);
    });

    testWidgets('insufficient balance: the ledger decides, edit amount '
        'pops to the form', (tester) async {
      repos.ledgerOutcome = TransactionOutcome.insufficientBalance;
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.transfer);
      await h.settle(tester);
      unawaited(h.router!.push(AppRoutes.transferReview, extra: fixtureDraft));
      await h.settle(tester);
      await swipe(tester);
      expect(find.text('Insufficient balance'), findsOneWidget);
      expect(find.byKey(const ValueKey('failure-edit')), findsOneWidget);
      expect(find.text('EDIT AMOUNT'), findsOneWidget);
      await tapButton(tester, 'Edit amount');
      await h.settle(tester);
      expect(h.location, AppRoutes.transfer);
    });

    testWidgets('a storage failure retries and then succeeds', (tester) async {
      var fail = true;
      await repos.init(h, tester: tester);
      final original = repos.txns;
      // Fail the first write, then fall back to the fixture behaviour.
      when(() => original.addTransaction(any())).thenAnswer((inv) async {
        if (fail) {
          fail = false;
          return const Failure('disk full');
        }
        repos.ledgerCalls.add(inv.positionalArguments.first as Transaction);
        return const Success(TransactionOutcome.recorded);
      });
      await h.pump(tester, AppRoutes.transferReview, extra: fixtureDraft);
      await h.settle(tester);
      await swipe(tester);
      expect(find.text('Could not save the payment'), findsOneWidget);
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(h.location, AppRoutes.transferSuccess);
      expect(repos.ledgerCalls, hasLength(1));
    });

    testWidgets('a tampered extra (negative amount) never reaches the bank '
        'or the ledger', (tester) async {
      await open(
        tester,
        draft: fixtureDraft.copyWith(amount: const Money.paise(-125000)),
      );
      await swipe(tester);
      expect(find.text('Invalid payment'), findsOneWidget);
      expect(repos.gateway.authorizeCalls, isEmpty);
      expect(repos.ledgerCalls, isEmpty);
      expect(find.text('EDIT AMOUNT'), findsOneWidget);
    });

    testWidgets('a tampered extra (over the maximum) is refused', (
      tester,
    ) async {
      await open(
        tester,
        draft: fixtureDraft.copyWith(amount: const Money.paise(10000001)),
      );
      await swipe(tester);
      expect(find.text('Invalid payment'), findsOneWidget);
      expect(repos.ledgerCalls, isEmpty);
    });

    testWidgets('a second failure shakes again and counts attempts', (
      tester,
    ) async {
      await open(
        tester,
        gateway: FakePaymentGateway(
          authorizeResults: const [GatewayTimedOut(), GatewayTimedOut()],
        ),
      );
      await swipe(tester);
      expect(find.text('Could not reach your bank'), findsOneWidget);
      h.haptics.reset();
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(find.text('Attempt 2'), findsOneWidget);
      expect(h.haptics.calls, contains(HapticType.error));
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(h.location, AppRoutes.transferSuccess);
    });
  });

  group('accessibility and motion', () {
    testWidgets('reduce motion replaces the slider with a button that pays '
        'once', (tester) async {
      await open(tester, rm: true);
      expect(_thumb, findsNothing);
      await tapButton(tester, 'Swipe to pay ₹1,250.00');
      // The second tap lands while the page is already leaving.
      await tester.tap(find.byType(FpButton), warnIfMissed: false);
      await h.settle(tester);
      expect(repos.ledgerCalls, hasLength(1));
      expect(h.location, AppRoutes.transferSuccess);
    });

    testWidgets('meets the guidelines at 1.3x in idle and failure', (
      tester,
    ) async {
      await open(
        tester,
        gateway: FakePaymentGateway(
          authorizeResults: const [GatewayDeclined('No.')],
        ),
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await expectGuidelines(tester);
      await swipe(tester);
      expect(tester.takeException(), isNull);
      await expectGuidelines(tester);
    });

    testWidgets('leaves no ticker or effect listener behind', (tester) async {
      await open(tester);
      await tester.drag(_thumb, const Offset(60, 0));
      await h.settle(tester);
      await h.dispose(tester);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
