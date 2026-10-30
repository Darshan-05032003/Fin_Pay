import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

void main() {
  group('FpCollapseMath', () {
    test('fraction runs 0 → 1 across the shrink range and clamps', () {
      double f(double o) =>
          FpCollapseMath.fraction(o, maxExtent: 260, minExtent: 60);
      expect(f(0), 0);
      expect(f(100), 0.5);
      expect(f(200), 1);
      expect(f(500), 1);
      expect(f(-20), 0);
    });

    test('a header that cannot shrink is always collapsed', () {
      expect(FpCollapseMath.fraction(0, maxExtent: 60, minExtent: 60), 1);
      expect(FpCollapseMath.fraction(10, maxExtent: 40, minExtent: 60), 1);
    });

    test('lerp and fades', () {
      expect(FpCollapseMath.lerp(56, 24, 0), 56);
      expect(FpCollapseMath.lerp(56, 24, 0.5), 40);
      expect(FpCollapseMath.lerp(56, 24, 1), 24);
      expect(FpCollapseMath.lerp(56, 24, 2), 24);
      expect(FpCollapseMath.fadeOut(0), 1);
      expect(FpCollapseMath.fadeOut(0.3), closeTo(0.5, 1e-9));
      expect(FpCollapseMath.fadeOut(0.6), 0);
      expect(FpCollapseMath.fadeOut(1), 0);
      expect(FpCollapseMath.fadeIn(0), 0);
      expect(FpCollapseMath.fadeIn(0.6), 0);
      expect(FpCollapseMath.fadeIn(0.8), closeTo(0.5, 1e-9));
      expect(FpCollapseMath.fadeIn(1), 1);
      expect(FpCollapseMath.fadeOut(0.5, until: 0), 0);
      expect(FpCollapseMath.fadeIn(0.5, from: 1), 1);
    });
  });

  group('FpCollapsingHeader', () {
    testWidgets('hands the builder the collapse fraction while scrolling', (
      tester,
    ) async {
      final seen = <double>[];
      await pumpFp(
        tester,
        CustomScrollView(
          slivers: [
            FpCollapsingHeader(
              expandedHeight: 200,
              collapsedHeight: 80,
              builder: (context, t) {
                seen.add(t);
                return ColoredBox(
                  key: const ValueKey('hdr'),
                  color: FpColors.surface,
                  child: Center(child: Text('t=${t.toStringAsFixed(2)}')),
                );
              },
            ),
            SliverList.builder(
              itemCount: 50,
              itemBuilder: (context, i) =>
                  SizedBox(height: 40, child: Text('Row $i')),
            ),
          ],
        ),
        scaffold: false,
      );
      expect(find.text('t=0.00'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('hdr'))).height, 200);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -60));
      await tester.pump();
      expect(find.text('t=0.50'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(find.text('t=1.00'), findsOneWidget);
      // Pinned: the collapsed bar stays at its minimum height.
      expect(tester.getSize(find.byKey(const ValueKey('hdr'))).height, 80);
      expect(seen.every((t) => t >= 0 && t <= 1), isTrue);
    });

    test('delegate rebuilds only when extents or the key change', () {
      Widget b(BuildContext c, double t) => const SizedBox();
      final a = FpCollapsingHeaderDelegate(
        expandedHeight: 200,
        collapsedHeight: 80,
        builder: b,
        rebuildKey: 1,
      );
      expect(
        a.shouldRebuild(
          FpCollapsingHeaderDelegate(
            expandedHeight: 200,
            collapsedHeight: 80,
            builder: b,
            rebuildKey: 1,
          ),
        ),
        isFalse,
      );
      expect(
        a.shouldRebuild(
          FpCollapsingHeaderDelegate(
            expandedHeight: 200,
            collapsedHeight: 80,
            builder: b,
            rebuildKey: 2,
          ),
        ),
        isTrue,
      );
      expect(
        a.shouldRebuild(
          FpCollapsingHeaderDelegate(
            expandedHeight: 220,
            collapsedHeight: 80,
            builder: b,
            rebuildKey: 1,
          ),
        ),
        isTrue,
      );
      expect(a.maxExtent, 200);
      expect(a.minExtent, 80);
    });
  });
}
