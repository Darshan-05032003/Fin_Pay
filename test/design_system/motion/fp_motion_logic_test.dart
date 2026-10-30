import 'package:fake_async/fake_async.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FpOdometer.plan', () {
    test('"1,234" → "9,876" rolls every digit up, separator stays', () {
      final plan = FpOdometer.plan('1,234', '9,876');
      expect(plan.length, 5);
      expect(plan[0].steps, ['1', '2', '3', '4', '5', '6', '7', '8', '9']);
      expect(plan[1].steps, [',']);
      expect(plan[1].isStatic, isTrue);
      expect(plan[2].steps, ['2', '3', '4', '5', '6', '7', '8']);
      expect(plan[3].steps, ['3', '4', '5', '6', '7']);
      expect(plan[4].steps, ['4', '5', '6']);
    });

    test('decreasing values roll down', () {
      final plan = FpOdometer.plan('9,876', '1,234');
      expect(plan[0].steps, ['9', '8', '7', '6', '5', '4', '3', '2', '1']);
      expect(plan[4].steps, ['6', '5', '4']);
    });

    test('digits wrap through 9 → 0 when increasing', () {
      final plan = FpOdometer.plan('19', '21');
      expect(plan[0].steps, ['1', '2']);
      expect(plan[1].steps, ['9', '0', '1']);
    });

    test('digits wrap through 0 → 9 when decreasing', () {
      final plan = FpOdometer.plan('21', '19');
      expect(plan[1].steps, ['1', '0', '9']);
    });

    test('new positions on the left start blank', () {
      final plan = FpOdometer.plan('₹9.99', '₹10.00');
      expect(plan.length, 6);
      expect(plan[0].steps, ['', '₹']);
      expect(plan[1].steps, ['₹', '1']);
      expect(plan[1].start, '₹');
      expect(plan[1].end, '1');
      expect(plan[2].steps, ['9', '0']);
      expect(plan[3].steps, ['.']);
    });

    test('identical strings are fully static', () {
      final plan = FpOdometer.plan('₹1,00,000.00', '₹1,00,000.00');
      expect(plan.every((r) => r.isStatic), isTrue);
    });

    test('handles the maximum amount and a shrink', () {
      final max = FpAmountText.format(99999999999);
      expect(max, '₹99,99,99,999.99');
      final plan = FpOdometer.plan('₹0.00', max);
      expect(plan.length, max.length);
      expect(plan.last.steps, List.generate(10, (i) => '$i'));
      final back = FpOdometer.plan(max, '₹0.00');
      expect(back.length, max.length);
      expect(back.first.steps, ['₹', '']);
    });

    test('ascending compares digits only and ignores leading zeros', () {
      expect(FpOdometer.ascending('₹0.00', '₹1.00'), isTrue);
      expect(FpOdometer.ascending('₹1.00', '₹0.00'), isFalse);
      expect(FpOdometer.ascending('00', '0'), isTrue);
      expect(FpOdometer.ascending('₹9.99', '₹10.00'), isTrue);
    });

    test('FpDigitRoll equality and toString', () {
      expect(const FpDigitRoll(['1', '2']), const FpDigitRoll(['1', '2']));
      expect(const FpDigitRoll(['1']), isNot(const FpDigitRoll(['2'])));
      expect(
        const FpDigitRoll(['1']).hashCode,
        const FpDigitRoll(['1']).hashCode,
      );
      expect(const FpDigitRoll(['1', '2']).toString(), 'FpDigitRoll(1 → 2)');
    });
  });

  group('FpAmountText.format', () {
    test('uses Indian grouping and two decimals', () {
      expect(FpAmountText.format(0), '₹0.00');
      expect(FpAmountText.format(5), '₹0.05');
      expect(FpAmountText.format(12345678), '₹1,23,456.78');
      expect(FpAmountText.format(100000000), '₹10,00,000.00');
      expect(FpAmountText.format(-4500), '-₹45.00');
      expect(FpAmountText.format(99999999999), '₹99,99,99,999.99');
    });
  });

  group('FpStagger.delays', () {
    test('index * step when under the cap', () {
      final d = FpStagger.delays(4, step: const Duration(milliseconds: 50));
      expect(d, [
        Duration.zero,
        const Duration(milliseconds: 50),
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 150),
      ]);
    });

    test('compresses so the last child starts at the cap', () {
      final d = FpStagger.delays(100);
      expect(d.length, 100);
      expect(d.first, Duration.zero);
      expect(d.last, const Duration(milliseconds: 480));
      for (var i = 1; i < d.length; i++) {
        expect(d[i] >= d[i - 1], isTrue);
      }
    });

    test('empty and single child', () {
      expect(FpStagger.delays(0), isEmpty);
      expect(FpStagger.delays(1), [Duration.zero]);
    });

    test('fpStaggerTotal is last delay plus duration', () {
      expect(
        fpStaggerTotal(3, step: const Duration(milliseconds: 100)),
        const Duration(milliseconds: 200) + FpMotion.emphasized,
      );
      expect(fpStaggerTotal(0), Duration.zero);
      expect(fpStaggerTotal(1000), FpStagger.defaultCap + FpMotion.emphasized);
    });
  });

  group('FpShakeController', () {
    test('shake() increments and notifies', () {
      var notified = 0;
      final c = FpShakeController()
        ..addListener(() => notified++)
        ..shake()
        ..shake();
      expect(c.shakeCount, 2);
      expect(notified, 2);
      c.dispose();
    });

    test('offsetAt is zero at both ends, bounded by amplitude, decays', () {
      final c = FpShakeController(amplitude: 10);
      expect(c.offsetAt(0), 0);
      expect(c.offsetAt(1).abs(), lessThan(1e-9));
      var peak = 0.0;
      for (var t = 0.0; t <= 1; t += 0.01) {
        final v = c.offsetAt(t).abs();
        expect(v, lessThanOrEqualTo(10));
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(5));
      // Later peaks are smaller than earlier ones.
      expect(c.offsetAt(1 / 12).abs(), greaterThan(c.offsetAt(9 / 12).abs()));
      expect(c.offsetAt(-1), 0);
      expect(c.offsetAt(2).abs(), lessThan(1e-9));
      c.dispose();
    });
  });

  group('FpSubmitGuard', () {
    test('sync action: runs once, then locked for 300 ms', () {
      fakeAsync((async) {
        final guard = FpSubmitGuard();
        var calls = 0;
        for (var i = 0; i < 1000; i++) {
          guard.run(() => calls++);
        }
        expect(calls, 1);
        expect(guard.isLocked, isTrue);
        async.elapse(const Duration(milliseconds: 299));
        expect(guard.run(() => calls++), isFalse);
        async.elapse(const Duration(milliseconds: 2));
        expect(guard.isLocked, isFalse);
        expect(guard.run(() => calls++), isTrue);
        expect(calls, 2);
        guard.dispose();
      });
    });

    test('async action: locked until the future completes', () {
      fakeAsync((async) {
        var calls = 0;
        final slow = Future<void>.delayed(const Duration(seconds: 2));
        final guard = FpSubmitGuard()
          ..run(() {
            calls++;
            return slow;
          });
        async.elapse(const Duration(seconds: 1));
        expect(guard.run(() => calls++), isFalse);
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        expect(guard.isLocked, isFalse);
        expect(calls, 1);
        guard.dispose();
      });
    });

    test('a failing future still unlocks', () {
      fakeAsync((async) {
        final guard = FpSubmitGuard()
          ..run(() => Future<void>.error(StateError('boom')));
        async.elapse(const Duration(milliseconds: 350));
        expect(guard.isLocked, isFalse);
        guard.dispose();
      });
    });

    test('a throwing sync action unlocks and rethrows', () {
      final guard = FpSubmitGuard();
      expect(() => guard.run(() => throw StateError('x')), throwsStateError);
      expect(guard.isLocked, isFalse);
      guard.dispose();
    });
  });

  group('FpParallax.translation', () {
    test('scales by factor and clamps', () {
      expect(FpParallax.translation(100, factor: 0.5), -50);
      expect(FpParallax.translation(100, factor: 0.5, clamp: 20), -20);
      expect(FpParallax.translation(-100, factor: 1, clamp: 20), 20);
      expect(FpParallax.translation(0, factor: 2), 0);
    });
  });

  group('FpBottomSheet.shouldDismiss', () {
    test('fling down dismisses, fling up keeps, else position decides', () {
      expect(FpBottomSheet.shouldDismiss(visible: 0.9, velocity: 800), isTrue);
      expect(
        FpBottomSheet.shouldDismiss(visible: 0.2, velocity: -800),
        isFalse,
      );
      expect(FpBottomSheet.shouldDismiss(visible: 0.4, velocity: 0), isTrue);
      expect(FpBottomSheet.shouldDismiss(visible: 0.6, velocity: 0), isFalse);
    });
  });

  group('FpConfettiBurst', () {
    test('is deterministic per seed, falls under gravity and fades out', () {
      final a = FpConfettiBurst(count: 10, colors: const [Colors.red], seed: 1);
      final b = FpConfettiBurst(count: 10, colors: const [Colors.red], seed: 1);
      final c = FpConfettiBurst(count: 10, colors: const [Colors.red], seed: 2);
      expect(a.particles.length, 10);
      expect(a.particles.first.x, b.particles.first.x);
      expect(a.particles.first.x == c.particles.first.x, isFalse);
      final p = a.particles.first;
      expect(a.positionAt(p, 0), Offset(p.x, p.y));
      expect(a.positionAt(p, 1).dy, greaterThan(a.positionAt(p, 0.3).dy));
      expect(a.opacityAt(0.5), 1);
      expect(a.opacityAt(1), 0);
      expect(a.opacityAt(0.85), closeTo(0.5, 0.01));
    });
  });
}
