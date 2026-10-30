@Tags(['stress'])
library;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stress_guard.dart';

/// Design-system load tests. Run with:
///
///   flutter test --tags stress --dart-define=FINPAY_STRESS=true \
///     --concurrency=1 test/stress
///
/// Numbers are printed and recorded in docs/LOAD_TEST_REPORT.md.
void main() {
  if (!stressGuard()) return;

  Future<void> pump(WidgetTester tester, Widget child, {Size? size}) async {
    if (size != null) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: FpTheme.dark(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('1,000 rapid taps on FpButton produce exactly one call', (
    tester,
  ) async {
    var calls = 0;
    await pump(
      tester,
      Center(
        child: FpButton(label: 'Pay', onPressed: () => calls++),
      ),
    );
    final center = tester.getCenter(find.byType(FpButton));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await tester.tapAt(center);
    }
    sw.stop();
    await tester.pumpAndSettle();
    debugPrint(
      '[stress] 1000 taps dispatched in ${sw.elapsedMilliseconds} ms, '
      'onPressed calls: $calls',
    );
    expect(calls, 1);
  });

  testWidgets('10k FpSurface rows: fling and measure frame build times', (
    tester,
  ) async {
    await pump(
      tester,
      ListView.builder(
        itemCount: 10000,
        itemExtent: 72,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FpSpacing.lg,
            vertical: FpSpacing.xs,
          ),
          child: FpSurface(
            onTap: () {},
            padding: const EdgeInsets.symmetric(horizontal: FpSpacing.lg),
            child: Row(
              children: [
                Expanded(child: Text('Row $i', style: FpTypography.body)),
                Text('₹${i * 7}.00', style: FpTypography.numeric),
              ],
            ),
          ),
        ),
      ),
      size: const Size(430, 900),
    );
    final buildTimes = <int>[];
    for (var round = 0; round < 5; round++) {
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 6000);
      for (var f = 0; f < 60; f++) {
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        sw.stop();
        buildTimes.add(sw.elapsedMicroseconds);
      }
    }
    await tester.pumpAndSettle();
    buildTimes.sort();
    final avg = buildTimes.reduce((a, b) => a + b) / buildTimes.length;
    final p90 = buildTimes[(buildTimes.length * 0.9).floor()];
    final p99 = buildTimes[(buildTimes.length * 0.99).floor()];
    final over16 = buildTimes.where((t) => t > 16000).length;
    debugPrint(
      '[stress] 10k rows fling: ${buildTimes.length} frames, '
      'avg ${(avg / 1000).toStringAsFixed(2)} ms, '
      'p90 ${(p90 / 1000).toStringAsFixed(2)} ms, '
      'p99 ${(p99 / 1000).toStringAsFixed(2)} ms, '
      'frames > 16 ms: $over16',
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FpSurface), findsWidgets);
  });

  testWidgets('FpAmountText 0 → max 100× without leaking tickers', (
    tester,
  ) async {
    var paise = 0;
    await pump(tester, Center(child: FpAmountText(paise: paise)));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      paise = paise == 0 ? 99999999999 : 0;
      await pump(tester, Center(child: FpAmountText(paise: paise)));
      await tester.pump(const Duration(milliseconds: 500));
    }
    sw.stop();
    await tester.pump(const Duration(seconds: 1));
    debugPrint(
      '[stress] odometer 100 rolls in ${sw.elapsedMilliseconds} ms, '
      'tickers after: ${SchedulerBinding.instance.transientCallbackCount}',
    );
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FpConfetti 50 bursts', (tester) async {
    final controller = FpConfettiController();
    addTearDown(controller.dispose);
    await pump(
      tester,
      FpConfetti(controller: controller, child: const SizedBox.expand()),
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 50; i++) {
      controller.burst();
      for (var f = 0; f < 10; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    sw.stop();
    await tester.pump(const Duration(seconds: 2));
    debugPrint(
      '[stress] 50 confetti bursts (500 frames) in ${sw.elapsedMilliseconds} '
      'ms, tickers after: ${SchedulerBinding.instance.transientCallbackCount}',
    );
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(controller.bursts, 50);
  });

  testWidgets('50 skeletons shimmering: one shared ticker', (tester) async {
    await pump(
      tester,
      FpSkeletonGroup(
        child: ListView(
          children: [for (var i = 0; i < 50; i++) const FpSkeletonRow()],
        ),
      ),
      size: const Size(430, 4000),
    );
    final sw = Stopwatch()..start();
    for (var f = 0; f < 120; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    sw.stop();
    final tickers = SchedulerBinding.instance.transientCallbackCount;
    debugPrint(
      '[stress] 200 skeleton blocks, 120 frames in ${sw.elapsedMilliseconds} '
      'ms (${(sw.elapsedMilliseconds / 120).toStringAsFixed(2)} ms/frame), '
      'active tickers: $tickers',
    );
    expect(find.byType(FpSkeleton), findsNWidgets(200));
    expect(tickers, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
