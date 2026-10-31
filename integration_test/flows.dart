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
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/screens/auth/login_screen.dart';
import 'package:fin_pay/screens/onboarding/onboarding_screen.dart';
import 'package:fin_pay/screens/onboarding/welcome_screen.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The demo account every build seeds on first run.
const String demoEmail = 'user@finpay.com';
const String demoPassword = 'FinPay123';

/// How long a step may take on a slow phone before the test fails.
const Duration stepTimeout = Duration(seconds: 20);

/// Boots the app the way `main()` does, minus the native splash plugin and
/// the orientation lock (both are platform calls that the test does not
/// need), and pumps the first frame.
Future<void> launchApp(WidgetTester tester) async {
  // The integration binding does not register the mock keyboard
  // (`registerTestTextInput` is false), so `enterText` sends client id -1,
  // which `TextInput` accepts only inside an `assert`: typing works in
  // debug and is silently dropped in profile/release builds. Registering
  // it routes the text-input channel through the mock in every mode and
  // keeps the real IME (and its layout shifts) out of the run.
  tester.binding.testTextInput.register();
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
  throw TestFailure(
    'Timed out waiting for $finder; on stage: ${screensOnStage(tester)}',
  );
}

/// The screen-level widgets currently in the tree, for failure messages.
String screensOnStage(WidgetTester tester) => tester.allWidgets
    .map((w) => w.runtimeType.toString())
    .where((n) => n.endsWith('Screen') || n.endsWith('Shell'))
    .toSet()
    .join(', ');

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

/// Taps the bottom-navigation tab called [label]. Scoped to the bar because
/// the same word can appear elsewhere (home has a "Stats" quick action).
Future<void> tapTab(WidgetTester tester, String label) async {
  final tab = find.descendant(
    of: find.byType(FpBottomNav),
    matching: find.text(label),
  );
  await pumpUntil(tester, tab);
  await tester.tap(tab);
  await tester.pump();
}

/// Taps [name] once it is on screen and pumps a frame.
Future<void> tapKey(WidgetTester tester, String name) async {
  await pumpUntil(tester, key(name));
  await tester.tap(key(name));
  await tester.pump();
}

/// The current text of the `EditableText` inside the widget with [name].
String fieldText(WidgetTester tester, String name) {
  final editable = find.descendant(
    of: key(name),
    matching: find.byType(EditableText),
  );
  if (editable.evaluate().isEmpty) return '';
  return tester.widget<EditableText>(editable).controller.text;
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
    await tapTab(tester, 'Profile');
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
    // The key sits on the column of both buttons; the first `FpButton` is
    // the primary one: "Get started" (first run → onboarding) or "Sign in"
    // (onboarding already seen → login).
    await tester.tap(
      find
          .descendant(of: key('welcome-cta'), matching: find.byType(FpButton))
          .first,
    );
    // go_router builds the next page on a later frame; wait for it.
    await pumpUntil(
      tester,
      find.byWidgetPredicate((w) => w is OnboardingScreen || w is LoginScreen),
    );
  }
  if (find.byType(OnboardingScreen).evaluate().isNotEmpty) {
    for (var page = 0; page < 3; page++) {
      if (find.byType(LoginScreen).evaluate().isNotEmpty) break;
      await pumpUntil(tester, key('onboarding-cta'));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(key('onboarding-cta'));
      // Page slide, or the finish → login navigation.
      await pumpFor(tester, const Duration(milliseconds: 400));
    }
  }
  await pumpUntil(tester, key('login-submit'));
}

/// Signs the demo account in and waits for the home shell.
Future<void> signIn(WidgetTester tester) async {
  await typeInto(tester, 'login-email', demoEmail);
  await typeInto(tester, 'login-password', demoPassword);
  // On a phone the IME resizes the form; with a live frame policy the
  // submit button can sit outside the viewport when the tap fires.
  await hideKeyboard(tester);
  await pumpFor(tester, const Duration(milliseconds: 300));
  // A live IME can clobber test input; check what landed and retype once.
  if (fieldText(tester, 'login-email') != demoEmail) {
    await typeInto(tester, 'login-email', demoEmail);
  }
  if (fieldText(tester, 'login-password') != demoPassword) {
    await typeInto(tester, 'login-password', demoPassword);
  }
  await hideKeyboard(tester);
  await tester.ensureVisible(key('login-submit'));
  await tester.pump();
  await tapKey(tester, 'login-submit');
  try {
    await pumpUntil(tester, find.byType(AppShell));
  } on TestFailure catch (e) {
    final message = find
        .descendant(of: key('login-message'), matching: find.byType(Text))
        .evaluate()
        .map((el) => (el.widget as Text).data)
        .join(' | ');
    throw TestFailure(
      '$e\nlogin-message: "$message"; '
      'email field: "${fieldText(tester, 'login-email')}"; '
      'password length: ${fieldText(tester, 'login-password').length}',
    );
  }
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
  await pumpUntil(tester, key('transfer-contacts'));
  await pumpFor(tester, const Duration(milliseconds: 600));
  // The picker is a lazy horizontal list: a contact off screen has no
  // element yet, so scroll the list until the one we want exists.
  await tester.dragUntilVisible(
    key('contact-$contactId'),
    key('transfer-contacts'),
    const Offset(-160, 0),
  );
  await tester.pump();
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

/// A Luhn-valid 16-digit Visa-range test number that differs per call (the
/// app refuses a duplicate last-four + expiry, so re-running on the same
/// install must not reuse a number), formatted 4-4-4-4.
String freshTestPan() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toString();
  final body = '4${stamp.padLeft(14, '0')}'.substring(0, 15);
  var sum = 0;
  for (var i = 0; i < body.length; i++) {
    var d = int.parse(body[body.length - 1 - i]);
    if (i.isEven) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  final pan = '$body${(10 - sum % 10) % 10}';
  return pan.replaceAllMapped(RegExp('.{4}'), (m) => '${m[0]} ').trim();
}

/// From the Cards tab: opens Add card, fills the form and returns to the
/// stack once the card is stored. Numbers must pass Luhn and a duplicate
/// (same last four + expiry) is refused, so callers vary them.
Future<void> addDemoCard(
  WidgetTester tester, {
  required String number,
  required String name,
  required String expiry,
  required String cvv,
}) async {
  // A tap that lands on the first frame after a tab switch can be dropped
  // under a live frame policy; retry until the Add card page is up.
  for (var attempt = 1; ; attempt++) {
    await tester.ensureVisible(key('cards-add'));
    await tester.pump();
    await tapKey(tester, 'cards-add');
    try {
      await pumpUntil(
        tester,
        key('add-card-number'),
        timeout: const Duration(seconds: 5),
      );
      break;
    } on TestFailure {
      if (attempt == 3) rethrow;
      debugPrint('cards-add: page not up after tap $attempt; retrying');
    }
  }
  await typeInto(tester, 'add-card-number', number);
  await typeInto(tester, 'add-card-name', name);
  await typeInto(tester, 'add-card-expiry', expiry);
  await typeInto(tester, 'add-card-cvv', cvv);
  await hideKeyboard(tester);
  await tester.ensureVisible(key('add-card-submit'));
  await tester.pump();
  await tapKey(tester, 'add-card-submit');
  await pumpUntil(tester, find.text('Card added'));
  await pumpUntilGone(tester, key('add-card-submit'));
  await pumpUntil(tester, key('cards-scroll'));
  await pumpFor(tester, const Duration(seconds: 1));
}

/// Taps [doneKey] on a root-navigator page (success / failure) and waits
/// until that page has left the tree and home is interactive again.
/// `find.byType(AppShell)` alone is not enough: the shell sits beneath the
/// page the whole time, so it matches before the page is dismissed.
Future<void> backHome(WidgetTester tester, String doneKey) async {
  await tapKey(tester, doneKey);
  await pumpUntilGone(tester, key(doneKey));
  await pumpFor(tester, const Duration(milliseconds: 500));
  await pumpUntil(tester, key('home-scroll'));
}

/// Drags the slider thumb across the whole track.
Future<void> swipeToPay(WidgetTester tester) async {
  final thumb = key('fp-swipe-thumb');
  // With system animations off (developer option "animator duration scale
  // 0", or an accessibility setting) Flutter reports `disableAnimations`,
  // and `FpSwipeToPay` renders its reduce-motion confirm button instead of
  // the slider. Accept either.
  final confirm = find.descendant(
    of: key('review-swipe'),
    matching: find.byType(FpButton),
  );
  await pumpUntil(
    tester,
    find.byWidgetPredicate(
      (w) => w.key == const ValueKey('fp-swipe-thumb') || w is FpButton,
    ),
  );
  if (thumb.evaluate().isEmpty && confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pump();
    return;
  }
  await pumpUntil(tester, thumb);
  final track = tester.getSize(key('review-swipe'));
  await tester.timedDrag(
    thumb,
    Offset(track.width, 0),
    const Duration(milliseconds: 400),
  );
  await tester.pump();
}

/// Runs [action] inside `binding.traceAction` when the VM service is
/// reachable (`flutter drive --no-dds`), and plainly under `flutter test`,
/// where DDS owns the VM service and `traceAction` throws *before* running
/// the action (so nothing runs twice). The flow still proves itself; only
/// the timeline is skipped.
Future<void> traced(
  IntegrationTestWidgetsFlutterBinding binding,
  Future<void> Function() action, {
  required String reportKey,
}) => _withVmService(
  () => binding.traceAction(action, reportKey: reportKey),
  action,
  reportKey,
);

/// The same fallback for `binding.watchPerformance` (frame timings + GC).
Future<void> watched(
  IntegrationTestWidgetsFlutterBinding binding,
  Future<void> Function() action, {
  required String reportKey,
}) => _withVmService(
  () => binding.watchPerformance(action, reportKey: reportKey),
  action,
  reportKey,
);

Future<void> _withVmService(
  Future<void> Function() instrumented,
  Future<void> Function() plain,
  String reportKey,
) async {
  try {
    await instrumented();
    // `integration_test` reports an unreachable VM service as a StateError
    // (an environment condition, not a bug), thrown before `action` runs.
    // ignore: avoid_catching_errors
  } on StateError catch (e) {
    if (!'$e'.contains('VM Service')) rethrow;
    debugPrint('[$reportKey] VM service unavailable; running uninstrumented');
    await plain();
  }
}

/// Dismisses the soft keyboard if the platform showed one.
Future<void> hideKeyboard(WidgetTester tester) async {
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pump();
}
