// On-device flows (spec §6 "integration_test/"):
//
//   (a) onboarding → login → home → Send money → contact → amount → review
//       → swipe to pay → success → transactions shows the new row;
//   (b) add card → appears in the stack;
//   (c) the decline path through the "Test Decline" contact.
//
// Run on an attached device (one at a time; see README "Tests"):
//
//   flutter test integration_test/app_flows_test.dart -d <device id>
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/app_flows_test.dart --no-dds -d <device id>
//
// The swipe-to-pay and card-stack sections are wrapped in
// `binding.traceAction` / `binding.watchPerformance`, so the drive run also
// writes `build/perf/*.timeline_summary.json`.
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('onboarding → login → send money → swipe to pay → success → '
      'the transaction is listed', (tester) async {
    await launchApp(tester);
    await reachLogin(tester);
    await signIn(tester);

    const amountDigits = '120';
    await startTransfer(tester, contactId: 'c-priya', digits: amountDigits);
    expect(find.textContaining('Priya Raghavan'), findsWidgets);

    await traced(binding, () async {
      await swipeToPay(tester);
      await pumpUntil(tester, key('success-check'));
    }, reportKey: 'swipe_to_pay_timeline');

    await pumpUntil(tester, key('success-done'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.textContaining('Priya Raghavan'), findsWidgets);
    await backHome(tester, 'success-done');

    await tapKey(tester, 'home-action-history');
    await pumpUntil(tester, key('transactions-scroll'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.textContaining('Sent to Priya Raghavan'), findsWidgets);
  });

  testWidgets('add card → the stack shows one more card', (tester) async {
    await launchApp(tester);
    if (find.byType(AppShell).evaluate().isEmpty) {
      await reachLogin(tester);
      await signIn(tester);
    }
    await tapTab(tester, 'Cards');
    await pumpUntil(tester, key('cards-scroll'));
    await pumpFor(tester, const Duration(seconds: 1));
    final before = _pileCount(tester);

    await addDemoCard(
      tester,
      number: freshTestPan(),
      name: 'Aarav Mehta',
      expiry: '12/30',
      cvv: '321',
    );
    expect(_pileCount(tester), before + 1);

    await watched(binding, () async {
      await tester.ensureVisible(key('cards-pile'));
      await tester.pump();
      await tapKey(tester, 'cards-pile');
      await pumpFor(tester, const Duration(milliseconds: 1200));
      await tester.drag(key('card-carousel'), const Offset(-320, 0));
      await pumpFor(tester, const Duration(milliseconds: 800));
      await tapKey(tester, 'cards-collapse');
      await pumpFor(tester, const Duration(milliseconds: 800));
    }, reportKey: 'card_stack_performance');
  });

  testWidgets('"Test Decline" is declined and the user can go home', (
    tester,
  ) async {
    await launchApp(tester);
    if (find.byType(AppShell).evaluate().isEmpty) {
      await reachLogin(tester);
      await signIn(tester);
    }
    await startTransfer(tester, contactId: 'c-decline', digits: '50');
    await swipeToPay(tester);
    await pumpUntil(tester, key('review-failure'));
    expect(find.text('Payment declined'), findsOneWidget);
    expect(key('success-check'), findsNothing);
    await backHome(tester, 'failure-home');
  });
}

/// The card count from the pile hint ("3 cards · tap the pile to fan out")
/// or the focused summary; 0 when the stack is empty.
int _pileCount(WidgetTester tester) {
  final hint = RegExp(r'^(\d+) cards?');
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final match = hint.firstMatch(text.data ?? '');
    if (match != null) return int.parse(match.group(1)!);
  }
  return 0;
}
