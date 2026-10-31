import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/statistics/widgets/stats_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'insights_activity_fixtures.dart';
import 'screen_harness.dart';

void main() {
  late ScreenHarness h;
  late InsightsRepos repos;

  setUp(() => h = ScreenHarness());

  Future<void> open(
    WidgetTester tester, {
    int rows = 40,
    double scale = 1,
    bool rm = false,
    AppSettings settings = AppSettings.defaults,
  }) async {
    repos = InsightsRepos(ledgerRows: rows);
    await repos.init(h, tester: tester, initialSettings: settings);
    await h.pump(
      tester,
      AppRoutes.statistics,
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
    // Odometers in the total cards count up for about half a second.
    await tester.pump(const Duration(seconds: 1));
  }

  Finder bars() => find.byKey(const ValueKey('stats-bars'));

  /// The semantics label of the amount inside the total card [key].
  String totalLabel(WidgetTester tester, String key) => tester
      .getSemantics(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(FpAmountText),
        ),
      )
      .label;

  /// The rendered spend rod of the newest bucket (chart data as drawn).
  double todaySpendRod(WidgetTester tester) {
    final chart = tester.widget<BarChart>(
      find.descendant(of: bars(), matching: find.byType(BarChart)),
    );
    return chart.data.barGroups.last.barRods.first.toY;
  }

  group('states', () {
    testWidgets('loading: skeleton while the period is pending', (
      tester,
    ) async {
      repos = InsightsRepos();
      final gate = Completer<Result<List<Transaction>>>();
      when(
        () => repos.txns.getTransactionsBetween(any(), any()),
      ).thenAnswer((_) => gate.future);
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.statistics);
      await tester.pump();
      expect(find.byKey(const ValueKey('stats-skeleton')), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-period')), findsOneWidget);
      expect(h.protector.enabled, isTrue, reason: 'totals → FLAG_SECURE');
      gate.complete(Success(repos.ledger));
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('stats-skeleton')), findsNothing);
      expect(bars(), findsOneWidget);
    });

    testWidgets('empty: "No spends yet"', (tester) async {
      await open(tester, rows: 0);
      expect(find.text('No spends yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-empty')), findsOneWidget);
      expect(bars(), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('error: message and retry', (tester) async {
      repos = InsightsRepos();
      var calls = 0;
      when(() => repos.txns.getTransactionsBetween(any(), any())).thenAnswer((
        _,
      ) async {
        calls++;
        return calls == 1
            ? const Failure('Storage unavailable')
            : Success(repos.ledger);
      });
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.statistics);
      await h.settle(tester);
      expect(find.text('Could not load insights'), findsOneWidget);
      expect(find.text('Storage unavailable'), findsOneWidget);
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(bars(), findsOneWidget);
    });

    testWidgets('content: totals, three charts, legend and top merchants', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('SPENT'), findsOneWidget);
      expect(find.text('RECEIVED'), findsOneWidget);
      expect(totalLabel(tester, 'stats-spent'), startsWith('Spent ₹'));
      expect(totalLabel(tester, 'stats-received'), startsWith('Received ₹'));
      expect(bars(), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-line')), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-donut')), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Cart'), findsOneWidget);
      expect(find.byKey(const ValueKey('stats-merchants')), findsOneWidget);
      expect(find.text('Grocery run'), findsOneWidget);
      expect(find.text('Tap a bar to inspect'), findsOneWidget);
      // Week labels along the bottom axis.
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('hide balance masks totals, merchants and tooltips', (
      tester,
    ) async {
      await open(tester, settings: const AppSettings(hideBalance: true));
      expect(totalLabel(tester, 'stats-spent'), 'Spent hidden');
      expect(find.text(FpAmountText.masked), findsWidgets);
      final chart = tester.widget<StatsBarChart>(bars());
      expect(chart.hidden, isTrue);
    });
  });

  group('charts', () {
    testWidgets('bars grow in: partway through the entrance the rod is '
        'shorter than at the end', (tester) async {
      repos = InsightsRepos();
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.statistics);
      await tester.pump();
      await tester.pump();
      // Stagger + entrance: sample early, then at the end.
      await tester.pump(const Duration(milliseconds: 120));
      final early = todaySpendRod(tester);
      await tester.pump(const Duration(seconds: 2));
      final full = todaySpendRod(tester);
      expect(full, greaterThan(0));
      expect(early, lessThan(full));
    });

    testWidgets('reduce motion: charts appear complete at once', (
      tester,
    ) async {
      repos = InsightsRepos();
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.statistics, reduceMotion: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final first = todaySpendRod(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(todaySpendRod(tester), first);
      expect(first, greaterThan(0));
    });

    testWidgets('the period switcher reloads and re-animates the charts', (
      tester,
    ) async {
      await open(tester);
      final weekKey = tester
          .widget(find.byKey(const ValueKey('stats-content-1')))
          .key;
      expect(weekKey, isNotNull);
      await tester.tap(find.text('Year'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final early = todaySpendRod(tester);
      await h.settle(tester);
      await tester.pump(const Duration(seconds: 1));
      final full = todaySpendRod(tester);
      expect(early, lessThan(full), reason: 'grows again');
      expect(find.byKey(const ValueKey('stats-content-2')), findsOneWidget);
      // Local midnights of the host zone, as storage compares UTC instants.
      verify(
        () => repos.txns.getTransactionsBetween(
          DateTime(2025, 11).toUtc(),
          DateTime(2026, 11).toUtc(),
        ),
      ).called(1);
      expect(find.text('Nov'), findsOneWidget, reason: 'every 2nd month');
      expect(h.haptics.calls, contains(HapticType.selection));
      final line = tester.widget<LineChart>(find.byType(LineChart));
      expect(line.data.lineBarsData.single.spots.length, 365);
    });

    testWidgets('tapping a bar shows its tooltip; tapping again hides it', (
      tester,
    ) async {
      await open(tester);
      final chartRect = tester.getRect(
        find.descendant(of: bars(), matching: find.byType(BarChart)),
      );
      // Seven groups spaced around; the spend rod sits left of each centre.
      final groupWidth = chartRect.width / 7;
      final x = chartRect.left + groupWidth * 6.5 - 6;
      final y = chartRect.bottom - 22 - 6;
      await tester.tapAt(Offset(x, y));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('stats-tooltip')), findsOneWidget);
      expect(find.textContaining('Sat: spent ₹'), findsOneWidget);
      await tester.tapAt(Offset(x, y));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('stats-tooltip')), findsNothing);
      // The line chart's built-in tooltip survives a tap too.
      await tester.tap(find.byType(LineChart));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('1.3×: no overflow and guidelines met', (tester) async {
      await open(tester, scale: 1.3);
      expect(tester.takeException(), isNull);
      await expectGuidelines(tester);
    });

    testWidgets('charts expose a textual description', (tester) async {
      await open(tester);
      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(bars()).label,
        contains('Bar chart: Sun spent'),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('stats-donut'))).label,
        contains('Donut chart:'),
      );
      handle.dispose();
    });
  });
}
