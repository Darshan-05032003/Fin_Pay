import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/home/home_screen.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  Future<void> open(WidgetTester tester, {String at = AppRoutes.home}) async {
    await h.init(tester, signedIn: true);
    await h.pump(tester, at);
    await h.settle(tester);
    // These tests run on the real in-memory database; every tab in the
    // IndexedStack reads it on mount (home ×3, stats, cards), so let those
    // reads finish before the test body continues.
    await h.flush(tester, rounds: 6);
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(FpBottomNav), matching: find.text(label)),
    );
    await tester.pump();
    await h.settle(tester);
    // The legacy statistics / profile tabs read the database on first show
    // and call setState when it answers; let that finish while mounted.
    await h.flush(tester, rounds: 3);
  }

  testWidgets('home shows the four-tab bar with Home selected and no back '
      'arrow', (tester) async {
    await open(tester);
    expect(find.byType(FpBottomNav), findsOneWidget);
    for (final item in AppShell.items) {
      expect(find.text(item.label), findsWidgets, reason: item.label);
    }
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(h.location, AppRoutes.home);
  });

  testWidgets('switching tabs keeps every branch mounted (state persists)', (
    tester,
  ) async {
    await open(tester);
    await tapTab(tester, 'Cards');
    expect(h.location, AppRoutes.cards);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.selection));
    await tapTab(tester, 'Stats');
    expect(h.location, AppRoutes.statistics);
    await tapTab(tester, 'Profile');
    expect(h.location, AppRoutes.profile);
    await tapTab(tester, 'Home');
    expect(h.location, AppRoutes.home);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    // One bar for the whole shell, never one per tab.
    expect(find.byType(FpBottomNav), findsOneWidget);
  });

  testWidgets('system back on a non-home tab goes home; on home it exits', (
    tester,
  ) async {
    await open(tester);
    await tapTab(tester, 'Cards');
    expect(h.location, AppRoutes.cards);
    expect(await h.router!.routerDelegate.popRoute(), isTrue);
    await tester.pump();
    await h.settle(tester);
    expect(h.location, AppRoutes.home);
    // Nothing left to pop: the system is told to leave the app.
    expect(await h.router!.routerDelegate.popRoute(), isFalse);
    await tester.pump();
    expect(h.location, AppRoutes.home);
  });

  testWidgets('FLAG_SECURE is on for home, stats and cards, off for '
      'profile', (tester) async {
    await open(tester);
    expect(h.protector.enabled, isTrue);
    await tapTab(tester, 'Stats');
    expect(h.protector.enabled, isTrue, reason: 'totals on screen (F6)');
    await tapTab(tester, 'Cards');
    expect(h.protector.enabled, isTrue);
    await tapTab(tester, 'Profile');
    expect(h.protector.enabled, isFalse);
    await tapTab(tester, 'Home');
    expect(h.protector.enabled, isTrue);
  });

  testWidgets('card routes are pushed over the bar on the root navigator', (
    tester,
  ) async {
    await open(tester, at: AppRoutes.cardDetailsFor('c1'));
    // These screens read the real (in-memory) database here; let it answer.
    await h.flush(tester);
    expect(h.location, '/cards/c1');
    expect(find.byType(FpBottomNav), findsNothing);
    h.router!.go(AppRoutes.addCard);
    await tester.pump();
    await h.settle(tester);
    await h.flush(tester);
    expect(h.location, AppRoutes.addCard);
    expect(find.byType(FpBottomNav), findsNothing);
  });

  testWidgets('card routes cannot be opened while signed out', (tester) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.cardDetailsFor('c1'));
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
    h.router!.go(AppRoutes.addCard);
    await tester.pump();
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('re-selecting the current tab fires the reselect notifier', (
    tester,
  ) async {
    await open(tester);
    final shell = tester.element(find.byType(HomeScreen));
    final reselect = AppShell.reselectOf(shell)!;
    expect(reselect.count, 0);
    await tapTab(tester, 'Home');
    expect(reselect.count, 1);
    expect(reselect.index, 0);
    expect(h.location, AppRoutes.home);
  });

  testWidgets('1.3× text scale: the bar does not overflow', (tester) async {
    await h.init(tester, signedIn: true);
    await h.pump(tester, AppRoutes.home, textScale: 1.3);
    await h.settle(tester);
    await h.flush(tester, rounds: 3);
    expect(tester.takeException(), isNull);
    expect(find.byType(FpBottomNav), findsOneWidget);
  });
}
