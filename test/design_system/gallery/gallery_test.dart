import 'dart:ui' show Tristate;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpGallery(
  WidgetTester tester, {
  bool isRelease = false,
  HapticService? haptics,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 7200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: FpTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: FpGalleryScreen(isRelease: isRelease, haptics: haptics),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('FpGalleryScreen', () {
    test('route constant', () {
      expect(FpGallery.route, '/gallery');
    });

    testWidgets('renders nothing in release mode', (tester) async {
      await _pumpGallery(tester, isRelease: true);
      expect(find.byType(Scaffold), findsNothing);
      expect(find.byType(FpButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows every component section in debug', (tester) async {
      await _pumpGallery(tester);
      for (final section in [
        'COLOURS',
        'TYPOGRAPHY',
        'BUTTONS',
        'SURFACES',
        'TEXT FIELDS',
        'OTP FIELD',
        'COUNTDOWN RING',
        'DRAWN CHECK',
        'CHIPS',
        'TOGGLE',
        'SEGMENTED CONTROL',
        'PAGE INDICATOR',
        'AMOUNT TEXT',
        'SKELETON',
        'EMPTY AND ERROR STATES',
        'MOTION',
        'SWIPE TO PAY',
        'SWIPE ACTIONS',
        'BOTTOM NAVIGATION',
        'REFRESH GLYPH',
        'FLIP CARD',
        'TILT CARD',
        'COLLAPSING HEADER',
        'OVERLAYS',
      ]) {
        expect(find.text(section), findsOneWidget, reason: section);
      }
      expect(find.byType(FpButton), findsWidgets);
      expect(find.byType(FpSurface), findsNWidgets(4));
      expect(find.byType(FpTextField), findsNWidgets(4));
      expect(find.byType(FpChip), findsNWidgets(4));
      expect(find.byType(FpOtpField), findsNWidgets(2));
      expect(find.byType(FpCountdownRing), findsNWidgets(3));
      expect(find.byType(FpDrawnCheck), findsNWidgets(2));
      expect(find.byType(FpToggle), findsNWidgets(3));
      expect(find.byType(FpSegmentedControl), findsNWidgets(2));
      expect(find.byType(FpPageIndicator), findsOneWidget);
      expect(find.byType(FpAmountText), findsNWidgets(3));
      expect(find.byType(FpSkeletonRow), findsNWidgets(2));
      expect(find.byType(FpEmptyState), findsOneWidget);
      expect(find.byType(FpErrorState), findsOneWidget);
      expect(find.byType(FpBottomNav), findsOneWidget);
      expect(find.byType(FpSwipeToPay), findsNWidgets(3));
      expect(find.byType(FpProcessingRing), findsNWidgets(2));
      expect(find.byType(FpRefreshGlyph), findsNWidgets(3));
      expect(find.byType(FpFlipCard), findsOneWidget);
      expect(find.byType(FpTiltCard), findsOneWidget);
      expect(find.byType(FpCollapsingHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('meets tap-target, label and contrast guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpGallery(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('interactions drive state and haptics', (tester) async {
      final haptics = FakeHapticService();
      await _pumpGallery(tester, haptics: haptics);
      await tester.tap(find.text('Idle'));
      await tester.pump();
      expect(haptics.calls, contains(HapticType.selection));
      await tester.tap(find.text('Year'));
      await tester.pump();
      await tester.tap(find.byType(FpToggle).first);
      await tester.pump();
      expect(haptics.calls, contains(HapticType.light));
      await tester.tap(find.text('ROLL'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('HIDE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(FpAmountText.masked), findsOneWidget);
      await tester.tap(
        find.ancestor(
          of: find.byType(FpPageIndicator),
          matching: find.byType(FpPressable),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getSemantics(find.byType(FpPageIndicator)).label,
        'Page 3 of 4',
      );
      await tester.tap(find.text('Cards'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .getSemantics(
              find.ancestor(
                of: find.text('Cards'),
                matching: find.byType(FpPressable),
              ),
            )
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      await tester.tap(find.text('FRONT'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('BACK'), findsOneWidget);
      await tester.tap(find.text('SHAKE ME'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('CONFETTI'));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('SHOW TOAST'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Payment of ₹1,200 sent'), findsOneWidget);
      // The skeleton shimmer never settles, so pump explicit durations.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('SHOW SHEET'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Confirm payment'), findsOneWidget);
      await tester.tap(find.text('PAY'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Confirm payment'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 1.3× text scale without overflow', (tester) async {
      await _pumpGallery(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
