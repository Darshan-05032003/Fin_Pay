import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/onboarding/onboarding_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

/// Horizontal translation of each parallax layer of the first page.
List<double> _layerShifts(WidgetTester tester) {
  final illustration = find.byType(OnboardingIllustration).first;
  return tester
      .widgetList<Transform>(
        find.descendant(
          of: illustration,
          matching: find.byWidgetPredicate(
            (w) => w is Transform && w.child is CustomPaint,
          ),
        ),
      )
      .map((t) => t.transform.getTranslation().x)
      .toList();
}

void main() {
  late ScreenHarness h;
  const pages = OnboardingPageSpec.all;

  setUp(() => h = ScreenHarness());

  testWidgets('next walks the pages, the last one finishes to login', (
    tester,
  ) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.onboarding);
    await h.settle(tester);
    expect(find.text(pages[0].title), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(FpPageIndicator)).label,
      'Page 1 of 3',
    );
    await tapButton(tester, 'Next');
    await h.settle(tester);
    expect(find.text(pages[1].title), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(FpPageIndicator)).label,
      'Page 2 of 3',
    );
    await tapButton(tester, 'Next');
    await h.settle(tester);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    await tapButton(tester, 'Get started');
    await h.settle(tester);
    expect(h.settingsRepo.settings.onboardingSeen, isTrue);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('skip records "seen" and goes to login', (tester) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.onboarding);
    await h.settle(tester);
    await tapButton(tester, 'Skip');
    await h.settle(tester);
    expect(h.settingsRepo.settings.onboardingSeen, isTrue);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('once seen, /onboarding redirects to login', (tester) async {
    await h.init(
      tester,
      initialSettings: const AppSettings(onboardingSeen: true),
    );
    await h.pump(tester, AppRoutes.onboarding);
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets(
    'swiping updates the indicator and layers move at different speeds',
    (tester) async {
      await h.init(tester);
      await h.pump(tester, AppRoutes.onboarding);
      await h.settle(tester);
      expect(_layerShifts(tester), everyElement(closeTo(0, 0.001)));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('onboarding-pages'))),
      );
      // The first move clears the touch slop; the scroll starts on the next.
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      final shifts = _layerShifts(tester);
      expect(shifts.length, 3);
      expect(shifts.toSet().length, 3, reason: 'every layer has its own speed');
      expect(shifts.every((s) => s > 0), isTrue, reason: 'layers lag the page');
      expect(shifts[0], greaterThan(shifts[1]));
      expect(shifts[1], greaterThan(shifts[2]));
      await gesture.moveBy(const Offset(-200, 0));
      await gesture.up();
      await h.settle(tester);
      expect(
        tester.getSemantics(find.byType(FpPageIndicator)).label,
        'Page 2 of 3',
      );
      expect(find.text(pages[1].title), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets('reduce motion: layers stay static while swiping', (
    tester,
  ) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.onboarding, reduceMotion: true);
    await h.settle(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('onboarding-pages'))),
    );
    await gesture.moveBy(const Offset(-60, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(_layerShifts(tester), everyElement(0));
    await gesture.up();
    await h.settle(tester);
    await tapButton(tester, 'Next');
    await h.settle(tester);
    await tapButton(tester, 'Next');
    await h.settle(tester);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('illustrations are described for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await h.init(tester);
    await h.pump(tester, AppRoutes.onboarding);
    await h.settle(tester);
    expect(
      tester.getSemantics(find.byType(OnboardingIllustration).first).label,
      pages[0].semanticLabel,
    );
    handle.dispose();
  });

  testWidgets('1.3× text scale: no overflow, guidelines met', (tester) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.onboarding, textScale: 1.3);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });

  testWidgets('leaves no ticker behind after 20 page swings', (tester) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.onboarding);
    await h.settle(tester);
    for (var i = 0; i < 20; i++) {
      await tester.fling(
        find.byKey(const ValueKey('onboarding-pages')),
        Offset(i.isEven ? -300 : 300, 0),
        1200,
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });
}
