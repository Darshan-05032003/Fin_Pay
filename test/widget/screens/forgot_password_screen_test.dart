import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

const ValueKey<String> _email = ValueKey('forgot-email');

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    bool rm = false,
  }) async {
    await h.init(tester);
    await h.pump(
      tester,
      AppRoutes.passwordReset,
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
  }

  testWidgets('validates the email before sending', (tester) async {
    await open(tester);
    expect(find.text('Forgot your password?'), findsOneWidget);
    await tapButton(tester, 'Send reset link');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Email is required'), findsOneWidget);
    await typeInto(tester, _email, 'nope');
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.error));
  });

  testWidgets('a valid email shows the spinner then the sent state', (
    tester,
  ) async {
    await open(tester);
    await typeInto(tester, _email, 'user@finpay.com');
    await tapButton(tester, 'Send reset link');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('fp-button-spinner')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.textContaining('user@finpay.com'), findsOneWidget);
    expect(find.byType(FpDrawnCheck), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.success));
    await tapButton(tester, 'Use a different email');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Forgot your password?'), findsOneWidget);
  });

  testWidgets('back to sign in after sending', (tester) async {
    await open(tester);
    await typeInto(tester, _email, 'user@finpay.com');
    await tapButton(tester, 'Send reset link');
    await tester.pump(const Duration(seconds: 2));
    await tapButton(tester, 'Back to sign in');
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('reduce motion and 1.3× text scale', (tester) async {
    await open(tester, scale: 1.3, rm: true);
    await typeInto(tester, _email, 'user@finpay.com');
    await tapButton(tester, 'Send reset link');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
