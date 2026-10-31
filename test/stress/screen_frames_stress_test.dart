@Tags(['stress'])
library;

import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../widget/screens/home_cards_fixtures.dart';
import '../widget/screens/insights_activity_fixtures.dart';
import '../widget/screens/screen_harness.dart';
import '../widget/screens/transfer_fixtures.dart';
import 'stress_guard.dart';

/// Wave 2 host-side frame-time benchmark, one scenario per key screen, all
/// measured the same way (build + layout + paint of one `tester.pump` on
/// the Linux test host, Dart JIT, software rendering: no raster thread, no
/// GPU, so the numbers are relative, not what a phone shows).
///
///     flutter test --tags stress --dart-define=FINPAY_STRESS=true \
///         --concurrency=1 test/stress/screen_frames_stress_test.dart
///
/// The last test prints one Markdown table for docs/LOAD_TEST_REPORT.md.
void main() {
  if (!stressGuard()) return;

  final rows = <String, FrameStats>{};

  Future<FrameStats> measure(
    WidgetTester tester,
    int frames, {
    Future<void> Function(int frame)? before,
  }) async {
    final micros = <int>[];
    for (var f = 0; f < frames; f++) {
      if (before != null) await before(f);
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      micros.add(sw.elapsedMicroseconds);
    }
    return FrameStats(micros);
  }

  void record(String screen, FrameStats stats) {
    rows[screen] = stats;
    debugPrint('[frames] $screen: $stats');
  }

  List<PaymentCard> manyCards(int n) => [
    for (var i = 0; i < n; i++)
      fixtureCards[i % fixtureCards.length].copyWith(
        id: 'card-$i',
        cardNumber:
            '4111 1111 11${(1000 + i).toString().substring(1)} '
            '${(1000 + i * 7 % 10000).toString().padLeft(4, '0')}',
      ),
  ];

  testWidgets('home: collapsing header over 10 scroll cycles', (tester) async {
    final h = ScreenHarness();
    final repos = HomeCardsRepos();
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.home);
    await h.settle(tester);
    final scroll = find.byKey(const ValueKey('home-scroll'));
    final stats = FrameStats.empty();
    for (var cycle = 0; cycle < 10; cycle++) {
      final gesture = await tester.startGesture(tester.getCenter(scroll));
      stats.addAll(
        await measure(
          tester,
          20,
          before: (f) => gesture.moveBy(Offset(0, f < 10 ? -24 : 24)),
        ),
      );
      await gesture.up();
      stats.addAll(await measure(tester, 10));
    }
    record('Home: header collapse + expand (10 cycles)', stats);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards: 12-card pile fan-out and collapse, 5 times', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = HomeCardsRepos();
    when(repos.cards.getCards).thenAnswer((_) async => Success(manyCards(12)));
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.cards);
    await h.settle(tester);
    final stats = FrameStats.empty();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.bySemanticsLabel(RegExp('tap to fan out')));
      stats.addAll(await measure(tester, 45));
      await tester.tap(find.byKey(const ValueKey('cards-collapse')));
      stats.addAll(await measure(tester, 30));
    }
    record('Cards: 12-card fan-out + collapse (5 cycles)', stats);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer: 300 keypad inputs with the rolling odometer', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = TransferRepos();
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.transfer);
    await h.settle(tester);
    final stats = await measure(
      tester,
      300,
      before: (i) async {
        final key = switch (i % 13) {
          10 => 'dot',
          11 => 'backspace',
          12 => 'backspace',
          final d => '$d',
        };
        await tester.tap(find.byKey(ValueKey('key-$key')), warnIfMissed: false);
      },
    );
    record('Transfer: 300 keypad inputs', stats);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics: year entrance over 365 daily points and 4 '
      'period switches', (tester) async {
    final h = ScreenHarness();
    final repos = InsightsRepos(ledgerRows: 0);
    final year = [
      for (var i = 0; i < 365 * 4; i++)
        Transaction(
          id: 'y$i',
          title: 'Merchant ${i % 23}',
          amount: Money.paise(i % 4 == 0 ? 120000 : -(1000 + i % 777)),
          date: insightsNow.subtract(Duration(hours: 6 * i)),
          type: i % 4 == 0
              ? TransactionType.receiveMoney
              : TransactionType.payment,
          icon: 'c${i % 9}',
        ),
    ];
    when(() => repos.txns.getTransactionsBetween(any(), any())).thenAnswer((
      inv,
    ) async {
      final from = inv.positionalArguments[0] as DateTime;
      final to = inv.positionalArguments[1] as DateTime;
      return Success(
        year
            .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
            .toList(),
      );
    });
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.statistics);
    await tester.pump();
    await tester.tap(find.text('Year'));
    await tester.pump();
    final stats = await measure(tester, 60);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(i.isEven ? 'Month' : 'Year'));
      stats.addAll(await measure(tester, 30));
    }
    record('Statistics: year entrance (365 points) + 4 switches', stats);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transactions: 2,000-row ledger scrolled 20 pages', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = InsightsRepos(ledgerRows: 2000);
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.transactions);
    await h.settle(tester);
    final list = find.byKey(const ValueKey('transactions-scroll'));
    final stats = FrameStats.empty();
    for (var page = 0; page < 20; page++) {
      final gesture = await tester.startGesture(tester.getCenter(list));
      stats.addAll(
        await measure(
          tester,
          12,
          before: (_) => gesture.moveBy(const Offset(0, -50)),
        ),
      );
      await gesture.up();
      stats.addAll(await measure(tester, 6));
    }
    record('Transactions: 2,000 rows, 20 pages scrolled', stats);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    // Rows keep their entrance/swipe tickers while mounted; after the
    // harness unmounts the tree nothing may be left ticking.
    await h.dispose(tester);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  test('consolidated table', () {
    final buffer = StringBuffer()
      ..writeln('| Screen / scenario | Frames | Avg | p90 | p99 | > 16 ms |')
      ..writeln('|---|---:|---:|---:|---:|---:|');
    for (final entry in rows.entries) {
      buffer.writeln('| ${entry.key} | ${entry.value.row} |');
    }
    debugPrint('[frames-table]\n$buffer');
    expect(rows.length, 5);
  });
}

/// Frame build times in microseconds with the percentile summary used in
/// every load report.
class FrameStats {
  FrameStats(List<int> micros) : _micros = [...micros];

  FrameStats.empty() : _micros = [];

  final List<int> _micros;

  void addAll(FrameStats other) => _micros.addAll(other._micros);

  int get frames => _micros.length;

  List<int> get _sorted => [..._micros]..sort();

  double get avgMs => _micros.reduce((a, b) => a + b) / _micros.length / 1000;

  double get p90Ms => _sorted[(_micros.length * 0.9).floor()] / 1000;

  double get p99Ms => _sorted[(_micros.length * 0.99).floor()] / 1000;

  int get over16 => _micros.where((t) => t > 16000).length;

  /// Table cells: frames, avg, p90, p99, > 16 ms.
  String get row =>
      '$frames | ${avgMs.toStringAsFixed(2)} ms | '
      '${p90Ms.toStringAsFixed(2)} ms | ${p99Ms.toStringAsFixed(2)} ms | '
      '$over16';

  @override
  String toString() =>
      '$frames frames, avg ${avgMs.toStringAsFixed(2)} ms, '
      'p90 ${p90Ms.toStringAsFixed(2)} ms, p99 ${p99Ms.toStringAsFixed(2)} '
      'ms, > 16 ms: $over16';
}
