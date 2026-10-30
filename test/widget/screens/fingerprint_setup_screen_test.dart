import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/platform/biometric_authenticator.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  Future<void> open(
    WidgetTester tester, {
    bool signedIn = true,
    double scale = 1,
    bool rm = false,
  }) async {
    await h.init(tester, signedIn: signedIn);
    await h.pump(
      tester,
      AppRoutes.fingerprintSetup,
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
  }

  testWidgets('ready: pulsing glyph, scan succeeds, check draws, continue', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Unlock with a touch'), findsOneWidget);
    expect(find.text('USE FINGERPRINT'), findsOneWidget);
    expect(tester.widget<FpPulse>(find.byType(FpPulse)).active, isTrue);
    await tester.tap(find.byKey(const ValueKey('fingerprint-glyph')));
    await tester.pump();
    await tester.pump();
    expect(h.biometrics.prompts, ['Confirm your fingerprint to set up FinPay']);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('fingerprint-check')), findsOneWidget);
    expect(find.text('Fingerprint added'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.success));
    expect(h.settingsRepo.settings.biometricEnabled, isTrue);
    await h.settle(tester);
    await tapButton(tester, 'Continue');
    await h.settle(tester);
    expect(h.location, AppRoutes.home);
  });

  testWidgets('failure shakes, explains, and can be retried', (tester) async {
    await open(tester);
    h.biometrics.result = BiometricResult.failed;
    await tapButton(tester, 'Use fingerprint');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Not recognised. Try again.'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.error));
    expect(
      tester.widget<FpShake>(find.byType(FpShake).first).controller.shakeCount,
      1,
    );
    h.biometrics.result = BiometricResult.success;
    await tapButton(tester, 'Try again');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Fingerprint added'), findsOneWidget);
    expect(h.biometrics.prompts.length, 2);
    await tester.pump(const Duration(milliseconds: 400));
  });

  for (final (result, snippet) in [
    (BiometricResult.lockedOut, 'locked'),
    (BiometricResult.error, 'went wrong'),
  ]) {
    testWidgets('${result.name} is explained with a retry', (tester) async {
      await open(tester);
      h.biometrics.result = result;
      await tapButton(tester, 'Use fingerprint');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining(snippet), findsOneWidget);
      expect(find.text('TRY AGAIN'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
    });
  }

  testWidgets('not available: only continue is offered', (tester) async {
    await h.init(tester, signedIn: true);
    h.biometrics.available = false;
    await h.pump(tester, AppRoutes.fingerprintSetup);
    await h.settle(tester);
    expect(
      find.text('Biometrics are not available on this device.'),
      findsOneWidget,
    );
    expect(find.text('USE FINGERPRINT'), findsNothing);
    expect(find.byKey(const ValueKey('fingerprint-glyph')), findsNothing);
    await tapButton(tester, 'Continue');
    await h.settle(tester);
    expect(h.location, AppRoutes.home);
    expect(h.settingsRepo.settings.biometricEnabled, isFalse);
  });

  testWidgets('not enrolled during the prompt moves to unavailable', (
    tester,
  ) async {
    await open(tester);
    h.biometrics.result = BiometricResult.notEnrolled;
    await tapButton(tester, 'Use fingerprint');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('enrolled'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('not now records the choice and goes home', (tester) async {
    await open(tester);
    await tapButton(tester, 'Not now');
    await h.settle(tester);
    expect(h.settingsRepo.settings.biometricEnabled, isFalse);
    expect(h.location, AppRoutes.home);
  });

  testWidgets('signed out: skipping lands on login, not home', (tester) async {
    await open(tester, signedIn: false);
    await tapButton(tester, 'Not now');
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('20 rapid taps on the glyph prompt once', (tester) async {
    await open(tester);
    final center = tester.getCenter(
      find.byKey(const ValueKey('fingerprint-glyph')),
    );
    for (var i = 0; i < 20; i++) {
      await tester.tapAt(center);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.biometrics.prompts.length, 1);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('reduce motion: no pulse, check appears at once', (tester) async {
    await open(tester, rm: true);
    await tapButton(tester, 'Use fingerprint');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('fingerprint-check')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('1.3× text scale with a failure: no overflow, guidelines met', (
    tester,
  ) async {
    await open(tester, scale: 1.3);
    h.biometrics.result = BiometricResult.lockedOut;
    await tapButton(tester, 'Use fingerprint');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
