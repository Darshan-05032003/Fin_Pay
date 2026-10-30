import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

const ValueKey<String> _name = ValueKey('create-name');
const ValueKey<String> _email = ValueKey('create-email');
const ValueKey<String> _phone = ValueKey('create-phone');
const ValueKey<String> _password = ValueKey('create-password');

/// Fills the sign-up form with valid demo data.
Future<void> fillSignUp(WidgetTester tester) async {
  await typeInto(tester, _name, 'Aarav Mehta');
  await typeInto(tester, _email, 'aarav@example.com');
  await typeInto(tester, _phone, '+91 98765 43210');
  await typeInto(tester, _password, 'Str0ng!pass');
}

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
      AppRoutes.createAccount,
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
  }

  testWidgets('content and screen protection', (tester) async {
    await open(tester);
    expect(find.text('Create your account'), findsOneWidget);
    for (final key in [_name, _email, _phone, _password]) {
      expect(find.byKey(key), findsOneWidget);
    }
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.textContaining('terms of service'), findsOneWidget);
    expect(h.protector.enabled, isTrue);
  });

  testWidgets('empty submit: four inline errors, shake and haptic', (
    tester,
  ) async {
    await open(tester);
    await tapButton(tester, 'Continue');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.error));
    expect(
      tester.widget<FpShake>(find.byType(FpShake).first).controller.shakeCount,
      1,
    );
    expect(h.location, AppRoutes.createAccount);
  });

  testWidgets('the strength meter follows the password', (tester) async {
    await open(tester);
    expect(find.text('Too short'), findsOneWidget);
    await typeInto(tester, _password, 'abcdefgh');
    expect(find.text('Weak'), findsOneWidget);
    await typeInto(tester, _password, 'Abcdefg1!');
    expect(find.text('Strong'), findsOneWidget);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Password strength: Strong'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('valid form continues to verification with nothing in extra', (
    tester,
  ) async {
    await open(tester);
    await fillSignUp(tester);
    await tapButton(tester, 'Continue');
    await h.settle(tester);
    expect(h.location, AppRoutes.verification);
    expect(h.extra, isNull);
    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.textContaining('+91 ••••• •3210'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.medium));
  });

  testWidgets('password toggle and background re-hide', (tester) async {
    await open(tester);
    await typeInto(tester, _password, 'Str0ng!pass');
    EditableText field() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(_password),
        matching: find.byType(EditableText),
      ),
    );
    expect(field().obscureText, isTrue);
    await tester.tap(find.byKey(const ValueKey('create-password-toggle')));
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

  testWidgets('back returns to login (pop when pushed, go otherwise)', (
    tester,
  ) async {
    await open(tester);
    await tapButton(tester, 'I already have an account');
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
    await tapButton(tester, 'Create an account');
    await h.settle(tester);
    expect(h.location, AppRoutes.createAccount);
    await tester.tap(find.byTooltip('Back'));
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('phone field only accepts phone characters', (tester) async {
    await open(tester);
    await typeInto(tester, _phone, 'abc+91 (987) 65-43210xyz😀');
    final text = tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(_phone),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;
    expect(text, '+91 (987) 65-43210');
  });

  testWidgets('reduce motion: continue still works', (tester) async {
    await open(tester, rm: true);
    await fillSignUp(tester);
    await tapButton(tester, 'Continue');
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.location, AppRoutes.verification);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1.3× text scale with errors: no overflow, guidelines met', (
    tester,
  ) async {
    await open(tester, scale: 1.3);
    await tapButton(tester, 'Continue');
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
