import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

void main() {
  group('FpRefreshMath', () {
    test('progress is 0 at rest, 1 once armed, never above', () {
      expect(FpRefreshMath.progress(0), 0);
      expect(FpRefreshMath.progress(-10), 0);
      expect(FpRefreshMath.progress(40), closeTo(0.5, 1e-9));
      expect(FpRefreshMath.progress(80), 1);
      expect(FpRefreshMath.progress(1000), 1);
    });

    test('displacement is resisted, monotonic and bounded', () {
      expect(FpRefreshMath.displacement(0), 0);
      expect(FpRefreshMath.displacement(-5), 0);
      var last = 0.0;
      for (var d = 1.0; d <= 400; d += 1) {
        final v = FpRefreshMath.displacement(d);
        expect(v, greaterThanOrEqualTo(last));
        expect(v, lessThan(FpRefreshMath.armDistance));
        last = v;
      }
      // Beyond maxDrag nothing changes.
      expect(
        FpRefreshMath.displacement(FpRefreshMath.maxDrag + 100),
        FpRefreshMath.displacement(FpRefreshMath.maxDrag),
      );
      // A pull to the arm distance moves the glyph most of the way.
      expect(
        FpRefreshMath.displacement(FpRefreshMath.armDistance),
        greaterThan(FpRefreshMath.armDistance * 0.6),
      );
    });

    test('isArmed at the threshold', () {
      expect(FpRefreshMath.isArmed(79.9), isFalse);
      expect(FpRefreshMath.isArmed(80), isTrue);
    });
  });

  group('FpRefreshIndicator', () {
    Future<void> pumpList(
      WidgetTester tester, {
      required Future<void> Function() onRefresh,
      FakeHapticService? haptics,
      bool reduceMotion = false,
    }) async {
      await pumpFp(
        tester,
        FpRefreshIndicator(
          onRefresh: onRefresh,
          haptics: haptics,
          child: ListView.builder(
            itemCount: 30,
            itemBuilder: (context, i) =>
                SizedBox(height: 48, child: Text('Row $i')),
          ),
        ),
        reduceMotion: reduceMotion,
        scaffold: false,
      );
    }

    FpRefreshGlyph glyph(WidgetTester tester) =>
        tester.widget<FpRefreshGlyph>(find.byType(FpRefreshGlyph));

    testWidgets('pull past the arm distance refreshes once, with a haptic', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      var calls = 0;
      final gate = Completer<void>();
      await pumpList(
        tester,
        haptics: haptics,
        onRefresh: () {
          calls++;
          return gate.future;
        },
      );
      expect(glyph(tester).progress, 0);
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(glyph(tester).progress, greaterThan(0));
      expect(glyph(tester).progress, lessThan(1));
      expect(haptics.calls, isEmpty);
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      expect(glyph(tester).progress, 1);
      expect(haptics.calls, [HapticType.medium]);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 1);
      // Spinning while the refresh runs.
      final a = glyph(tester).spin;
      await tester.pump(const Duration(milliseconds: 300));
      expect(glyph(tester).spin, isNot(a));
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(glyph(tester).progress, 0);
      expect(calls, 1);
    });

    testWidgets('a short pull snaps back without refreshing', (tester) async {
      var calls = 0;
      await pumpList(tester, onRefresh: () async => calls++);
      await tester.drag(find.byType(ListView), const Offset(0, 30));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 0);
      expect(glyph(tester).progress, 0);
    });

    testWidgets('a pull while not at the top does nothing', (tester) async {
      var calls = 0;
      await pumpList(tester, onRefresh: () async => calls++);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(find.byType(ListView), const Offset(0, 150));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 0);
    });

    testWidgets('reduce motion: refreshes but never spins', (tester) async {
      final gate = Completer<void>();
      await pumpList(tester, onRefresh: () => gate.future, reduceMotion: true);
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(glyph(tester).spin, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(glyph(tester).spin, 0);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(glyph(tester).progress, 0);
    });

    testWidgets('a throwing refresh still retracts the glyph', (tester) async {
      await pumpList(tester, onRefresh: () async => throw StateError('x'));
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isA<StateError>());
      expect(glyph(tester).progress, 0);
    });
  });
}
