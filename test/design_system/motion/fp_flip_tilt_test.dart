import 'dart:math' as math;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

void main() {
  group('FpFlipMath', () {
    test('angle, face switch and clamping', () {
      expect(FpFlipMath.angle(0), 0);
      expect(FpFlipMath.angle(0.5), closeTo(math.pi / 2, 1e-9));
      expect(FpFlipMath.angle(1), closeTo(math.pi, 1e-9));
      expect(FpFlipMath.angle(2), closeTo(math.pi, 1e-9));
      expect(FpFlipMath.showsBack(0.49), isFalse);
      expect(FpFlipMath.showsBack(0.5), isTrue);
    });

    test('the back face is counter-rotated so it is not mirrored', () {
      // At t = 1 the back face is drawn with no rotation at all, and at
      // rest there is no perspective entry either.
      final end = FpFlipMath.transform(1);
      expect(end, Matrix4.identity());
      expect(
        FpFlipMath.transform(0.999).entry(3, 2),
        closeTo(FpFlipMath.perspective, 1e-6),
      );
      // Just past the midpoint the back is rotated by a small negative angle.
      final mid = FpFlipMath.transform(0.6);
      expect(mid.entry(0, 0), closeTo(math.cos(0.6 * math.pi - math.pi), 1e-9));
      // Front at the start is identity (plus perspective).
      expect(FpFlipMath.transform(0).entry(0, 0), 1);
    });
  });

  group('FpFlipCard', () {
    Future<void> pumpFlip(
      WidgetTester tester, {
      required bool flipped,
      VoidCallback? onTap,
      bool reduceMotion = false,
    }) async {
      await pumpFp(
        tester,
        FpFlipCard(
          flipped: flipped,
          onTap: onTap,
          semanticLabel: 'Card',
          front: const SizedBox(width: 200, height: 120, child: Text('FRONT')),
          back: const SizedBox(width: 200, height: 120, child: Text('BACK')),
        ),
        reduceMotion: reduceMotion,
      );
    }

    testWidgets('shows the front, flips to the back over 400 ms', (
      tester,
    ) async {
      await pumpFlip(tester, flipped: false);
      expect(find.text('FRONT'), findsOneWidget);
      expect(find.text('BACK'), findsNothing);
      await pumpFlip(tester, flipped: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('FRONT'), findsOneWidget, reason: 'before 90°');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('BACK'), findsOneWidget, reason: 'after 90°');
      await tester.pump(const Duration(milliseconds: 200));
      final transform = tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(FpFlipCard),
              matching: find.byType(Transform),
            ),
          )
          .transform;
      expect(transform.entry(0, 0), closeTo(1, 1e-6));
      expect(find.text('BACK'), findsOneWidget);
    });

    testWidgets('reduce motion: cuts to the other face at once', (
      tester,
    ) async {
      await pumpFlip(tester, flipped: false, reduceMotion: true);
      await pumpFlip(tester, flipped: true, reduceMotion: true);
      await tester.pump();
      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('FRONT'), findsNothing);
    });

    testWidgets('tap and semantics', (tester) async {
      var taps = 0;
      await pumpFlip(tester, flipped: false, onTap: () => taps++);
      final node = tester.getSemantics(find.byType(FpFlipCard));
      expect(node.label, 'Card');
      expect(node.flagsCollection.isButton, isTrue);
      await tester.tap(find.byType(FpFlipCard));
      expect(taps, 1);
    });
  });

  group('FpTiltMath', () {
    test('clamp and damp', () {
      expect(FpTiltMath.clamp(const Offset(3, -7)), const Offset(1, -1));
      expect(FpTiltMath.clamp(const Offset(0.2, 0.3)), const Offset(0.2, 0.3));
      final d = FpTiltMath.damp(Offset.zero, const Offset(1, 1), 0.25);
      expect(d.dx, closeTo(0.25, 1e-9));
      expect(d.dy, closeTo(0.25, 1e-9));
      // A damping factor above 1 is clamped: never overshoots.
      expect(FpTiltMath.damp(Offset.zero, const Offset(1, 0), 5).dx, 1);
      // A huge sensor sample is clamped before damping.
      expect(
        FpTiltMath.damp(Offset.zero, const Offset(100, 0), 0.5).dx,
        closeTo(0.5, 1e-9),
      );
    });

    test('transform rotates within maxAngle and keeps perspective', () {
      final flat = FpTiltMath.transform(Offset.zero);
      expect(flat, Matrix4.identity());
      expect(
        FpTiltMath.transform(const Offset(0.1, 0)).entry(3, 2),
        closeTo(FpTiltMath.perspective, 1e-6),
      );
      final tilted = FpTiltMath.transform(const Offset(1, 0));
      expect(tilted.entry(0, 0), closeTo(math.cos(FpTiltMath.maxAngle), 1e-9));
      final over = FpTiltMath.transform(const Offset(10, 0));
      expect(over.entry(0, 0), closeTo(math.cos(FpTiltMath.maxAngle), 1e-9));
      final custom = FpTiltMath.transform(const Offset(1, 0), maxAngle: 0.5);
      expect(custom.entry(0, 0), closeTo(math.cos(0.5), 1e-9));
    });

    test('sheen moves opposite to the tilt; pointer maps to -1…1', () {
      expect(
        FpTiltMath.sheenAlignment(const Offset(1, 0)),
        const Alignment(-1.5, 0),
      );
      expect(
        FpTiltMath.fromPointer(Offset.zero, const Size(200, 100)),
        const Offset(-1, -1),
      );
      expect(
        FpTiltMath.fromPointer(const Offset(100, 50), const Size(200, 100)),
        Offset.zero,
      );
      expect(
        FpTiltMath.fromPointer(const Offset(400, 100), const Size(200, 100)),
        const Offset(1, 1),
      );
      expect(
        FpTiltMath.fromPointer(const Offset(1, 1), Size.zero),
        Offset.zero,
      );
    });
  });

  group('FpTiltCard', () {
    Matrix4 transformOf(WidgetTester tester) => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(FpTiltCard),
            matching: find.byType(Transform),
          ),
        )
        .transform;

    testWidgets('follows the controller and the sheen moves', (tester) async {
      final controller = FpTiltController();
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        FpTiltCard(
          controller: controller,
          child: const SizedBox(width: 200, height: 120),
        ),
      );
      expect(transformOf(tester).entry(0, 0), 1);
      controller.set(const Offset(1, 0));
      await tester.pump();
      expect(
        transformOf(tester).entry(0, 0),
        closeTo(math.cos(FpTiltMath.maxAngle), 1e-9),
      );
      final sheen = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(FpTiltCard),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient = (sheen.decoration as BoxDecoration).gradient;
      expect(gradient, isA<RadialGradient>());
      expect((gradient! as RadialGradient).center, const Alignment(-1.5, 0));
    });

    testWidgets('drag fallback tilts under the finger and springs back', (
      tester,
    ) async {
      final controller = FpTiltController();
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        FpTiltCard(
          controller: controller,
          child: const SizedBox(width: 200, height: 100),
        ),
      );
      final topLeft = tester.getTopLeft(find.byType(FpTiltCard));
      final gesture = await tester.startGesture(topLeft + const Offset(10, 10));
      await tester.pump();
      expect(controller.value.dx, lessThan(-0.5));
      expect(controller.value.dy, lessThan(-0.5));
      await gesture.moveTo(topLeft + const Offset(190, 90));
      await tester.pump();
      expect(controller.value.dx, greaterThan(0.5));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(controller.value.dx.abs(), lessThan(0.01));
      expect(controller.value.dy.abs(), lessThan(0.01));
    });

    testWidgets('reduce motion: flat, no sheen, no transform', (tester) async {
      final controller = FpTiltController()..set(const Offset(1, 1));
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        FpTiltCard(
          controller: controller,
          child: const SizedBox(width: 200, height: 100),
        ),
        reduceMotion: true,
      );
      expect(
        find.descendant(
          of: find.byType(FpTiltCard),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(FpTiltCard),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('controller.push is damped', (tester) async {
      final controller = FpTiltController(damping: 0.5)
        ..push(const Offset(1, 0))
        ..push(const Offset(1, 0));
      expect(controller.value.dx, closeTo(0.75, 1e-9));
      controller.dispose();
    });
  });
}
