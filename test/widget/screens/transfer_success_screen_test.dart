import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:fin_pay/screens/transfer/widgets/receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';
import 'transfer_fixtures.dart';

void main() {
  late ScreenHarness h;
  late TransferRepos repos;

  setUp(() {
    h = ScreenHarness();
    repos = TransferRepos();
  });

  Future<void> open(
    WidgetTester tester, {
    PaymentReceipt? receipt,
    double scale = 1,
    bool rm = false,
  }) async {
    await repos.init(h, tester: tester);
    await h.pump(
      tester,
      AppRoutes.transferSuccess,
      extra: receipt ?? fixtureReceipt,
      textScale: scale,
      reduceMotion: rm,
    );
    await tester.pump();
  }

  testWidgets('content: check, headline, amount, receipt rows with a masked '
      'VPA, protected', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('success-check')), findsOneWidget);
    expect(find.byType(FpConfetti), findsOneWidget);
    await h.settle(tester);
    expect(find.text('Payment sent'), findsOneWidget);
    expect(find.bySemanticsLabel('Amount ₹1,250.00'), findsOneWidget);
    expect(find.text('to Priya Raghavan'), findsOneWidget);
    expect(find.byType(ReceiptCard), findsOneWidget);
    expect(find.text('pr•••••@okaxis'), findsOneWidget);
    expect(find.text('priya.r@okaxis'), findsNothing);
    expect(find.text('FPTEST000001'), findsOneWidget);
    expect(find.text('chai'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.textContaining('31 Oct 2026'), findsOneWidget);
    expect(h.protector.enabled, isTrue);
  });

  testWidgets('the drawn check triggers one confetti burst and one success '
      'haptic', (tester) async {
    await open(tester);
    expect(h.haptics.calls, isNot(contains(HapticType.success)));
    await h.settle(tester);
    expect(h.haptics.calls.where((c) => c == HapticType.success).length, 1);
    // Confetti is animating: a ticker is alive until the burst ends.
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('already paid changes the headline and status', (tester) async {
    await open(
      tester,
      receipt: PaymentReceipt(
        draft: fixtureDraft.copyWith(note: ''),
        reference: 'FPTEST000001',
        paidAt: DateTime.utc(2026, 10, 31, 4),
        alreadyPaid: true,
      ),
    );
    await h.settle(tester);
    expect(find.text('Already paid'), findsNWidgets(2));
    expect(find.text('Payment sent'), findsNothing);
    expect(find.text('Note'), findsNothing);
  });

  testWidgets('share receipt opens a sheet; copy puts the masked text on '
      'the clipboard and toasts', (tester) async {
    final clipboard = FakeClipboard(tester);
    await open(tester);
    await h.settle(tester);
    await tapButton(tester, 'Share receipt');
    await h.settle(tester);
    expect(find.byKey(const ValueKey('receipt-share-text')), findsOneWidget);
    expect(find.textContaining('FinPay receipt'), findsOneWidget);
    await tapButton(tester, 'Copy receipt');
    await h.settle(tester);
    expect(clipboard.copied, hasLength(1));
    final text = clipboard.copied.single;
    expect(text, contains('₹1,250.00 to Priya Raghavan (pr•••••@okaxis)'));
    expect(text, contains('Reference FPTEST000001'));
    expect(text, contains('Note: chai'));
    expect(text, isNot(contains('priya.r@okaxis')));
    expect(text, isNot(contains(fixtureDraft.idempotencyKey)));
    expect(find.text('Receipt copied'), findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-share-text')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('done and system back both go home', (tester) async {
    await open(tester);
    await h.settle(tester);
    await tapButton(tester, 'Done');
    await h.settle(tester);
    expect(h.location, AppRoutes.home);
    await h.flush(tester);
    await h.pump(tester, AppRoutes.transferSuccess, extra: fixtureReceipt);
    await h.settle(tester);
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await h.settle(tester);
    expect(h.location, AppRoutes.home);
    await h.flush(tester);
  });

  testWidgets('reduce motion: no confetti ticker, check shown at once, '
      'haptic still plays', (tester) async {
    await open(tester, rm: true);
    await tester.pump();
    expect(h.haptics.calls, contains(HapticType.success));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('Payment sent'), findsOneWidget);
  });

  testWidgets('meets the guidelines at 1.3x', (tester) async {
    await open(tester, scale: 1.3);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });

  testWidgets('without a receipt the guard screen shows', (tester) async {
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.transferSuccess, extra: fixtureDraft);
    await h.settle(tester);
    expect(find.text('Start a transfer from the home screen.'), findsOneWidget);
    expect(find.byType(ReceiptCard), findsNothing);
  });
}
