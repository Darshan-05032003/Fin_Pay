import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'create_account_screen_test.dart' show fillSignUp;
import 'screen_harness.dart';

const ValueKey<String> _field = ValueKey('otp-field');

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  /// Boots at the sign-up form, fills it and continues to the code step.
  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    bool rm = false,
  }) async {
    await h.init(tester);
    await h.pump(
      tester,
      AppRoutes.createAccount,
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
    await fillSignUp(tester);
    await tapButton(tester, 'Continue');
    await h.settle(tester);
    expect(h.location, AppRoutes.verification);
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await typeInto(tester, _field, code);
    await tester.pump();
    await tester.pump();
  }

  Color cellBorder(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('fp-otp-cell-0')),
    );
    return (box.decoration! as BoxDecoration).border!.top.color;
  }

  testWidgets('opened directly it shows the start-again guard', (tester) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.verification);
    await h.settle(tester);
    expect(find.text('Start again'), findsOneWidget);
    expect(find.byKey(_field), findsNothing);
    await tapButton(tester, 'Create account');
    await h.settle(tester);
    expect(h.location, AppRoutes.createAccount);
  });

  testWidgets('the right code verifies, signs in and continues', (
    tester,
  ) async {
    await open(tester);
    h.signInSucceeds();
    expect(find.byKey(const ValueKey('otp-countdown')), findsOneWidget);
    await enterCode(tester, '543210');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Verified'), findsOneWidget);
    expect(find.byType(FpDrawnCheck), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.success));
    await h.flush(tester);
    await h.settle(tester);
    verify(
      () => h.auth.setCredentials(
        email: 'aarav@example.com',
        password: 'Str0ng!pass',
      ),
    ).called(1);
    expect(h.session.state, isA<SessionAuthenticated>());
    expect(h.location, AppRoutes.fingerprintSetup);
    expect(h.protector.enabled, isFalse);
  });

  testWidgets('a pasted message with junk still verifies', (tester) async {
    await open(tester);
    h.signInSucceeds();
    await enterCode(tester, 'Your FinPay code is 54-32-10. Do not share it.');
    await h.flush(tester);
    await h.settle(tester);
    expect(h.location, AppRoutes.fingerprintSetup);
  });

  testWidgets('a wrong code shakes, flashes red and counts down attempts', (
    tester,
  ) async {
    await open(tester);
    await enterCode(tester, '000000');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
    expect(cellBorder(tester), FpColors.alert);
    expect(h.haptics.calls, contains(HapticType.error));
    expect(
      tester.getSemantics(find.byType(FpOtpField)).value,
      '0 of 6 digits entered',
    );
    await tester.pump(const Duration(seconds: 1));
    expect(h.location, AppRoutes.verification);
  });

  testWidgets('five wrong codes lock the step', (tester) async {
    await open(tester);
    for (var i = 0; i < 5; i++) {
      await enterCode(tester, '11111$i');
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Too many wrong codes. Go back and start again.'),
      findsOneWidget,
    );
    expect(tester.widget<FpOtpField>(find.byKey(_field)).enabled, isFalse);
    await enterCode(tester, '543210');
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.location, AppRoutes.verification);
    expect(find.text('Verified'), findsNothing);
  });

  testWidgets('resend waits for the countdown, then restarts it', (
    tester,
  ) async {
    await open(tester);
    int seconds() => int.parse(
      tester
          .widget<FpCountdownRing>(find.byKey(const ValueKey('otp-countdown')))
          .label!,
    );
    expect(
      tester.widget<FpButton>(find.byKey(const ValueKey('otp-resend'))).enabled,
      isFalse,
    );
    final start = seconds();
    expect(start, inInclusiveRange(20, 30));
    await tester.pump(const Duration(seconds: 12));
    expect(seconds(), start - 12);
    await tester.pump(const Duration(seconds: 30));
    expect(seconds(), 0);
    expect(
      tester.widget<FpButton>(find.byKey(const ValueKey('otp-resend'))).enabled,
      isTrue,
    );
    await tapButton(tester, 'Resend code');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('A new code is on its way.'), findsOneWidget);
    expect(seconds(), inInclusiveRange(28, 30));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a failed account write offers a retry', (tester) async {
    await open(tester);
    when(
      () => h.auth.setCredentials(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Failure('Could not store credentials'));
    await enterCode(tester, '543210');
    await h.flush(tester);
    await h.settle(tester);
    expect(find.text('Could not store credentials'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(h.location, AppRoutes.verification);
    when(
      () => h.auth.setCredentials(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Success(null));
    h.signInSucceeds();
    await tapButton(tester, 'Try again');
    await h.flush(tester);
    await h.settle(tester);
    expect(h.location, AppRoutes.fingerprintSetup);
  });

  testWidgets('back keeps the typed form underneath', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Back'));
    await h.settle(tester);
    expect(h.location, AppRoutes.createAccount);
    expect(find.text('Aarav Mehta'), findsOneWidget);
  });

  testWidgets('reduce motion path', (tester) async {
    await open(tester, rm: true);
    await enterCode(tester, '000000');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
    h.signInSucceeds();
    await enterCode(tester, '543210');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Verified'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1.3× text scale: no overflow, guidelines met', (tester) async {
    await open(tester, scale: 1.3);
    await enterCode(tester, '000000');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
