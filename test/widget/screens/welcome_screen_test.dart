import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/spring_rise.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  testWidgets('new user: brand, tagline and onboarding call to action', (
    tester,
  ) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.welcome);
    await h.settle(tester);
    expect(find.text('FinPay'), findsOneWidget);
    expect(find.text('Your money. Your move.'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('I ALREADY HAVE AN ACCOUNT'), findsOneWidget);
    expect(find.byType(SpringRise), findsOneWidget);
    await tapButton(tester, 'Get started');
    await h.settle(tester);
    expect(h.location, AppRoutes.onboarding);
  });

  testWidgets('returning user: sign in first, create account second', (
    tester,
  ) async {
    await h.init(
      tester,
      initialSettings: const AppSettings(onboardingSeen: true),
    );
    await h.pump(tester, AppRoutes.welcome);
    await h.settle(tester);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE AN ACCOUNT'), findsOneWidget);
    await tapButton(tester, 'Sign in');
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('"I already have an account" goes to login', (tester) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.welcome);
    await h.settle(tester);
    await tapButton(tester, 'I already have an account');
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('session unknown: no calls to action yet', (tester) async {
    await h.init(tester, restore: false);
    await h.pump(tester, AppRoutes.welcome);
    await h.settle(tester);
    expect(find.text('FinPay'), findsOneWidget);
    expect(find.text('GET STARTED'), findsNothing);
  });

  testWidgets('the CTA rises on a spring and ends in place', (tester) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.welcome);
    await tester.pump(const Duration(milliseconds: 450));
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(SpringRise),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.getTranslation().y, greaterThan(0));
    await h.settle(tester);
    final settled = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(SpringRise),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(settled.transform.getTranslation().y.abs(), lessThan(0.5));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  testWidgets('reduce motion: no spring translation, buttons still work', (
    tester,
  ) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.welcome, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 50));
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(SpringRise),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.getTranslation().y, 0);
    await h.settle(tester);
    await tapButton(tester, 'Get started');
    await h.settle(tester);
    expect(h.location, AppRoutes.onboarding);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1.3× text scale has no overflow and meets guidelines', (
    tester,
  ) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.welcome, textScale: 1.3);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
