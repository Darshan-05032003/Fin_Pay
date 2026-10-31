import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduceMotion = false, double scale = 1}) =>
    MaterialApp(
      theme: FpTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(scale),
        ),
        child: app!,
      ),
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );

Finder get _thumb => find.byKey(const ValueKey('fp-swipe-thumb'));

/// Two frames a second apart: the first delivers the ticker's elapsed-zero
/// tick, the second lets the spring finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('FpSwipeMath', () {
    test('travel is the track minus the thumb and insets, never negative', () {
      expect(FpSwipeMath.travel(trackWidth: 360, thumbSize: 56, inset: 4), 296);
      expect(FpSwipeMath.travel(trackWidth: 40, thumbSize: 56, inset: 4), 0);
    });

    test('progress is dx over travel, clamped to 0..1', () {
      expect(FpSwipeMath.progressFor(dx: 0, travel: 300), 0);
      expect(FpSwipeMath.progressFor(dx: 150, travel: 300), 0.5);
      expect(FpSwipeMath.progressFor(dx: 900, travel: 300), 1);
      expect(FpSwipeMath.progressFor(dx: -50, travel: 300), 0);
      expect(FpSwipeMath.progressFor(dx: 50, travel: 0), 0);
    });

    test('threshold is 85 % of the track', () {
      expect(FpSwipeMath.threshold, 0.85);
      expect(FpSwipeMath.shouldComplete(progress: 0.84), isFalse);
      expect(FpSwipeMath.shouldComplete(progress: 0.85), isTrue);
      expect(FpSwipeMath.shouldComplete(progress: 1), isTrue);
    });

    test('a fast fling completes from half way, never from the start', () {
      expect(FpSwipeMath.shouldComplete(progress: 0.5, velocity: 1200), isTrue);
      expect(
        FpSwipeMath.shouldComplete(progress: 0.49, velocity: 5000),
        isFalse,
      );
      expect(
        FpSwipeMath.shouldComplete(progress: 0.6, velocity: 1199),
        isFalse,
      );
      expect(
        FpSwipeMath.shouldComplete(progress: 0.6, velocity: -3000),
        isFalse,
      );
    });

    test('ticks sit at 25, 50 and 75 % and are crossed upwards only', () {
      expect(FpSwipeMath.ticks, [0.25, 0.5, 0.75]);
      expect(FpSwipeMath.ticksCrossed(from: 0, to: 0.3), [0.25]);
      expect(FpSwipeMath.ticksCrossed(from: 0.3, to: 0.8), [0.5, 0.75]);
      expect(FpSwipeMath.ticksCrossed(from: 0, to: 1), [0.25, 0.5, 0.75]);
      expect(FpSwipeMath.ticksCrossed(from: 0.8, to: 0.3), isEmpty);
      expect(FpSwipeMath.ticksCrossed(from: 0.25, to: 0.25), isEmpty);
      expect(FpSwipeMath.ticksCrossed(from: 0.24, to: 0.25), [0.25]);
    });

    test('ticksPassed counts the ticks at or below the progress', () {
      expect(FpSwipeMath.ticksPassed(0), 0);
      expect(FpSwipeMath.ticksPassed(0.25), 1);
      expect(FpSwipeMath.ticksPassed(0.74), 2);
      expect(FpSwipeMath.ticksPassed(1), 3);
    });

    test('the label fades out over the first 40 % of the drag', () {
      expect(FpSwipeMath.labelOpacity(0), 1);
      expect(FpSwipeMath.labelOpacity(0.2), closeTo(0.5, 1e-9));
      expect(FpSwipeMath.labelOpacity(0.4), 0);
      expect(FpSwipeMath.labelOpacity(1), 0);
    });

    test('snap target is 1 past the threshold and 0 before it', () {
      expect(FpSwipeMath.snapTarget(progress: 0.9), 1);
      expect(FpSwipeMath.snapTarget(progress: 0.2), 0);
      expect(FpSwipeMath.snapTarget(progress: 0.5, velocity: 2000), 1);
    });
  });

  group('FpSwipeToPay', () {
    late FakeHapticService haptics;
    late int confirmed;

    setUp(() {
      haptics = FakeHapticService();
      confirmed = 0;
    });

    Widget slider({
      bool processing = false,
      bool enabled = true,
      FutureOr<void> Function()? onConfirmed,
    }) => FpSwipeToPay(
      label: 'Swipe to pay ₹1,200.00',
      onConfirmed: onConfirmed ?? () => confirmed++,
      processing: processing,
      enabled: enabled,
      haptics: haptics,
    );

    testWidgets('renders the label, thumb and a button semantics node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(slider()));
      expect(find.text('SWIPE TO PAY ₹1,200.00'), findsOneWidget);
      expect(_thumb, findsOneWidget);
      final node = tester.getSemantics(find.byType(FpSwipeToPay));
      expect(node.label, 'Swipe to pay ₹1,200.00');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(tester.getSize(_thumb).height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('a short drag snaps back and confirms nothing', (tester) async {
      await tester.pumpWidget(_app(slider()));
      final start = tester.getCenter(_thumb);
      await tester.drag(_thumb, const Offset(80, 0));
      await tester.pump();
      await settle(tester);
      expect(confirmed, 0);
      expect(tester.getCenter(_thumb).dx, closeTo(start.dx, 0.5));
      expect(haptics.calls, [HapticType.selection]);
    });

    testWidgets(
      'ticks play one selection haptic per forward crossing, none backwards',
      (tester) async {
        await tester.pumpWidget(_app(slider()));
        final gesture = await tester.startGesture(tester.getCenter(_thumb));
        await gesture.moveBy(const Offset(100, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(-120, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(120, 0));
        await tester.pump();
        // 25 % and 50 % on the way out, then 25 % and 50 % again after the
        // retreat; nothing on the way back.
        expect(haptics.calls, List.filled(4, HapticType.selection));
        await gesture.up();
        await settle(tester);
        expect(confirmed, 0);
      },
    );

    testWidgets('a drag past the threshold confirms once with a heavy haptic', (
      tester,
    ) async {
      await tester.pumpWidget(_app(slider()));
      await tester.drag(_thumb, const Offset(400, 0));
      await tester.pump();
      await settle(tester);
      expect(confirmed, 1);
      expect(haptics.calls.last, HapticType.heavy);
      expect(haptics.calls.where((c) => c == HapticType.selection).length, 3);
    });

    testWidgets('a fast fling from half way confirms', (tester) async {
      await tester.pumpWidget(_app(slider()));
      await tester.fling(_thumb, const Offset(170, 0), 2000);
      await settle(tester);
      expect(confirmed, 1);
    });

    testWidgets('while processing the thumb is locked at the end and shows a '
        'ring; releasing processing springs it back', (tester) async {
      await tester.pumpWidget(_app(slider(processing: true)));
      await settle(tester);
      final locked = tester.getCenter(_thumb).dx;
      expect(find.byType(FpProcessingRing), findsOneWidget);
      await tester.drag(_thumb, const Offset(-200, 0));
      await tester.pump();
      expect(tester.getCenter(_thumb).dx, closeTo(locked, 0.5));
      expect(confirmed, 0);
      final node = tester.getSemantics(find.byType(FpSwipeToPay));
      expect(node.value, 'Processing');
      await tester.pumpWidget(_app(slider()));
      await settle(tester);
      expect(tester.getCenter(_thumb).dx, lessThan(locked - 100));
      expect(find.byType(FpProcessingRing), findsNothing);
    });

    testWidgets('after confirming, the thumb stays at the end while the '
        'parent processes and returns when it stops', (tester) async {
      var processing = false;
      late StateSetter setOuter;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return slider(
                processing: processing,
                onConfirmed: () => setOuter(() => processing = true),
              );
            },
          ),
        ),
      );
      final rest = tester.getCenter(_thumb).dx;
      await tester.drag(_thumb, const Offset(400, 0));
      await tester.pump();
      await settle(tester);
      expect(processing, isTrue);
      final end = tester.getCenter(_thumb).dx;
      expect(end, greaterThan(rest + 200));
      // A second drag while locked does nothing.
      await tester.drag(_thumb, const Offset(-300, 0));
      await settle(tester);
      expect(tester.getCenter(_thumb).dx, closeTo(end, 0.5));
      setOuter(() => processing = false);
      await tester.pump();
      await settle(tester);
      expect(tester.getCenter(_thumb).dx, closeTo(rest, 0.5));
      // Unlocked again: a new swipe confirms a second time.
      await tester.drag(_thumb, const Offset(400, 0));
      await tester.pump();
      await settle(tester);
      expect(processing, isTrue);
    });

    testWidgets('a confirm whose parent never locks springs back after the '
        'action completes', (tester) async {
      await tester.pumpWidget(_app(slider()));
      final rest = tester.getCenter(_thumb).dx;
      await tester.drag(_thumb, const Offset(400, 0));
      await tester.pump();
      await settle(tester);
      expect(confirmed, 1);
      expect(tester.getCenter(_thumb).dx, closeTo(rest, 0.5));
      await tester.drag(_thumb, const Offset(400, 0));
      await tester.pump();
      await settle(tester);
      expect(confirmed, 2);
    });

    testWidgets('1,000 rapid pointer downs and a multi-touch drag confirm '
        'exactly once', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        _app(slider(onConfirmed: () => completer.future)),
      );
      final a = await tester.startGesture(tester.getCenter(_thumb));
      final b = await tester.startGesture(
        tester.getCenter(_thumb) + const Offset(0, 10),
        pointer: 2,
      );
      await a.moveBy(const Offset(400, 0));
      await b.moveBy(const Offset(400, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();
      for (var i = 0; i < 1000; i++) {
        final g = await tester.startGesture(
          tester.getCenter(_thumb),
          pointer: 10 + i,
        );
        await g.moveBy(const Offset(400, 0));
        await g.up();
      }
      await tester.pump();
      await settle(tester);
      expect(confirmed, 0);
      // The in-flight action is the only call that was made.
      completer.complete();
      await tester.pump();
      await settle(tester);
    });

    testWidgets('semantics tap confirms once and is blocked while processing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(slider()));
      tester.semantics.performAction(
        find.semantics.byLabel('Swipe to pay ₹1,200.00'),
        SemanticsAction.tap,
      );
      await tester.pump();
      await settle(tester);
      expect(confirmed, 1);
      await tester.pumpWidget(_app(slider(processing: true)));
      final locked = tester.getSemantics(find.byType(FpSwipeToPay));
      expect(locked.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('disabled ignores drags and taps', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(slider(enabled: false)));
      await tester.drag(_thumb, const Offset(400, 0));
      await settle(tester);
      expect(confirmed, 0);
      final node = tester.getSemantics(find.byType(FpSwipeToPay));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('reduce motion falls back to a plain confirm button', (
      tester,
    ) async {
      await tester.pumpWidget(_app(slider(), reduceMotion: true));
      expect(_thumb, findsNothing);
      expect(find.byType(FpButton), findsOneWidget);
      await tester.tap(find.byType(FpButton));
      await tester.pump();
      expect(confirmed, 1);
      await tester.pumpWidget(
        _app(slider(processing: true), reduceMotion: true),
      );
      expect(tester.widget<FpButton>(find.byType(FpButton)).isLoading, isTrue);
      await settle(tester);
    });

    testWidgets('fits at 1.3x text scale without overflow', (tester) async {
      await tester.pumpWidget(_app(slider(), scale: 1.3));
      expect(tester.takeException(), isNull);
      expect(find.text('SWIPE TO PAY ₹1,200.00'), findsOneWidget);
    });

    testWidgets('leaves no ticker behind after dispose', (tester) async {
      await tester.pumpWidget(_app(slider()));
      await tester.drag(_thumb, const Offset(100, 0));
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('FpProcessingRing', () {
    testWidgets('spins and stops with reduce motion', (tester) async {
      await tester.pumpWidget(_app(const FpProcessingRing()));
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(
        _app(const FpProcessingRing(), reduceMotion: true),
      );
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      final node = tester.getSemantics(find.byType(FpProcessingRing));
      expect(node.label, 'Processing');
    });
  });
}
