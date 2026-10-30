import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FpMotion durations', () {
    test('fast 150, standard 250, emphasized 400, screen 450', () {
      expect(FpMotion.fast, const Duration(milliseconds: 150));
      expect(FpMotion.standard, const Duration(milliseconds: 250));
      expect(FpMotion.emphasized, const Duration(milliseconds: 400));
      expect(FpMotion.screen, const Duration(milliseconds: 450));
      expect(FpMotion.durations.length, 4);
    });

    test('small UI motion sits in 200–300 ms, screens in 350–500 ms', () {
      expect(FpMotion.standard.inMilliseconds, inInclusiveRange(200, 300));
      expect(FpMotion.screen.inMilliseconds, inInclusiveRange(350, 500));
      expect(FpMotion.fast.inMilliseconds, lessThan(100 + 100));
    });
  });

  group('FpMotion curves', () {
    test('no curve is linear', () {
      for (final entry in FpMotion.curves.entries) {
        final c = entry.value;
        expect(c, isNot(Curves.linear), reason: entry.key);
        // A linear curve would return exactly t at every sample.
        final samples = [0.1, 0.25, 0.5, 0.75, 0.9];
        final deviations = samples.map((t) => (c.transform(t) - t).abs());
        expect(
          deviations.reduce((a, b) => a > b ? a : b),
          greaterThan(0.02),
          reason: '${entry.key} is linear',
        );
      }
    });

    test('curves are monotonic and start/end at 0/1', () {
      for (final entry in FpMotion.curves.entries) {
        final c = entry.value;
        expect(c.transform(0), 0, reason: entry.key);
        expect(c.transform(1), 1, reason: entry.key);
        var last = 0.0;
        for (var i = 1; i <= 100; i++) {
          final v = c.transform(i / 100);
          expect(v, greaterThanOrEqualTo(last - 1e-9), reason: entry.key);
          last = v;
        }
      }
    });

    test('decelerate is fast early, accelerate is slow early', () {
      expect(FpMotion.emphasizedDecelerate.transform(0.3), greaterThan(0.6));
      expect(FpMotion.emphasizedAccelerate.transform(0.3), lessThan(0.2));
    });
  });

  group('FpMotion.of', () {
    testWidgets('reads MediaQuery.disableAnimations', (tester) async {
      late FpMotion normal;
      late FpMotion reduced;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              normal = FpMotion.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = FpMotion.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(normal.reduce, isFalse);
      expect(reduced.reduce, isTrue);
      expect(normal.scaled(FpMotion.standard), FpMotion.standard);
      expect(reduced.scaled(FpMotion.standard), Duration.zero);
      expect(normal.curveOr(FpMotion.standardCurve), FpMotion.standardCurve);
      expect(reduced.curveOr(FpMotion.standardCurve), Curves.easeOut);
    });
  });

  group('FpSprings', () {
    test('presets are under- or critically damped and settle quickly', () {
      for (final entry in FpSprings.all.entries) {
        final s = entry.value;
        final ratio = FpSprings.dampingRatio(s);
        expect(ratio, inInclusiveRange(0.6, 1.0), reason: entry.key);
        expect(s.mass, greaterThan(0));
        expect(s.stiffness, greaterThan(0));
        final sim = FpSprings.simulation(s, start: 0, end: 1);
        expect(sim.isDone(1), isTrue, reason: '${entry.key} settles in 1 s');
        expect(sim.x(0), 0);
        expect(sim.x(5), closeTo(1, 0.001));
      }
    });

    test('press spring is stiffer than sheet spring', () {
      expect(FpSprings.press.stiffness, greaterThan(FpSprings.sheet.stiffness));
      expect(
        FpSprings.slider.stiffness,
        greaterThan(FpSprings.press.stiffness),
      );
    });

    test('simulation honours velocity and never overshoots by > 10 %', () {
      final sim = FpSprings.simulation(
        FpSprings.press,
        start: 1,
        end: 0,
        velocity: -2,
      );
      expect(sim.dx(0), -2);
      var min = 1.0;
      for (var t = 0.0; t < 1; t += 0.005) {
        final x = sim.x(t);
        if (x < min) min = x;
      }
      expect(min, greaterThan(-0.1));
      expect(sim, isA<SpringSimulation>());
    });
  });
}
