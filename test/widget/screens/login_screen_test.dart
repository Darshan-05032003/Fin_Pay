import 'dart:async';

import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'screen_harness.dart';

const ValueKey<String> _email = ValueKey('login-email');
const ValueKey<String> _password = ValueKey('login-password');

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    bool rm = false,
  }) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.login, textScale: scale, reduceMotion: rm);
    await h.settle(tester);
  }

  Future<void> fill(
    WidgetTester tester, {
    String password = 'FinPay123',
  }) async {
    await typeInto(tester, _email, 'user@finpay.com');
    await typeInto(tester, _password, password);
  }

  FpShakeController shake(WidgetTester tester) =>
      tester.widget<FpShake>(find.byType(FpShake).first).controller;

  testWidgets('content: fields, actions, and no demo credentials on screen', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(_email), findsOneWidget);
    expect(find.byKey(_password), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('FORGOT PASSWORD?'), findsOneWidget);
    expect(find.text('CREATE AN ACCOUNT'), findsOneWidget);
    expect(find.textContaining('FinPay123'), findsNothing);
    expect(find.textContaining('user@finpay.com'), findsNothing);
    expect(h.protector.enabled, isTrue);
  });

  testWidgets('empty submit: inline errors, shake and error haptic', (
    tester,
  ) async {
    await open(tester);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.error));
    verifyNever(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
    await typeInto(tester, _email, 'user@finpay.com');
    expect(find.text('Email is required'), findsNothing);
  });

  testWidgets('wrong credentials: typed message under the form', (
    tester,
  ) async {
    await open(tester);
    h.signInFails(const InvalidCredentials(remainingAttempts: 3));
    await fill(tester, password: 'wrongpass');
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('Incorrect email or password. 3 attempts left.'),
      findsOneWidget,
    );
    expect(shake(tester).shakeCount, 1);
    expect(h.haptics.calls, contains(HapticType.error));
    expect(h.session.state, isA<SessionUnauthenticated>());
    expect(h.location, AppRoutes.login);
  });

  testWidgets('lockout: live countdown, disabled button, re-enables after', (
    tester,
  ) async {
    await open(tester);
    h.signInFails(
      AccountLocked(
        until: tester.binding.clock.now().add(const Duration(seconds: 30)),
        remaining: const Duration(seconds: 30),
      ),
    );
    await fill(tester);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Too many attempts. Try again in 30 s.'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Too many attempts. Try again in 20 s.'), findsOneWidget);
    await tapButton(tester, 'Locked');
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.textContaining('Too many attempts'), findsNothing);
    verify(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);
  });

  testWidgets('storage failure is worded differently from wrong credentials', (
    tester,
  ) async {
    await open(tester);
    h.signInFails(const CredentialStoreUnavailable('keystore'));
    await fill(tester);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('Could not check your credentials. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('success: spinner morph, success haptic, lands on home', (
    tester,
  ) async {
    await open(tester);
    final gate = Completer<AuthResult>();
    when(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => gate.future);
    await fill(tester);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('fp-button-spinner')), findsOneWidget);
    gate.complete(AuthSuccess(harnessUser));
    await tester.pump();
    await h.settle(tester);
    expect(h.haptics.calls, contains(HapticType.success));
    expect(h.session.state, const SessionAuthenticated('u1'));
    expect(h.location, AppRoutes.home);
  });

  testWidgets('50 rapid taps on sign in call the repository once', (
    tester,
  ) async {
    await open(tester);
    final gate = Completer<AuthResult>();
    when(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => gate.future);
    await fill(tester);
    final center = tester.getCenter(find.byKey(const ValueKey('login-submit')));
    for (var i = 0; i < 50; i++) {
      await tester.tapAt(center);
    }
    await tester.pump();
    gate.complete(AuthSuccess(harnessUser));
    await h.settle(tester);
    verify(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);
  });

  testWidgets('password visibility toggles and re-hides when backgrounded', (
    tester,
  ) async {
    await open(tester);
    await typeInto(tester, _password, 'FinPay123');
    EditableText field() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(_password),
        matching: find.byType(EditableText),
      ),
    );
    expect(field().obscureText, isTrue);
    await tester.tap(find.byKey(const ValueKey('login-password-toggle')));
    await tester.pump();
    expect(field().obscureText, isFalse);
    // Backgrounding: resumed → inactive → hidden → paused.
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(field().obscureText, isTrue);
    [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(field().obscureText, isTrue, reason: 'stays hidden on resume');
  });

  testWidgets('screen protection stays on across the sign-up push and pop', (
    tester,
  ) async {
    await open(tester);
    expect(h.protector.enableCalls, 1);
    await tapButton(tester, 'Create an account');
    await h.settle(tester);
    expect(h.location, AppRoutes.createAccount);
    expect(SecureScreen.activeCount, 2);
    expect(h.protector.enabled, isTrue);
    expect(h.protector.enableCalls, 1);
    h.router!.pop();
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
    expect(h.protector.enabled, isTrue);
    expect(h.protector.disableCalls, 0);
    h.router!.go(AppRoutes.welcome);
    await h.settle(tester);
    expect(h.protector.enabled, isFalse);
    expect(h.protector.disableCalls, 1);
  });

  testWidgets('forgot password and create account are reachable', (
    tester,
  ) async {
    await open(tester);
    await tapButton(tester, 'Forgot password?');
    await h.settle(tester);
    expect(h.location, AppRoutes.passwordReset);
    h.router!.pop();
    await h.settle(tester);
    await tapButton(tester, 'Create an account');
    await h.settle(tester);
    expect(h.location, AppRoutes.createAccount);
  });

  testWidgets('hostile input never throws and never reaches the repository', (
    tester,
  ) async {
    await open(tester);
    await typeInto(tester, _email, "' OR 1=1 --@x.com");
    await typeInto(tester, _password, '%s%n\u202E😀' * 100);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Enter a valid email address'), findsOneWidget);
    await typeInto(tester, _email, '${'a' * 300}@x.com');
    await typeInto(tester, _password, 'x' * 10000);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    verifyNever(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('reduce motion: everything still works', (tester) async {
    await open(tester, rm: true);
    h.signInFails(const InvalidCredentials(remainingAttempts: 2));
    await fill(tester);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Incorrect email or password. 2 attempts left.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('1.3× text scale: no overflow, guidelines met', (tester) async {
    await open(tester, scale: 1.3);
    await fill(tester);
    await tapButton(tester, 'Sign in');
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
