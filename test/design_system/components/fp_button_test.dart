import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:neopop/neopop.dart';

import '../helpers/pump.dart';

void main() {
  group('FpButton', () {
    for (final variant in FpButtonVariant.values) {
      testWidgets('${variant.name} renders label uppercase and fires once', (
        tester,
      ) async {
        var calls = 0;
        await pumpFp(
          tester,
          FpButton(
            label: 'Pay now',
            variant: variant,
            onPressed: () => calls++,
          ),
        );
        expect(find.text('PAY NOW'), findsOneWidget);
        await tester.tap(find.byType(FpButton));
        await tester.pumpAndSettle();
        expect(calls, 1);
        // The depth edge is drawn by neopop for every variant but ghost.
        expect(
          find.byType(NeoPopButton),
          variant == FpButtonVariant.ghost ? findsNothing : findsOneWidget,
        );
      });
    }

    for (final size in FpButtonSize.values) {
      testWidgets('${size.name} is at least 48 dp tall', (tester) async {
        await pumpFp(
          tester,
          FpButton(label: 'Go', size: size, onPressed: () {}),
        );
        final box = tester.getSize(find.byType(FpButton));
        expect(box.height, greaterThanOrEqualTo(48));
        expect(box.height, size.height);
      });
    }

    testWidgets('plays a medium haptic on press down', (tester) async {
      final haptics = fakeHaptics();
      await pumpFp(
        tester,
        FpButton(label: 'Pay', onPressed: () {}, haptics: haptics),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FpButton)),
      );
      await tester.pump();
      expect(haptics.calls, [HapticType.medium]);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(haptics.calls.length, 1);
    });

    testWidgets('falls back to the GetIt HapticService', (tester) async {
      final haptics = fakeHaptics();
      GetIt.I.registerSingleton<HapticService>(haptics);
      addTearDown(() => GetIt.I.unregister<HapticService>());
      await pumpFp(tester, FpButton(label: 'Pay', onPressed: () {}));
      await tester.tap(find.byType(FpButton));
      await tester.pumpAndSettle();
      expect(haptics.calls, [HapticType.medium]);
    });

    testWidgets('depth collapses on press and springs back', (tester) async {
      await pumpFp(tester, FpButton(label: 'Pay', onPressed: () {}));
      final face = find.byKey(const ValueKey('fp-button-face'));
      final rest = tester.getTopLeft(face);
      final gesture = await tester.startGesture(tester.getCenter(face));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final pressed = tester.getTopLeft(face);
      expect(pressed.dx - rest.dx, closeTo(FpDepth.button, 0.01));
      expect(pressed.dy - rest.dy, closeTo(FpDepth.button, 0.01));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(face), rest);
    });

    testWidgets('reduce motion: no translation, still fires and vibrates', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      var calls = 0;
      await pumpFp(
        tester,
        FpButton(label: 'Pay', onPressed: () => calls++, haptics: haptics),
        reduceMotion: true,
      );
      final face = find.byKey(const ValueKey('fp-button-face'));
      final rest = tester.getTopLeft(face);
      final gesture = await tester.startGesture(tester.getCenter(face));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getTopLeft(face), rest);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(haptics.calls, [HapticType.medium]);
    });

    testWidgets('disabled: no callback, no haptic, semantics disabled', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      var calls = 0;
      await pumpFp(
        tester,
        FpButton(
          label: 'Pay',
          enabled: false,
          onPressed: () => calls++,
          haptics: haptics,
        ),
      );
      await tester.tap(find.byType(FpButton));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(haptics.calls, isEmpty);
      final semantics = tester.getSemantics(find.byType(FpButton));
      expect(semantics.label, 'Pay');
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    });

    testWidgets('null onPressed also disables', (tester) async {
      await pumpFp(tester, const FpButton(label: 'Pay'));
      final semantics = tester.getSemantics(find.byType(FpButton));
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    });

    testWidgets('isLoading morphs to a spinner and blocks presses', (
      tester,
    ) async {
      var calls = 0;
      await pumpFp(
        tester,
        FpButton(label: 'Pay', isLoading: true, onPressed: () => calls++),
      );
      await tester.pump(FpMotion.standard);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('PAY'), findsNothing);
      await tester.tap(find.byType(FpButton));
      await tester.pump(FpMotion.standard);
      expect(calls, 0);
      expect(tester.getSemantics(find.byType(FpButton)).value, 'Loading');
    });

    testWidgets('loading transition under reduce motion is instant', (
      tester,
    ) async {
      await pumpFp(
        tester,
        FpButton(label: 'Pay', isLoading: true, onPressed: () {}),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FpButton),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('leading icon and intrinsic width', (tester) async {
      await pumpFp(
        tester,
        FpButton(
          label: 'Add',
          leadingIcon: Icons.add,
          expand: false,
          onPressed: () {},
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(tester.getSize(find.byType(FpButton)).width, lessThan(300));
    });

    testWidgets('double-submit guard: 1,000 rapid taps call once', (
      tester,
    ) async {
      var calls = 0;
      await pumpFp(tester, FpButton(label: 'Pay', onPressed: () => calls++));
      final center = tester.getCenter(find.byType(FpButton));
      for (var i = 0; i < 1000; i++) {
        await tester.tapAt(center);
      }
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('guard waits for the returned future', (tester) async {
      var calls = 0;
      final completer = Completer<void>();
      await pumpFp(
        tester,
        FpButton(
          label: 'Pay',
          onPressed: () {
            calls++;
            return completer.future;
          },
        ),
      );
      await tester.tap(find.byType(FpButton));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(FpButton));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      completer.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FpButton));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('multi-touch: two pointers down at once fire once', (
      tester,
    ) async {
      var calls = 0;
      await pumpFp(tester, FpButton(label: 'Pay', onPressed: () => calls++));
      final center = tester.getCenter(find.byType(FpButton));
      final g1 = await tester.startGesture(center, pointer: 1);
      final g2 = await tester.startGesture(
        center + const Offset(4, 0),
        pointer: 2,
      );
      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();
      expect(calls, lessThanOrEqualTo(1));
    });

    testWidgets('custom semantic label and tap action', (tester) async {
      var calls = 0;
      await pumpFp(
        tester,
        FpButton(
          label: 'Pay',
          semanticLabel: 'Pay 1200 rupees',
          onPressed: () => calls++,
        ),
      );
      final node = tester.getSemantics(find.byType(FpButton));
      expect(node.label, 'Pay 1200 rupees');
      tester.semantics.tap(find.semantics.byLabel('Pay 1200 rupees'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('long label does not overflow at 1.3× text scale', (
      tester,
    ) async {
      await pumpFp(
        tester,
        FpButton(
          label: 'A very long label that keeps going and going',
          onPressed: () {},
        ),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
