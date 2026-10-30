import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

FpDrawnCheckPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(FpDrawnCheck),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as FpDrawnCheckPainter;
}

void main() {
  group('FpDrawnCheck', () {
    testWidgets('hidden until shown, then draws the path over the duration', (
      tester,
    ) async {
      var completed = 0;
      await pumpFp(
        tester,
        FpDrawnCheck(shown: false, onCompleted: () => completed++),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).progress, 0);
      await pumpFp(tester, FpDrawnCheck(onCompleted: () => completed++));
      await tester.pump(const Duration(milliseconds: 150));
      final mid = _painter(tester).progress;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).progress, 1);
      expect(completed, 1);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('shown from the first frame animates once', (tester) async {
      var completed = 0;
      await pumpFp(tester, FpDrawnCheck(onCompleted: () => completed++));
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).progress, 1);
      expect(completed, 1);
      await pumpFp(tester, FpDrawnCheck(onCompleted: () => completed++));
      await tester.pump(const Duration(seconds: 1));
      expect(completed, 1);
    });

    testWidgets('reduce motion: appears fully drawn at once', (tester) async {
      var completed = 0;
      await pumpFp(
        tester,
        FpDrawnCheck(onCompleted: () => completed++),
        reduceMotion: true,
      );
      await tester.pump();
      expect(_painter(tester).progress, 1);
      expect(completed, 1);
    });

    testWidgets('has an image semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFp(tester, const FpDrawnCheck(semanticLabel: 'Verified'));
      expect(tester.getSemantics(find.byType(FpDrawnCheck)).label, 'Verified');
      handle.dispose();
    });

    test(
      'the path has a measurable length and the painter repaints on change',
      () {
        final path = FpDrawnCheck.pathFor(const Size(100, 100));
        final length = path.computeMetrics().fold<double>(
          0,
          (sum, m) => sum + m.length,
        );
        expect(length, greaterThan(50));
        const a = FpDrawnCheckPainter(
          progress: 0.5,
          color: Colors.white,
          strokeWidth: 6,
        );
        const b = FpDrawnCheckPainter(
          progress: 0.6,
          color: Colors.white,
          strokeWidth: 6,
        );
        expect(a.shouldRepaint(b), isTrue);
        expect(a.shouldRepaint(a), isFalse);
      },
    );
  });
}
