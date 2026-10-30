import 'dart:math' as math;

import 'package:fin_pay/screens/home/home_header_math.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeHeaderMath', () {
    test('heights include the status bar', () {
      expect(HomeHeaderMath.expandedHeight(44), 44 + 204);
      expect(HomeHeaderMath.collapsedHeight(44), 44 + 64);
      expect(
        HomeHeaderMath.expandedHeight(0),
        greaterThan(HomeHeaderMath.collapsedHeight(0)),
      );
    });

    test('the balance shrinks to half and docks on the right', () {
      expect(HomeHeaderMath.balanceScale(0), 1);
      expect(HomeHeaderMath.balanceScale(0.5), 0.75);
      expect(HomeHeaderMath.balanceScale(1), 0.5);
      expect(HomeHeaderMath.balanceScale(3), 0.5);
      expect(HomeHeaderMath.balanceAlignment(0), Alignment.centerLeft);
      expect(HomeHeaderMath.balanceAlignment(0.5), Alignment.center);
      expect(HomeHeaderMath.balanceAlignment(1), Alignment.centerRight);
    });

    test('the balance rises into the bar and stays inside it', () {
      const h = 58.8; // displayLarge 56 × 1.05
      const top = HomeHeaderMath.balanceTop;
      final docked = HomeHeaderMath.balanceY(1, balanceHeight: h);
      expect(HomeHeaderMath.balanceY(0, balanceHeight: h), top);
      expect(docked, lessThan(top));
      // Vertically centred: the scaled balance fits in the collapsed bar.
      const scaled = h * HomeHeaderMath.dockedScale;
      expect(
        docked,
        closeTo((HomeHeaderMath.collapsedContent - scaled) / 2, 1e-9),
      );
      expect(docked + scaled, lessThan(HomeHeaderMath.collapsedContent));
      final mid = HomeHeaderMath.balanceY(0.5, balanceHeight: h);
      expect(mid, closeTo((top + docked) / 2, 1e-9));
    });

    test('the eye rides into the bar', () {
      final expanded = HomeHeaderMath.eyeY(0);
      final docked = HomeHeaderMath.eyeY(1);
      expect(docked, (HomeHeaderMath.collapsedContent - 48) / 2);
      expect(expanded, greaterThan(docked));
      expect(docked + 48, lessThanOrEqualTo(HomeHeaderMath.collapsedContent));
    });

    test('fades cross over at half way; greeting drifts up', () {
      expect(HomeHeaderMath.expandedOnlyOpacity(0), 1);
      expect(HomeHeaderMath.expandedOnlyOpacity(0.25), 0.5);
      expect(HomeHeaderMath.expandedOnlyOpacity(0.5), 0);
      expect(HomeHeaderMath.expandedOnlyOpacity(1), 0);
      expect(HomeHeaderMath.dockedOnlyOpacity(0), 0);
      expect(HomeHeaderMath.dockedOnlyOpacity(0.5), 0);
      expect(HomeHeaderMath.dockedOnlyOpacity(0.75), 0.5);
      expect(HomeHeaderMath.dockedOnlyOpacity(1), 1);
      expect(HomeHeaderMath.greetingShift(0), 0);
      expect(HomeHeaderMath.greetingShift(1), -24);
      expect(HomeHeaderMath.greetingShift(5), -24);
    });

    test('greeting by hour and first name', () {
      expect(HomeHeaderMath.greetingFor(DateTime(2026, 1, 1, 3)), 'Good night');
      expect(
        HomeHeaderMath.greetingFor(DateTime(2026, 1, 1, 5)),
        'Good morning',
      );
      expect(
        HomeHeaderMath.greetingFor(DateTime(2026, 1, 1, 11)),
        'Good morning',
      );
      expect(
        HomeHeaderMath.greetingFor(DateTime(2026, 1, 1, 12)),
        'Good afternoon',
      );
      expect(
        HomeHeaderMath.greetingFor(DateTime(2026, 1, 1, 17)),
        'Good evening',
      );
      expect(
        HomeHeaderMath.greetingFor(DateTime(2026, 1, 1, 21)),
        'Good night',
      );
      expect(HomeHeaderMath.firstName('Aarav Mehta'), 'Aarav');
      expect(HomeHeaderMath.firstName('  Aarav  '), 'Aarav');
      expect(HomeHeaderMath.firstName('Aarav'), 'Aarav');
      expect(HomeHeaderMath.firstName(''), 'there');
    });
  });

  group('OfferTilt', () {
    test('centred card is the identity; neighbours turn and shrink', () {
      expect(OfferTilt.transform(0), Matrix4.identity());
      expect(OfferTilt.rotationY(1), closeTo(-OfferTilt.anglePerPage, 1e-9));
      expect(OfferTilt.rotationY(-1), closeTo(OfferTilt.anglePerPage, 1e-9));
      expect(OfferTilt.rotationY(5), closeTo(-OfferTilt.anglePerPage, 1e-9));
      expect(
        OfferTilt.rotationY(0.5),
        closeTo(-OfferTilt.anglePerPage / 2, 1e-9),
      );
      expect(OfferTilt.scale(0), 1);
      expect(OfferTilt.scale(1), closeTo(1 - OfferTilt.scalePerPage, 1e-9));
      expect(OfferTilt.scale(10), 0.85);
      final m = OfferTilt.transform(1);
      expect(m.entry(3, 2), greaterThan(0), reason: 'has perspective');
      expect(
        m.entry(0, 0),
        closeTo(math.cos(OfferTilt.anglePerPage) * OfferTilt.scale(1), 1e-6),
      );
    });
  });
}
