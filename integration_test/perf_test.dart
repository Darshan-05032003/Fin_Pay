// Profile-mode frame traces for the key screens (spec §7b):
//
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/perf_test.dart --profile --no-dds -d <device id>
//
// Each section is a `traceAction` with its own report key, so the driver
// writes one `build/perf/<section>.timeline_summary.json` per screen with
// average / p90 / p99 build and raster times and the missed-frame counts:
// home_collapse, card_stack, transfer_keypad, swipe_to_pay, statistics,
// transactions_scroll.
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame traces per key screen', (tester) async {
    await launchApp(tester);
    if (find.byType(AppShell).evaluate().isEmpty) {
      await reachLogin(tester);
      await signIn(tester);
    }

    // Home: collapse and expand the balance header five times.
    await traced(binding, () async {
      final scroll = key('home-scroll');
      for (var i = 0; i < 5; i++) {
        await tester.timedDrag(
          scroll,
          const Offset(0, -320),
          const Duration(milliseconds: 300),
        );
        await pumpFor(tester, const Duration(milliseconds: 300));
        await tester.timedDrag(
          scroll,
          const Offset(0, 320),
          const Duration(milliseconds: 300),
        );
        await pumpFor(tester, const Duration(milliseconds: 300));
      }
    }, reportKey: 'home_collapse_timeline');

    // Cards: fan out, swipe the carousel, flip, collapse.
    await tapTab(tester, 'Cards');
    await pumpUntil(tester, key('cards-scroll'));
    await pumpFor(tester, const Duration(seconds: 1));
    await traced(binding, () async {
      final pile = key('cards-pile');
      // Cards load from the database first; wait for the pile instead of
      // checking once. A fresh install (the tool reinstalls when switching
      // debug/profile builds, which wipes the database) has no cards, so
      // seed two and measure a real stack.
      try {
        await pumpUntil(
          tester,
          find.byWidgetPredicate(
            (w) =>
                w.key == const ValueKey('cards-pile') ||
                w.key == const ValueKey('cards-empty'),
          ),
        );
      } on TestFailure {
        debugPrint('card_stack: neither a pile nor the empty state appeared');
      }
      if (pile.evaluate().isEmpty && key('cards-empty').evaluate().isNotEmpty) {
        await addDemoCard(
          tester,
          number: freshTestPan(),
          name: 'Perf Card One',
          expiry: '11/31',
          cvv: '123',
        );
        await addDemoCard(
          tester,
          number: freshTestPan(),
          name: 'Perf Card Two',
          expiry: '10/32',
          cvv: '456',
        );
        await pumpUntil(tester, pile);
      }
      if (pile.evaluate().isNotEmpty) {
        await tester.ensureVisible(pile);
        await tester.pump();
        await tester.tap(pile);
        await pumpFor(tester, const Duration(milliseconds: 1200));
        await tester.drag(key('card-carousel'), const Offset(-320, 0));
        await pumpFor(tester, const Duration(milliseconds: 800));
        await tapKey(tester, 'cards-collapse');
        await pumpFor(tester, const Duration(milliseconds: 800));
      }
    }, reportKey: 'card_stack_timeline');

    // Transfer: keypad with the rolling odometer, then swipe to pay.
    await tapTab(tester, 'Home');
    await pumpUntil(tester, key('home-scroll'));
    await tapKey(tester, 'home-action-send');
    await pumpUntil(tester, key('contact-c-rohan'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(key('contact-c-rohan'));
    await tester.pump();
    await traced(binding, () async {
      for (final d in '1234567'.split('')) {
        await tester.tap(key('key-$d'));
        await pumpFor(tester, const Duration(milliseconds: 120));
      }
      for (var i = 0; i < 5; i++) {
        await tester.tap(key('key-backspace'));
        await pumpFor(tester, const Duration(milliseconds: 120));
      }
    }, reportKey: 'transfer_keypad_timeline');
    await tapKey(tester, 'transfer-continue');
    await pumpUntil(tester, key('review-swipe'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await traced(binding, () async {
      await swipeToPay(tester);
      await pumpUntil(tester, key('success-done'));
      await pumpFor(tester, const Duration(seconds: 2));
    }, reportKey: 'swipe_to_pay_timeline');
    await backHome(tester, 'success-done');

    // Statistics: entrance and period switches.
    await traced(binding, () async {
      await tapTab(tester, 'Stats');
      await pumpUntil(tester, key('stats-period'));
      await pumpFor(tester, const Duration(milliseconds: 1500));
      for (final period in ['Month', 'Year', 'Week']) {
        await tester.tap(find.text(period));
        await pumpFor(tester, const Duration(milliseconds: 900));
      }
    }, reportKey: 'statistics_timeline');

    // Transactions: scroll the ledger.
    await tapTab(tester, 'Home');
    await pumpUntil(tester, key('home-scroll'));
    await tapKey(tester, 'home-action-history');
    await pumpUntil(tester, key('transactions-scroll'));
    await pumpFor(tester, const Duration(seconds: 1));
    await traced(binding, () async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(
          key('transactions-scroll'),
          const Offset(0, -600),
          1500,
        );
        await pumpFor(tester, const Duration(milliseconds: 700));
      }
    }, reportKey: 'transactions_scroll_timeline');
  });
}
