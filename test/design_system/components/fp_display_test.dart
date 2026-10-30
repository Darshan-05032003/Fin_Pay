import 'dart:ui' show Tristate;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neopop/neopop.dart';

import '../helpers/pump.dart';

void main() {
  group('FpSurface', () {
    for (final variant in FpSurfaceVariant.values) {
      testWidgets('${variant.name} renders its child', (tester) async {
        await pumpFp(
          tester,
          FpSurface(variant: variant, child: const Text('Card')),
        );
        expect(find.text('Card'), findsOneWidget);
        expect(
          find.byType(NeoPopCard),
          variant == FpSurfaceVariant.flat ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tappable surface is a button with haptic and plunk', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      var taps = 0;
      await pumpFp(
        tester,
        FpSurface(
          onTap: () => taps++,
          semanticLabel: 'Open card',
          haptics: haptics,
          width: 200,
          height: 100,
          child: const Text('Card'),
        ),
      );
      final node = tester.getSemantics(find.byType(FpSurface));
      expect(node.label, 'Open card');
      expect(node.flagsCollection.isButton, isTrue);
      final size = tester.getSize(find.byType(FpSurface));
      expect(size.width, 200);
      expect(size.height, 100);
      await tester.tap(find.byType(FpSurface));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(haptics.calls, [HapticType.light]);
    });

    testWidgets('non-tappable surface with label exposes it', (tester) async {
      await pumpFp(
        tester,
        const FpSurface(semanticLabel: 'Balance card', child: Text('x')),
      );
      expect(tester.getSemantics(find.byType(FpSurface)).label, 'Balance card');
    });

    testWidgets('custom colour, edge and depth', (tester) async {
      await pumpFp(
        tester,
        const FpSurface(
          color: Colors.red,
          edge: FpEdge.accent,
          depth: 10,
          child: Text('x'),
        ),
      );
      final card = tester.widget<NeoPopCard>(find.byType(NeoPopCard));
      expect(card.color, Colors.red);
      expect(card.depth, 10);
      expect(card.hShadowColor, FpEdge.accent.right);
    });
  });

  group('FpAmountText', () {
    testWidgets('shows the formatted amount instantly on first build', (
      tester,
    ) async {
      await pumpFp(tester, const FpAmountText(paise: 12345678));
      expect(find.text('₹'), findsOneWidget);
      final label = tester.getSemantics(find.byType(FpAmountText)).label;
      expect(label, '₹1,23,456.78');
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        0,
        reason: 'nothing animating',
      );
    });

    testWidgets('rolls digits when the value changes', (tester) async {
      await pumpFp(tester, const FpAmountText(paise: 100000));
      await pumpFp(tester, const FpAmountText(paise: 900000));
      await tester.pump();
      // Mid-roll: the hundreds-of-rupees column shows intermediate digits.
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('5'), findsWidgets);
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byType(FpAmountText)).label, '₹9,000.00');
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('reduce motion: instant', (tester) async {
      await pumpFp(
        tester,
        const FpAmountText(paise: 100000),
        reduceMotion: true,
      );
      await pumpFp(
        tester,
        const FpAmountText(paise: 900000),
        reduceMotion: true,
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('animateFirstBuild counts up from zero', (tester) async {
      await pumpFp(
        tester,
        const FpAmountText(paise: 500000, animateFirstBuild: true),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await tester.pumpAndSettle();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('mask hides digits and semantics', (tester) async {
      await pumpFp(
        tester,
        const FpAmountText(paise: 12345678, hide: FpAmountHide.mask),
      );
      await tester.pumpAndSettle();
      expect(find.text(FpAmountText.masked), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(
        tester.getSemantics(find.byType(FpAmountText)).label,
        'Amount hidden',
      );
    });

    testWidgets('blur mode renders through an ImageFiltered', (tester) async {
      await pumpFp(
        tester,
        const FpAmountText(paise: 12345678, hide: FpAmountHide.blur),
      );
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(FpAmountText)).label,
        'Amount hidden',
      );
    });

    testWidgets('handles the maximum amount at 1.3× text scale', (
      tester,
    ) async {
      await pumpFp(
        tester,
        const FpAmountText(paise: 99999999999),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byType(FpAmountText)).label,
        '₹99,99,99,999.99',
      );
      expect(tester.getSize(find.byType(FpAmountText)).width, lessThan(800));
    });

    testWidgets('negative amounts and width changes do not throw', (
      tester,
    ) async {
      await pumpFp(tester, const FpAmountText(paise: -4500));
      await pumpFp(tester, const FpAmountText(paise: 99999999999));
      await tester.pumpAndSettle();
      await pumpFp(tester, const FpAmountText(paise: 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSemantics(find.byType(FpAmountText)).label, '₹0.00');
    });
  });

  group('FpSkeleton', () {
    testWidgets('shimmers with its own ticker; static with reduce motion', (
      tester,
    ) async {
      await pumpFp(tester, const FpSkeleton(width: 100, height: 20));
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      await pumpFp(
        tester,
        const FpSkeleton(width: 100, height: 20),
        reduceMotion: true,
      );
      await pumpFp(tester, const SizedBox());
      await pumpFp(
        tester,
        const FpSkeleton(width: 100, height: 20),
        reduceMotion: true,
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('a group shares one ticker across many skeletons', (
      tester,
    ) async {
      await pumpFp(
        tester,
        FpSkeletonGroup(
          child: Column(
            children: [for (var i = 0; i < 20; i++) const FpSkeletonRow()],
          ),
        ),
        surfaceSize: const Size(400, 2000),
      );
      await tester.pump();
      expect(find.byType(FpSkeleton), findsNWidgets(80));
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      final circle = tester.widget<FpSkeleton>(find.byType(FpSkeleton).first);
      expect(circle.radius, 22);
    });
  });

  group('FpEmptyState / FpErrorState', () {
    testWidgets('empty state shows title, message and action', (tester) async {
      var acted = 0;
      await pumpFp(
        tester,
        FpEmptyState(
          title: 'No transactions',
          message: 'Send money to see it here',
          actionLabel: 'Send',
          onAction: () => acted++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No transactions'), findsOneWidget);
      expect(find.text('Send money to see it here'), findsOneWidget);
      await tester.tap(find.text('SEND'));
      await tester.pumpAndSettle();
      expect(acted, 1);
    });

    testWidgets('error state retries; without onRetry no button', (
      tester,
    ) async {
      var retries = 0;
      await pumpFp(
        tester,
        FpErrorState(title: 'Failed', onRetry: () => retries++),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      await pumpFp(tester, const FpErrorState(title: 'Failed'));
      await tester.pumpAndSettle();
      expect(find.byType(FpButton), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('reduce motion renders without entrance transforms', (
      tester,
    ) async {
      await pumpFp(
        tester,
        const FpEmptyState(title: 'Empty'),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.text('Empty'), findsOneWidget);
      final fades = tester.widgetList<FadeTransition>(
        find.descendant(
          of: find.byType(FpEntrance),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fades, isNotEmpty);
      await tester.pumpAndSettle();
      for (final f in fades) {
        expect(f.opacity.value, 1);
      }
    });
  });

  group('semantic flags', () {
    testWidgets('toggle exposes the toggled state', (tester) async {
      await pumpFp(tester, FpToggle(value: true, onChanged: (_) {}));
      expect(
        tester.getSemantics(find.byType(FpToggle)).flagsCollection.isToggled,
        Tristate.isTrue,
      );
    });
  });
}
