// Shared steps for the on-device flows (`app_flows_test.dart`,
// `perf_test.dart`). Everything here drives the real app: real DI, the real
// sqflite database on the device, the real secure storage and the simulated
// gateway / OTP / contacts the app ships with.
//
// Finders use the `ValueKey`s the screens already carry; nothing here reads
// private state. Demo credentials are public by design (README), so typing
// them in a test leaks nothing.
import 'package:fin_pay/app.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/screens/onboarding/onboarding_screen.dart';
import 'package:fin_pay/screens/onboarding/welcome_screen.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo account every build seeds on first run.
const String demoEmail = 'user@finpay.com';
const String demoPassword = 'FinPay123';

/// How long a step may take on a slow phone before the test fails.
const Duration stepTimeout = Duration(seconds: 20);

/// Boots the app the way `main()` does, minus the native splash plugin and
/// the orientation lock (both are platform calls that the test does not
/// need), and pumps the first frame.
Future<void> launchApp(WidgetTester tester) async {
  await di.reset();
  await di.init();
  await di.sl<AuthRepository>().ensureDemoAccount();
  await di.sl<SettingsCubit>().load();
  await di.sl<SessionCubit>().restore();
  await tester.pumpWidget(const FinPayApp());
  await tester.pump();
  await pumpUntil(
    tester,
    find.byWidgetPredicate(
      (w) => w is WelcomeScreen || w is AppShell || w is OnboardingScreen,
    ),
  );
}

/// Pumps frames until [finder] matches or [timeout] passes.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = stepTimeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Pumps frames until [finder] matches nothing or [timeout] passes.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = stepTimeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder to go away');
}

/// Pumps a fixed amount of real time (entrances, springs, toasts).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Finder key(String name) => find.byKey(ValueKey(name));

/// Taps [name] once it is on screen and pumps a frame.
Future<void> tapKey(WidgetTester tester, String name) async {
  await pumpUntil(tester, key(name));
  await tester.tap(key(name));
  await tester.pump();
}

/// Types into the `EditableText` inside the widget with [name].
Future<void> typeInto(WidgetTester tester, String name, String text) async {
  await pumpUntil(tester, key(name));
  await tester.enterText(
    find.descendant(of: key(name), matching: find.byType(EditableText)),
    text,
  );
  await tester.pump();
}

/// Leaves the app signed out on the login screen, whatever state the device
/// was in: a restored session is logged out through the profile tab, the
/// welcome screen and onboarding are walked through.
Future<void> reachLogin(WidgetTester tester) async {
  if (find.byType(AppShell).evaluate().isNotEmpty) {
    await tester.tap(find.text('Profile'));
    await pumpUntil(tester, key('profile-logout'));
    await tester.ensureVisible(key('profile-logout'));
    await tester.pump();
    await tapKey(tester, 'profile-logout');
    await tapKey(tester, 'logout-confirm');
    await pumpUntil(tester, key('login-submit'));
    return;
  }
  if (find.byType(WelcomeScreen).evaluate().isNotEmpty) {
    await pumpUntil(tester, key('welcome-cta'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    // "Get started" (first run → onboarding) or "Sign in" (seen → login).
    final seen = find.text('SIGN IN').evaluate().isNotEmpty;
    await tester.tap(find.text(seen ? 'SIGN IN' : 'GET STARTED'));
    await tester.pump();
  }
  if (find.byType(OnboardingScreen).evaluate().isNotEmpty ||
      key('onboarding-cta').evaluate().isNotEmpty) {
    for (var page = 0; page < 3; page++) {
      await pumpUntil(tester, key('onboarding-cta'));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(key('onboarding-cta'));
      await tester.pump();
      if (key('login-submit').evaluate().isNotEmpty) break;
    }
  }
  await pumpUntil(tester, key('login-submit'));
}

/// Signs the demo account in and waits for the home shell.
Future<void> signIn(WidgetTester tester) async {
  await typeInto(tester, 'login-email', demoEmail);
  await typeInto(tester, 'login-password', demoPassword);
  await tapKey(tester, 'login-submit');
  await pumpUntil(tester, find.byType(AppShell));
  await pumpUntil(tester, key('home-scroll'));
  await pumpFor(tester, const Duration(milliseconds: 800));
}

/// From home: Send money → [contactId] → types [digits] → Continue → the
/// review screen with the swipe slider on screen.
Future<void> startTransfer(
  WidgetTester tester, {
  required String contactId,
  required String digits,
}) async {
  await tapKey(tester, 'home-action-send');
  await pumpUntil(tester, key('contact-$contactId'));
  await pumpFor(tester, const Duration(milliseconds: 600));
  await tester.ensureVisible(key('contact-$contactId'));
  await tester.pump();
  await tester.tap(key('contact-$contactId'));
  await tester.pump();
  for (final d in digits.split('')) {
    await tester.tap(key('key-$d'));
    await tester.pump(const Duration(milliseconds: 40));
  }
  await pumpFor(tester, const Duration(milliseconds: 300));
  await tapKey(tester, 'transfer-continue');
  await pumpUntil(tester, key('review-swipe'));
  await pumpFor(tester, const Duration(milliseconds: 600));
}

/// Drags the slider thumb across the whole track.
Future<void> swipeToPay(WidgetTester tester) async {
  final thumb = key('fp-swipe-thumb');
  await pumpUntil(tester, thumb);
  final track = tester.getSize(key('review-swipe'));
  await tester.timedDrag(
    thumb,
    Offset(track.width, 0),
    const Duration(milliseconds: 400),
  );
  await tester.pump();
}

/// Dismisses the soft keyboard if the platform showed one.
Future<void> hideKeyboard(WidgetTester tester) async {
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pump();
}
