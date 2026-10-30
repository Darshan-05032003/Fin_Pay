import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

FpCountdownRingPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(FpCountdownRing),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as FpCountdownRingPainter;
}

void main() {
  group('FpCountdownRing', () {
    testWidgets('paints the progress and shows the label', (tester) async {
      await pumpFp(tester, const FpCountdownRing(progress: 0.5, label: '15'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('15'), findsOneWidget);
      expect(_painter(tester).progress, closeTo(0.5, 0.001));
    });

    testWidgets('progress changes animate between values', (tester) async {
      await pumpFp(tester, const FpCountdownRing(progress: 1, label: '30'));
      await tester.pump(const Duration(seconds: 1));
      await pumpFp(tester, const FpCountdownRing(progress: 0, label: '0'));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _painter(tester).progress;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).progress, closeTo(0, 0.001));
    });

    testWidgets('reduce motion: jumps straight to the value', (tester) async {
      await pumpFp(
        tester,
        const FpCountdownRing(progress: 1, label: '30'),
        reduceMotion: true,
      );
      await pumpFp(
        tester,
        const FpCountdownRing(progress: 0.2, label: '6'),
        reduceMotion: true,
      );
      await tester.pump();
      expect(_painter(tester).progress, closeTo(0.2, 0.001));
    });

    testWidgets('out-of-range progress is clamped', (tester) async {
      await pumpFp(tester, const FpCountdownRing(progress: 7));
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).progress, 1);
      await pumpFp(tester, const FpCountdownRing(progress: -3));
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).progress, 0);
    });

    testWidgets('semantics label describes the remaining time', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFp(
        tester,
        const FpCountdownRing(
          progress: 0.5,
          label: '15',
          semanticLabel: 'Resend available in 15 seconds',
        ),
      );
      final node = tester.getSemantics(find.byType(FpCountdownRing));
      expect(node.label, 'Resend available in 15 seconds');
      handle.dispose();
    });

    test('painter repaints only when something changed', () {
      const a = FpCountdownRingPainter(
        progress: 0.5,
        color: Colors.red,
        track: Colors.grey,
        strokeWidth: 4,
      );
      const b = FpCountdownRingPainter(
        progress: 0.5,
        color: Colors.red,
        track: Colors.grey,
        strokeWidth: 4,
      );
      const c = FpCountdownRingPainter(
        progress: 0.6,
        color: Colors.red,
        track: Colors.grey,
        strokeWidth: 4,
      );
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });
}
