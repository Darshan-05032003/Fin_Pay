import 'dart:async';

import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

/// A host screen with a button that shows a toast or a sheet.
class _Host extends StatelessWidget {
  const _Host({required this.onPressed});

  final void Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FpButton(label: 'Open', onPressed: () => onPressed(context)),
      ),
    );
  }
}

const _handleLabel = 'Drag handle. Swipe down to dismiss';

void main() {
  group('FpToast', () {
    for (final kind in FpToastKind.values) {
      testWidgets(
        '${kind.name} toast shows, is a live region, auto-dismisses',
        (tester) async {
          late FpToastHandle handle;
          await pumpFp(
            tester,
            _Host(
              onPressed: (context) => handle = FpToast.show(
                context,
                message: 'Hello',
                kind: kind,
                duration: const Duration(seconds: 1),
              ),
            ),
            scaffold: false,
          );
          await tester.tap(find.text('OPEN'));
          await tester.pump();
          await tester.pump(FpMotion.emphasized);
          expect(find.text('Hello'), findsOneWidget);
          final node = tester.getSemantics(find.text('Hello'));
          expect(node.flagsCollection.isLiveRegion, isTrue);
          expect(node.label, contains('Hello'));
          expect(FpToast.current, same(handle));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(find.text('Hello'), findsNothing);
          expect(FpToast.current, isNull);
          await expectLater(handle.closed, completes);
        },
      );
    }

    testWidgets('tap dismisses early and a new toast replaces the old one', (
      tester,
    ) async {
      await pumpFp(
        tester,
        _Host(onPressed: (context) => FpToast.show(context, message: 'One')),
        scaffold: false,
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(FpMotion.emphasized);
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsNothing);

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(FpMotion.emphasized);
      expect(find.text('One'), findsOneWidget);
      FpToast.current?.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('One'), findsNothing);
    });

    testWidgets('reduce motion: fade only, no slide', (tester) async {
      await pumpFp(
        tester,
        _Host(onPressed: (context) => FpToast.show(context, message: 'Quiet')),
        scaffold: false,
        reduceMotion: true,
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(FpMotion.fast);
      expect(find.text('Quiet'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Quiet'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      FpToast.current?.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('host disposed while a toast is open does not throw', (
      tester,
    ) async {
      await pumpFp(
        tester,
        _Host(onPressed: (context) => FpToast.show(context, message: 'Bye')),
        scaffold: false,
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      FpToast.current?.dismiss();
    });
  });

  group('FpBottomSheet', () {
    setUp(FpBottomSheet.reset);

    Future<void> open(
      WidgetTester tester, {
      bool reduceMotion = false,
      bool dismissible = true,
      void Function(Object?)? onResult,
    }) async {
      await pumpFp(
        tester,
        _Host(
          onPressed: (context) async {
            final result = await FpBottomSheet.show<String>(
              context,
              title: 'Confirm',
              isDismissible: dismissible,
              builder: (context) => FpButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop('ok'),
              ),
            );
            onResult?.call(result);
          },
        ),
        scaffold: false,
        reduceMotion: reduceMotion,
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
    }

    testWidgets('springs in, returns the pop result, scrim has a label', (
      tester,
    ) async {
      Object? result;
      await open(tester, onResult: (r) => result = r);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Confirm'), findsOneWidget);
      expect(FpBottomSheet.isOpen, isTrue);
      final sheet = find.byKey(const ValueKey('fp-sheet-translation'));
      final early = tester.widget<FractionalTranslation>(sheet).translation.dy;
      expect(early, greaterThan(0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FractionalTranslation>(sheet).translation.dy,
        closeTo(0, 0.001),
      );
      expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(result, 'ok');
      expect(FpBottomSheet.isOpen, isFalse);
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('drag down past half dismisses; small drag snaps back', (
      tester,
    ) async {
      Object? result = 'unset';
      await open(tester, onResult: (r) => result = r);
      await tester.pumpAndSettle();
      final handle = find.bySemanticsLabel(_handleLabel);
      final sheetHeight = tester
          .getSize(find.byKey(const ValueKey('fp-sheet-translation')))
          .height;
      await tester.drag(handle, Offset(0, sheetHeight * 0.2));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      await tester.drag(handle, Offset(0, sheetHeight * 0.7));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('a fast fling dismisses from any position', (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      final handle = find.bySemanticsLabel(_handleLabel);
      await tester.fling(handle, const Offset(0, 60), 2000);
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsNothing);
      expect(FpBottomSheet.isOpen, isFalse);
    });

    testWidgets('tapping the scrim dismisses; not when isDismissible=false', (
      tester,
    ) async {
      await open(tester);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsNothing);

      await open(tester, dismissible: false);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
    });

    testWidgets('double show opens a single sheet', (tester) async {
      await pumpFp(
        tester,
        _Host(
          onPressed: (context) {
            unawaited(
              FpBottomSheet.show<void>(
                context,
                title: 'First',
                builder: (_) => const SizedBox(height: 50),
              ),
            );
            unawaited(
              FpBottomSheet.show<void>(
                context,
                title: 'Second',
                builder: (_) => const SizedBox(height: 50),
              ),
            );
          },
        ),
        scaffold: false,
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(FpBottomSheet.isOpen, isFalse);
    });

    testWidgets('popped mid-entrance does not throw', (tester) async {
      await open(tester);
      await tester.pump(const Duration(milliseconds: 30));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm'), findsNothing);
      expect(FpBottomSheet.isOpen, isFalse);
      // Let the open button's submit guard expire.
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('double-tapping the handle pops once', (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      final handle = find.bySemanticsLabel(_handleLabel);
      await tester.tap(handle);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(handle, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);
      expect(FpBottomSheet.isOpen, isFalse);
    });

    testWidgets('reduce motion: fades, no translation', (tester) async {
      await open(tester, reduceMotion: true);
      await tester.pump(FpMotion.fast);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byKey(const ValueKey('fp-sheet-translation')), findsNothing);
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('back navigation closes the sheet cleanly', (tester) async {
      await open(tester);
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsNothing);
      expect(FpBottomSheet.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
