@Tags(['golden'])
library;

import 'dart:async';

import 'package:fin_pay/core/platform/biometric_authenticator.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget/screens/create_account_screen_test.dart' show fillSignUp;
import '../../widget/screens/screen_harness.dart';

/// Every onboarding / auth screen in its main states, at 1.0× and 1.3×.
/// Baselines live in `goldens/<screen>_<state>_<scale>.png`; regenerate
/// with `flutter test --update-goldens test/golden/screens` only when a
/// change is intended.
void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  Future<void> snap(WidgetTester tester, String name, double scale) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final s = scale.toStringAsFixed(1).replaceAll('.', '_');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${name}_$s.png'),
    );
  }

  for (final scale in [1.0, 1.3]) {
    group('${scale}x', () {
      testWidgets('welcome new and returning', (tester) async {
        await h.init(tester);
        await h.pump(tester, AppRoutes.welcome, textScale: scale);
        await snap(tester, 'welcome_new', scale);
        await h.settings.setOnboardingSeen(seen: true);
        await tester.pump();
        await snap(tester, 'welcome_returning', scale);
      });

      testWidgets('onboarding first and last page', (tester) async {
        await h.init(tester);
        await h.pump(tester, AppRoutes.onboarding, textScale: scale);
        await snap(tester, 'onboarding_page1', scale);
        await tapButton(tester, 'Next');
        await tester.pump(const Duration(seconds: 1));
        await tapButton(tester, 'Next');
        await snap(tester, 'onboarding_page3', scale);
      });

      testWidgets('login content, errors and lockout', (tester) async {
        await h.init(tester);
        await h.pump(tester, AppRoutes.login, textScale: scale);
        await snap(tester, 'login_content', scale);
        await tapButton(tester, 'Sign in');
        await snap(tester, 'login_errors', scale);
        h.signInFails(
          AccountLocked(
            until: tester.binding.clock.now().add(const Duration(seconds: 30)),
            remaining: const Duration(seconds: 30),
          ),
        );
        await typeInto(
          tester,
          const ValueKey('login-email'),
          'user@finpay.com',
        );
        await typeInto(tester, const ValueKey('login-password'), 'FinPay123');
        await tapButton(tester, 'Sign in');
        await tester.pump(const Duration(milliseconds: 100));
        await snap(tester, 'login_locked', scale);
      });

      testWidgets('create account content and errors', (tester) async {
        await h.init(tester);
        await h.pump(tester, AppRoutes.createAccount, textScale: scale);
        await typeInto(tester, const ValueKey('create-password'), 'Abcdefg1');
        await snap(tester, 'create_account_content', scale);
        await typeInto(tester, const ValueKey('create-password'), '');
        await tapButton(tester, 'Continue');
        await snap(tester, 'create_account_errors', scale);
      });

      testWidgets('verification entry, wrong code, verified and expired', (
        tester,
      ) async {
        await h.init(tester);
        await h.pump(tester, AppRoutes.createAccount, textScale: scale);
        await h.settle(tester);
        await fillSignUp(tester);
        await tapButton(tester, 'Continue');
        await snap(tester, 'verification_entry', scale);
        await typeInto(tester, const ValueKey('otp-field'), '000000');
        await tester.pump();
        await snap(tester, 'verification_wrong', scale);
        // Keep the account write pending so the "setting up" copy is stable.
        when(
          () => h.auth.setCredentials(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => Completer<Result<void>>().future);
        await typeInto(tester, const ValueKey('otp-field'), '543210');
        await tester.pump();
        await snap(tester, 'verification_verified', scale);
        await h.pump(tester, AppRoutes.verification, textScale: scale);
        await snap(tester, 'verification_expired', scale);
      });

      testWidgets('fingerprint ready, failed, success and unavailable', (
        tester,
      ) async {
        await h.init(tester, signedIn: true);
        await h.pump(tester, AppRoutes.fingerprintSetup, textScale: scale);
        await snap(tester, 'fingerprint_ready', scale);
        h.biometrics.result = BiometricResult.failed;
        await tapButton(tester, 'Use fingerprint');
        await snap(tester, 'fingerprint_failed', scale);
        h.biometrics.result = BiometricResult.success;
        await tapButton(tester, 'Try again');
        await snap(tester, 'fingerprint_success', scale);
        h.biometrics.available = false;
        await h.pump(tester, AppRoutes.fingerprintSetup, textScale: scale);
        await snap(tester, 'fingerprint_unavailable', scale);
      });

      testWidgets('forgot password form and sent', (tester) async {
        await h.init(tester);
        await h.pump(tester, AppRoutes.passwordReset, textScale: scale);
        await snap(tester, 'forgot_form', scale);
        await typeInto(
          tester,
          const ValueKey('forgot-email'),
          'user@finpay.com',
        );
        await tapButton(tester, 'Send reset link');
        await snap(tester, 'forgot_sent', scale);
      });
    });
  }
}
