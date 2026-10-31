@Tags(['golden'])
library;

import 'dart:async';

import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget/screens/insights_activity_fixtures.dart';
import '../../widget/screens/screen_harness.dart';

/// Statistics, transactions, notifications and profile in their main states
/// at 1.0× and 1.3×. Baselines live in `goldens/insights_<state>_<scale>.png`;
/// regenerate with
/// `flutter test --update-goldens test/golden/screens/insights_activity_golden_test.dart`
/// only when a change is intended.
///
/// The fixture "now" is a *local* noon, so every time label renders the same
/// digits in any zone (CI runs in UTC, the author's machine in IST).
void main() {
  late ScreenHarness h;
  late InsightsRepos repos;
  final localNoon = DateTime(2026, 10, 31, 12);

  setUp(() => h = ScreenHarness());

  Future<void> boot(
    WidgetTester tester, {
    int rows = 40,
    AppSettings settings = AppSettings.defaults,
  }) async {
    repos = InsightsRepos(ledgerRows: rows, now: localNoon);
    await repos.init(h, tester: tester, initialSettings: settings);
  }

  Future<void> snap(
    WidgetTester tester,
    String name,
    double scale, {
    Duration settle = const Duration(seconds: 3),
  }) async {
    await tester.pump(settle);
    await tester.pump();
    final s = scale.toStringAsFixed(1).replaceAll('.', '_');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/insights_${name}_$s.png'),
    );
  }

  Finder scrollable(String key) => find
      .descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Scrollable),
      )
      .first;

  for (final scale in [1.0, 1.3]) {
    group('${scale}x', () {
      testWidgets('statistics loading', (tester) async {
        await boot(tester);
        final gate = Completer<Result<List<Transaction>>>();
        when(
          () => repos.txns.getTransactionsBetween(any(), any()),
        ).thenAnswer((_) => gate.future);
        await h.pump(tester, AppRoutes.statistics, textScale: scale);
        await snap(
          tester,
          'statistics_loading',
          scale,
          settle: const Duration(milliseconds: 300),
        );
        gate.complete(const Success([]));
        await h.settle(tester);
      });

      testWidgets('statistics empty', (tester) async {
        await boot(tester, rows: 0);
        await h.pump(tester, AppRoutes.statistics, textScale: scale);
        await snap(tester, 'statistics_empty', scale);
      });

      testWidgets('statistics week and month', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.statistics, textScale: scale);
        await snap(tester, 'statistics_week', scale);
        await tester.tap(find.text('Month'));
        await tester.pump();
        await snap(tester, 'statistics_month', scale);
      });

      testWidgets('transactions loading', (tester) async {
        await boot(tester);
        final gate = Completer<Result<List<Transaction>>>();
        when(
          () => repos.txns.getTransactions(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) => gate.future);
        await h.pump(tester, AppRoutes.transactions, textScale: scale);
        await snap(
          tester,
          'transactions_loading',
          scale,
          settle: const Duration(milliseconds: 300),
        );
        gate.complete(const Success([]));
        await h.settle(tester);
      });

      testWidgets('transactions empty', (tester) async {
        await boot(tester, rows: 0);
        await h.pump(tester, AppRoutes.transactions, textScale: scale);
        await snap(tester, 'transactions_empty', scale);
      });

      testWidgets('transactions content, filtered and swiped', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.transactions, textScale: scale);
        await snap(tester, 'transactions_content', scale);
        await tester.tap(find.byKey(const ValueKey('filter-sent')));
        await tester.pump();
        await snap(tester, 'transactions_filtered', scale);
        await tester.tap(find.byKey(const ValueKey('filter-all')));
        await tester.pump();
        await h.settle(tester);
        await tester.dragFrom(
          tester.getCenter(find.byKey(const ValueKey('tx-tx000001'))),
          const Offset(-120, 0),
        );
        await tester.pump();
        await snap(tester, 'transactions_swiped', scale);
      });

      testWidgets('notifications empty', (tester) async {
        await boot(tester);
        when(
          () => repos.notes.getNotifications(limit: any(named: 'limit')),
        ).thenAnswer((_) async => const Success([]));
        when(
          repos.notes.getNotifications,
        ).thenAnswer((_) async => const Success([]));
        await h.pump(tester, AppRoutes.notifications, textScale: scale);
        await snap(tester, 'notifications_empty', scale);
      });

      testWidgets('notifications unread and all read', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.notifications, textScale: scale);
        await snap(tester, 'notifications_unread', scale);
        await tester.tap(find.byKey(const ValueKey('notifications-mark-all')));
        await tester.pump();
        await snap(tester, 'notifications_content', scale);
      });

      testWidgets('profile default and hide balance on', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.profile, textScale: scale);
        await snap(tester, 'profile_default', scale);
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('setting-hide-balance')),
            matching: find.byType(FpToggle),
          ),
        );
        await tester.pump();
        await snap(tester, 'profile_hide_balance', scale);
        expect(h.settingsRepo.settings.hideBalance, isTrue);
      });

      testWidgets('profile logout sheet', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.profile, textScale: scale);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('profile-logout')),
          200,
          scrollable: scrollable('profile-scroll'),
        );
        await tester.tap(find.byKey(const ValueKey('profile-logout')));
        await tester.pump();
        await snap(tester, 'profile_logout_sheet', scale);
      });
    });
  }
}
