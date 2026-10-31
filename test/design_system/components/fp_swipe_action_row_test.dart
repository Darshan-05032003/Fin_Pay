import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

void main() {
  group('FpSwipeActionMath', () {
    const reveal = 144.0; // two actions
    const row = 400.0;

    test('reveal width is 72 per action, never negative', () {
      expect(FpSwipeActionMath.revealWidth(1), 72);
      expect(FpSwipeActionMath.revealWidth(2), 144);
      expect(FpSwipeActionMath.revealWidth(0), 0);
      expect(FpSwipeActionMath.revealWidth(-3), 0);
    });

    test('clampOffset ignores right swipes and NaN', () {
      for (final raw in [0.0, 10.0, 1e9, double.nan]) {
        expect(
          FpSwipeActionMath.clampOffset(
            raw,
            reveal: reveal,
            rowWidth: row,
            dismissible: true,
          ),
          0,
        );
      }
    });

    test('clampOffset follows the finger inside the tray', () {
      expect(
        FpSwipeActionMath.clampOffset(
          -80,
          reveal: reveal,
          rowWidth: row,
          dismissible: false,
        ),
        -80,
      );
      expect(
        FpSwipeActionMath.clampOffset(
          -reveal,
          reveal: reveal,
          rowWidth: row,
          dismissible: false,
        ),
        -reveal,
      );
    });

    test('clampOffset resists past the tray when not dismissible', () {
      final v = FpSwipeActionMath.clampOffset(
        -244,
        reveal: reveal,
        rowWidth: row,
        dismissible: false,
      );
      expect(
        v,
        closeTo(-reveal - 100 * FpSwipeActionMath.overdragResistance, 1e-9),
      );
      // Monotonic: further drag never moves the row back.
      final further = FpSwipeActionMath.clampOffset(
        -1000,
        reveal: reveal,
        rowWidth: row,
        dismissible: false,
      );
      expect(further, lessThan(v));
    });

    test('clampOffset follows fully past the tray when dismissible, bounded '
        'by the row width', () {
      expect(
        FpSwipeActionMath.clampOffset(
          -300,
          reveal: reveal,
          rowWidth: row,
          dismissible: true,
        ),
        -300,
      );
      expect(
        FpSwipeActionMath.clampOffset(
          -5000,
          reveal: reveal,
          rowWidth: row,
          dismissible: true,
        ),
        -row,
      );
    });

    test('progress and threshold', () {
      expect(FpSwipeActionMath.progress(0, reveal: reveal), 0);
      expect(FpSwipeActionMath.progress(-72, reveal: reveal), 0.5);
      expect(FpSwipeActionMath.progress(-500, reveal: reveal), 1);
      expect(FpSwipeActionMath.progress(-50, reveal: 0), 0);
      expect(FpSwipeActionMath.isPastThreshold(-71, reveal: reveal), isFalse);
      expect(FpSwipeActionMath.isPastThreshold(-72, reveal: reveal), isTrue);
      expect(FpSwipeActionMath.isPastThreshold(-72, reveal: 0), isFalse);
    });

    test('snapTarget: below threshold closes, above opens', () {
      expect(
        FpSwipeActionMath.snapTarget(offset: -40, velocity: 0, reveal: reveal),
        0,
      );
      expect(
        FpSwipeActionMath.snapTarget(offset: -100, velocity: 0, reveal: reveal),
        -reveal,
      );
      expect(
        FpSwipeActionMath.snapTarget(offset: -100, velocity: 0, reveal: 0),
        0,
      );
    });

    test('snapTarget: a fling wins over the position', () {
      expect(
        FpSwipeActionMath.snapTarget(
          offset: -10,
          velocity: -FpSwipeActionMath.flingVelocity,
          reveal: reveal,
        ),
        -reveal,
      );
      expect(
        FpSwipeActionMath.snapTarget(
          offset: -140,
          velocity: FpSwipeActionMath.flingVelocity,
          reveal: reveal,
        ),
        0,
      );
    });

    test('shouldDismiss only when dismissible and far enough or flung past '
        'the tray', () {
      bool d({
        required double offset,
        double velocity = 0,
        bool dismissible = true,
        double rowWidth = row,
      }) => FpSwipeActionMath.shouldDismiss(
        offset: offset,
        velocity: velocity,
        reveal: reveal,
        rowWidth: rowWidth,
        dismissible: dismissible,
      );
      expect(d(offset: -row * 0.55), isTrue);
      expect(d(offset: -row * 0.54), isFalse);
      expect(d(offset: -row * 0.9, dismissible: false), isFalse);
      expect(d(offset: -150, velocity: -900), isTrue, reason: 'fling past');
      expect(d(offset: -140, velocity: -900), isFalse, reason: 'inside tray');
      expect(d(offset: -150, velocity: -100), isFalse);
      expect(d(offset: -300, rowWidth: 0), isFalse);
    });
  });

  group('FpSwipeActionRow', () {
    late FakeHapticService haptics;
    late List<String> log;

    setUp(() {
      haptics = fakeHaptics();
      log = [];
    });

    Widget row({
      VoidCallback? onDismissed,
      VoidCallback? onTap,
      FpSwipeActionController? controller,
      bool enabled = true,
      int actions = 2,
    }) => SizedBox(
      width: 400,
      child: FpSwipeActionRow(
        key: const ValueKey('row'),
        semanticLabel: 'Coffee, ₹320',
        onDismissed: onDismissed,
        onTap: onTap,
        controller: controller,
        enabled: enabled,
        haptics: haptics,
        actions: [
          FpSwipeAction(
            label: 'Details',
            icon: Icons.info_outline,
            onPressed: () => log.add('details'),
          ),
          if (actions > 1)
            FpSwipeAction(
              label: 'Delete',
              icon: Icons.delete_outline,
              tone: FpSwipeActionTone.danger,
              onPressed: () => log.add('delete'),
            ),
        ],
        child: const SizedBox(height: 64, child: Text('Coffee')),
      ),
    );

    double foregroundDx(WidgetTester tester) =>
        tester.getTopLeft(find.text('Coffee')).dx -
        tester.getTopLeft(find.byKey(const ValueKey('row'))).dx;

    /// Centre of the row itself (stays on the foreground while it is open,
    /// unlike the left-aligned text, which slides out of the clip).
    Offset rowCenter(WidgetTester tester) =>
        tester.getCenter(find.byKey(const ValueKey('row')));

    Future<void> drag(WidgetTester tester, double dx, {double vx = 0}) async {
      if (vx == 0) {
        await tester.dragFrom(rowCenter(tester), Offset(dx, 0));
      } else {
        final ms = (dx.abs() / vx.abs() * 1000).round().clamp(1, 1000);
        await tester.timedDragFrom(
          rowCenter(tester),
          Offset(dx, 0),
          Duration(milliseconds: ms),
          frequency: 240,
        );
      }
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('a short drag snaps back closed', (tester) async {
      await pumpFp(tester, row());
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Coffee')),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(foregroundDx(tester), closeTo(-40, 0.5));
      await gesture.up();
      await settle(tester);
      expect(foregroundDx(tester), closeTo(0, 0.5));
      expect(haptics.calls, isEmpty);
    });

    testWidgets('past the threshold the tray opens with a selection haptic '
        'and the actions are tappable', (tester) async {
      await pumpFp(tester, row());
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Coffee')),
      );
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(haptics.calls, [HapticType.selection]);
      await gesture.up();
      await settle(tester);
      expect(foregroundDx(tester), closeTo(-144, 0.5));
      await tester.tap(find.byKey(const ValueKey('fp-swipe-action-Delete')));
      await tester.pump();
      expect(log, ['delete']);
      await settle(tester);
      expect(foregroundDx(tester), closeTo(0, 0.5), reason: 'closes after');
      expect(haptics.calls.last, HapticType.light);
    });

    testWidgets('crossing back below the threshold plays a second tick', (
      tester,
    ) async {
      await pumpFp(tester, row());
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Coffee')),
      );
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(haptics.calls, [HapticType.selection, HapticType.selection]);
      expect(foregroundDx(tester), closeTo(0, 0.5));
    });

    testWidgets('a fling opens the tray from a short drag', (tester) async {
      await pumpFp(tester, row());
      await drag(tester, -30, vx: 2000);
      await settle(tester);
      expect(foregroundDx(tester), closeTo(-144, 0.5));
    });

    testWidgets('tapping the open row closes it; tapping a closed row calls '
        'onTap', (tester) async {
      var taps = 0;
      await pumpFp(tester, row(onTap: () => taps++));
      await drag(tester, -120);
      await settle(tester);
      expect(foregroundDx(tester), closeTo(-144, 0.5));
      await tester.tapAt(rowCenter(tester));
      await settle(tester);
      expect(foregroundDx(tester), closeTo(0, 0.5));
      expect(taps, 0);
      await tester.tap(find.text('Coffee'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a non-dismissible row resists past the tray and never '
        'dismisses', (tester) async {
      await pumpFp(tester, row());
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Coffee')),
      );
      await gesture.moveBy(const Offset(-344, 0));
      await tester.pump();
      expect(foregroundDx(tester), closeTo(-144 - 200 * 0.3, 0.5));
      await gesture.up();
      await settle(tester);
      expect(foregroundDx(tester), closeTo(-144, 0.5));
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('a dismissible row dragged past 55 % slides away, collapses '
        'and reports once', (tester) async {
      var dismissed = 0;
      await pumpFp(tester, row(onDismissed: () => dismissed++));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Coffee')),
      );
      await gesture.moveBy(const Offset(-230, 0));
      await tester.pump();
      expect(foregroundDx(tester), closeTo(-230, 0.5), reason: 'follows');
      await gesture.up();
      await tester.pump();
      await settle(tester);
      expect(dismissed, 1);
      expect(haptics.calls.last, HapticType.medium);
      expect(tester.getSize(find.byKey(const ValueKey('row'))).height, 0);
      // Dragging again after dismissal does nothing.
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('a dismissible row released inside the tray just opens', (
      tester,
    ) async {
      var dismissed = 0;
      await pumpFp(tester, row(onDismissed: () => dismissed++));
      await drag(tester, -120);
      await settle(tester);
      expect(dismissed, 0);
      expect(foregroundDx(tester), closeTo(-144, 0.5));
    });

    testWidgets('reduce motion: snaps and dismisses without animation', (
      tester,
    ) async {
      var dismissed = 0;
      await pumpFp(
        tester,
        row(onDismissed: () => dismissed++),
        reduceMotion: true,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Coffee')),
      );
      await gesture.moveBy(const Offset(-100, 0));
      await gesture.up();
      await tester.pump();
      expect(foregroundDx(tester), closeTo(-144, 0.5), reason: 'instant');
      final g2 = await tester.startGesture(rowCenter(tester));
      await g2.moveBy(const Offset(-200, 0));
      await g2.up();
      await tester.pump();
      expect(dismissed, 1);
      expect(tester.getSize(find.byKey(const ValueKey('row'))).height, 0);
    });

    testWidgets('the controller closes an open row', (tester) async {
      final controller = FpSwipeActionController();
      addTearDown(controller.dispose);
      await pumpFp(tester, row(controller: controller));
      await drag(tester, -120);
      await settle(tester);
      expect(foregroundDx(tester), closeTo(-144, 0.5));
      controller.close();
      await settle(tester);
      expect(foregroundDx(tester), closeTo(0, 0.5));
    });

    testWidgets('disabled: no drag, no tap', (tester) async {
      var taps = 0;
      await pumpFp(tester, row(enabled: false, onTap: () => taps++));
      await drag(tester, -120);
      await settle(tester);
      expect(foregroundDx(tester), 0);
      await tester.tap(find.text('Coffee'));
      expect(taps, 0);
    });

    testWidgets('semantics: label plus custom actions (and Dismiss when '
        'dismissible) that run without a gesture', (tester) async {
      var dismissed = 0;
      final handle = tester.ensureSemantics();
      await pumpFp(tester, row(onDismissed: () => dismissed++));
      final node = tester.getSemantics(find.byKey(const ValueKey('row')));
      expect(node.label, 'Coffee, ₹320');
      final actions = node.getSemanticsData().customSemanticsActionIds!;
      final labels = actions
          .map((id) => CustomSemanticsAction.getAction(id)!.label)
          .toList();
      expect(labels, containsAll(['Details', 'Delete', 'Dismiss']));
      final detailsId = actions.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Details',
      );
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        detailsId,
      );
      expect(log, ['details']);
      final dismissId = actions.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Dismiss',
      );
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        dismissId,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(dismissed, 1);
      handle.dispose();
    });

    testWidgets('a single-action row reveals 72 px', (tester) async {
      await pumpFp(tester, row(actions: 1));
      await drag(tester, -60);
      await settle(tester);
      expect(foregroundDx(tester), closeTo(-72, 0.5));
    });

    testWidgets('1.3× text: the action labels fit', (tester) async {
      await pumpFp(tester, row(), textScale: 1.3);
      await drag(tester, -120);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('FpToast action', () {
    testWidgets('the action runs once, closes the toast and marks the '
        'handle', (tester) async {
      var undone = 0;
      late FpToastHandle handle;
      await pumpFp(
        tester,
        Builder(
          builder: (context) => FpButton(
            label: 'Show',
            expand: false,
            onPressed: () => handle = FpToast.show(
              context,
              message: 'Deleted',
              actionLabel: 'Undo',
              onAction: () => undone++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('SHOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('UNDO'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fp-toast-action')));
      await tester.pump();
      expect(undone, 1);
      expect(handle.actionTaken, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Deleted'), findsNothing);
      await handle.closed;
    });

    testWidgets('without an action the handle reports none and the toast '
        'is one button node', (tester) async {
      late FpToastHandle handle;
      await pumpFp(
        tester,
        Builder(
          builder: (context) => FpButton(
            label: 'Show',
            expand: false,
            onPressed: () => handle = FpToast.show(context, message: 'Hi'),
          ),
        ),
      );
      await tester.tap(find.text('SHOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('fp-toast-action')), findsNothing);
      expect(handle.actionTaken, isFalse);
      handle.dismiss();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('action toast meets the tap-target and label guidelines', (
      tester,
    ) async {
      await pumpFp(
        tester,
        Builder(
          builder: (context) => FpButton(
            label: 'Show',
            expand: false,
            onPressed: () => FpToast.show(
              context,
              message: 'Deleted',
              actionLabel: 'Undo',
              onAction: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('SHOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      FpToast.current?.dismiss();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
