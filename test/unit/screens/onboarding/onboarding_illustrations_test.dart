import 'package:fin_pay/screens/onboarding/onboarding_illustrations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingParallax.layerShift', () {
    test('a layer at speed 1 moves with the page (no extra shift)', () {
      expect(OnboardingParallax.layerShift(0.5, width: 400, speed: 1), 0);
    });

    test('slower layers lag behind the page in proportion', () {
      // Page is half a width to the left of this page (delta +0.5): a
      // 0.4-speed layer counter-shifts by 60 % of that distance.
      expect(
        OnboardingParallax.layerShift(0.5, width: 400, speed: 0.4),
        closeTo(120, 1e-9),
      );
      expect(
        OnboardingParallax.layerShift(-0.5, width: 400, speed: 0.4),
        closeTo(-120, 1e-9),
      );
      expect(
        OnboardingParallax.layerShift(0.5, width: 400, speed: 0),
        closeTo(200, 1e-9),
      );
    });

    test('delta is clamped to one page so layers never fly off', () {
      expect(
        OnboardingParallax.layerShift(3, width: 400, speed: 0.5),
        closeTo(200, 1e-9),
      );
      expect(
        OnboardingParallax.layerShift(-3, width: 400, speed: 0.5),
        closeTo(-200, 1e-9),
      );
    });

    test('different speeds give different shifts for the same swipe', () {
      final shifts = [
        for (final s in OnboardingParallax.speeds)
          OnboardingParallax.layerShift(0.3, width: 400, speed: s),
      ];
      expect(shifts.toSet().length, shifts.length);
      expect(OnboardingParallax.speeds.length, 3);
    });
  });

  test('every page has three layers', () {
    for (final page in OnboardingPageSpec.all) {
      expect(page.title, isNotEmpty);
      expect(page.body, isNotEmpty);
      expect(page.layers.length, 3);
    }
  });
}
