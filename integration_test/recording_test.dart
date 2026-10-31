// Drives the ten flows listed in docs/images/README.md on a phone while
// `adb shell screenrecord` runs, and prints device-clock markers so each
// clip can be cut from the recording:
//
//   [rec] <name> start <epoch ms>
//   [rec] <name> end <epoch ms>
//
// A flow that fails is reported and skipped; the others still record.
// Run in profile mode for smooth motion, with the developer "animation
// scale" options at 1×, and start the screen recording first:
//
//   adb shell screenrecord --time-limit 180 /sdcard/rec_1.mp4   (per 180 s)
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/recording_test.dart --profile --no-dds \
//       -d <device id>
//
// Everything is the real app: real DI, the on-device database, the
// simulated gateway and the demo account (`user@finpay.com` / `FinPay123`).
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/platform/fakes/fake_screen_protector.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/screens/auth/login_screen.dart';
import 'package:fin_pay/screens/onboarding/onboarding_screen.dart';
import 'package:fin_pay/screens/onboarding/welcome_screen.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows.dart';

/// Screen capture is blocked by `FLAG_SECURE` on every signed-in screen (as
/// it should be), so the recording run alone fakes the screen protector.
final recordingOverrides = di.DiOverrides(
  screenProtector: FakeScreenProtector(),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // `--dart-define=FINPAY_REC_ONLY=profile,statistics` records only those
  // flows; the app is signed in first so each flow can start from home.
  const only = String.fromEnvironment('FINPAY_REC_ONLY');
  final wanted = only.isEmpty
      ? null
      : only.split(',').map((s) => s.trim()).toSet();

  testWidgets('record the README flows', (tester) async {
    if (wanted != null) {
      await launchApp(tester, overrides: recordingOverrides);
      if (find.byType(AppShell).evaluate().isEmpty) {
        await reachLogin(tester);
        await signIn(tester);
      }
    }

    Future<void> clip(String name, Future<void> Function() body) async {
      if (wanted != null && !wanted.contains(name)) return;
      debugPrint('[rec] $name start ${DateTime.now().millisecondsSinceEpoch}');
      try {
        await body();
      } on Exception catch (e) {
        debugPrint('[rec] $name FAILED $e');
      }
      debugPrint('[rec] $name end ${DateTime.now().millisecondsSinceEpoch}');
      await pumpFor(tester, const Duration(milliseconds: 800));
    }

    Finder keyPrefix(String prefix) => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(prefix),
    );

    // 1. Welcome wordmark, spring CTAs, parallax onboarding.
    await clip('onboarding', () async {
      await launchApp(tester, overrides: recordingOverrides);
      if (find.byType(AppShell).evaluate().isNotEmpty) {
        // A restored session skips the welcome screen; log out to login.
        await reachLogin(tester);
        return;
      }
      if (find.byType(WelcomeScreen).evaluate().isNotEmpty) {
        await pumpUntil(tester, key('welcome-cta'));
        await pumpFor(tester, const Duration(milliseconds: 1600));
        await tester.tap(
          find
              .descendant(
                of: key('welcome-cta'),
                matching: find.byType(FpButton),
              )
              .first,
        );
        await pumpUntil(
          tester,
          find.byWidgetPredicate(
            (w) => w is OnboardingScreen || w is LoginScreen,
          ),
        );
      }
      if (find.byType(OnboardingScreen).evaluate().isNotEmpty) {
        await pumpFor(tester, const Duration(milliseconds: 900));
        for (var page = 0; page < 2; page++) {
          await tester.timedDrag(
            key('onboarding-pages'),
            const Offset(-320, 0),
            const Duration(milliseconds: 650),
          );
          await pumpFor(tester, const Duration(milliseconds: 1000));
        }
        for (var i = 0; i < 3; i++) {
          if (find.byType(LoginScreen).evaluate().isNotEmpty) break;
          await tapKey(tester, 'onboarding-cta');
          await pumpFor(tester, const Duration(milliseconds: 700));
        }
      }
      await pumpUntil(tester, key('login-submit'));
    });

    // 2. Validation shake on a wrong password, spinner morph, fade-through.
    await clip('login', () async {
      await typeInto(tester, 'login-email', demoEmail);
      await typeInto(tester, 'login-password', 'not-the-password');
      await hideKeyboard(tester);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.ensureVisible(key('login-submit'));
      await tester.pump();
      await tapKey(tester, 'login-submit');
      await pumpFor(tester, const Duration(milliseconds: 1800));
      await typeInto(tester, 'login-password', demoPassword);
      await hideKeyboard(tester);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tapKey(tester, 'login-submit');
      await pumpUntil(tester, find.byType(AppShell));
      await pumpUntil(tester, key('home-scroll'));
      await pumpFor(tester, const Duration(milliseconds: 1800));
    });

    // 3. Collapsing header, odometer, hide balance.
    await clip('home_header', () async {
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.timedDrag(
        key('home-scroll'),
        const Offset(0, -360),
        const Duration(milliseconds: 700),
      );
      await pumpFor(tester, const Duration(milliseconds: 800));
      await tester.timedDrag(
        key('home-scroll'),
        const Offset(0, 360),
        const Duration(milliseconds: 700),
      );
      await pumpFor(tester, const Duration(milliseconds: 800));
      await tapKey(tester, 'home-hide-balance');
      await pumpFor(tester, const Duration(milliseconds: 1000));
      await tapKey(tester, 'home-hide-balance');
      await pumpFor(tester, const Duration(milliseconds: 800));
    });

    // 4. Add card: live preview, BIN cross-fade, validation, flip on CVV.
    final visa = freshTestPan();
    final mastercard = freshTestPan(prefix: '55');
    final rupay = freshTestPan(prefix: '65');
    await clip('add_card', () async {
      await tapTab(tester, 'Cards');
      await pumpUntil(tester, key('cards-scroll'));
      await pumpFor(tester, const Duration(milliseconds: 900));
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
        }
      }
      await pumpFor(tester, const Duration(milliseconds: 600));
      final digits = visa.replaceAll(' ', '');
      for (final n in [4, 8, 12, 16]) {
        await typeInto(tester, 'add-card-number', digits.substring(0, n));
        await pumpFor(tester, const Duration(milliseconds: 450));
      }
      await typeInto(tester, 'add-card-number', mastercard);
      await pumpFor(tester, const Duration(milliseconds: 1000));
      await typeInto(tester, 'add-card-number', rupay);
      await pumpFor(tester, const Duration(milliseconds: 1000));
      await typeInto(tester, 'add-card-name', 'Aarav Mehta');
      await pumpFor(tester, const Duration(milliseconds: 400));
      await typeInto(tester, 'add-card-expiry', '12/30');
      await pumpFor(tester, const Duration(milliseconds: 400));
      await typeInto(tester, 'add-card-cvv', '321');
      await pumpFor(tester, const Duration(milliseconds: 1100));
      await hideKeyboard(tester);
      await tester.ensureVisible(key('add-card-submit'));
      await tester.pump();
      await tapKey(tester, 'add-card-submit');
      await pumpUntil(tester, find.text('Card added'));
      await pumpUntilGone(tester, key('add-card-submit'));
      await pumpUntil(tester, key('cards-scroll'));
      await pumpFor(tester, const Duration(milliseconds: 1200));
    });

    // A second card (off clip) so the pile fans out into a real stack.
    try {
      await addDemoCard(
        tester,
        number: freshTestPan(),
        name: 'Second Card',
        expiry: '10/32',
        cvv: '456',
      );
    } on Exception catch (e) {
      debugPrint('[rec] seed second card FAILED $e');
    }

    // 5. Card stack: fan-out, carousel, flip, CVV reveal, collapse.
    await clip('card_stack', () async {
      await pumpUntil(tester, key('cards-pile'));
      await tester.ensureVisible(key('cards-pile'));
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 600));
      await tapKey(tester, 'cards-pile');
      await pumpFor(tester, const Duration(milliseconds: 1500));
      await tester.timedDrag(
        key('card-carousel'),
        const Offset(-320, 0),
        const Duration(milliseconds: 600),
      );
      await pumpFor(tester, const Duration(milliseconds: 1000));
      final focused = keyPrefix('focused-card-');
      if (focused.evaluate().isNotEmpty) {
        await tester.tap(focused.first);
        await pumpFor(tester, const Duration(milliseconds: 1100));
        final reveal = keyPrefix('reveal-cvv-');
        if (reveal.evaluate().isNotEmpty) {
          await tester.tap(reveal.first);
          await pumpFor(tester, const Duration(milliseconds: 2600));
        }
        await tester.tap(focused.first);
        await pumpFor(tester, const Duration(milliseconds: 900));
      }
      await tapKey(tester, 'cards-collapse');
      await pumpFor(tester, const Duration(milliseconds: 1000));
    });

    // 6. Keypad, review sheet, snap-back, swipe to pay, success.
    await clip('swipe_to_pay', () async {
      await tapTab(tester, 'Home');
      await pumpUntil(tester, key('home-scroll'));
      await tapKey(tester, 'home-action-send');
      await pumpUntil(tester, key('transfer-contacts'));
      await pumpFor(tester, const Duration(milliseconds: 900));
      await tester.dragUntilVisible(
        key('contact-c-priya'),
        key('transfer-contacts'),
        const Offset(-160, 0),
      );
      await tester.pump();
      await tester.tap(key('contact-c-priya'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      for (final d in '1250'.split('')) {
        await tester.tap(key('key-$d'));
        await pumpFor(tester, const Duration(milliseconds: 380));
      }
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tapKey(tester, 'transfer-continue');
      await pumpUntil(tester, key('review-swipe'));
      await pumpFor(tester, const Duration(milliseconds: 1300));
      final thumb = key('fp-swipe-thumb');
      if (thumb.evaluate().isNotEmpty) {
        final track = tester.getSize(key('review-swipe'));
        await tester.timedDrag(
          thumb,
          Offset(track.width * 0.4, 0),
          const Duration(milliseconds: 500),
        );
        await pumpFor(tester, const Duration(milliseconds: 1000));
        await tester.timedDrag(
          thumb,
          Offset(track.width, 0),
          const Duration(milliseconds: 900),
        );
      } else {
        await swipeToPay(tester);
      }
      await pumpUntil(tester, key('success-check'));
      await pumpFor(tester, const Duration(milliseconds: 3500));
      await backHome(tester, 'success-done');
    });

    // 7. Timeout on "Test Timeout": drawn cross, shake, Retry, already paid.
    await clip('payment_failure', () async {
      await startTransfer(tester, contactId: 'c-timeout', digits: '75');
      await swipeToPay(tester);
      await pumpUntil(
        tester,
        key('review-failure'),
        timeout: const Duration(seconds: 40),
      );
      await pumpFor(tester, const Duration(milliseconds: 2200));
      await tapKey(tester, 'failure-retry');
      await pumpUntil(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w.key == const ValueKey('success-check') ||
              w.key == const ValueKey('review-failure'),
        ),
        timeout: const Duration(seconds: 40),
      );
      await pumpFor(tester, const Duration(milliseconds: 2600));
      if (key('success-done').evaluate().isNotEmpty) {
        await backHome(tester, 'success-done');
      } else {
        await backHome(tester, 'failure-home');
      }
    });

    // 8. Charts growing, drawing, sweeping; period switcher.
    await clip('statistics', () async {
      await tapTab(tester, 'Stats');
      await pumpUntil(tester, key('stats-period'));
      await pumpFor(tester, const Duration(milliseconds: 2600));
      for (final period in ['Month', 'Year', 'Week']) {
        final tab = find.descendant(
          of: key('stats-period'),
          matching: find.text(period),
        );
        if (tab.evaluate().isEmpty) continue;
        await tester.tap(tab.first);
        await pumpFor(tester, const Duration(milliseconds: 1600));
      }
    });

    // 9. Sticky headers, search, filters, swipe actions with Undo.
    await clip('transactions', () async {
      await tapTab(tester, 'Home');
      await pumpUntil(tester, key('home-scroll'));
      await tapKey(tester, 'home-action-history');
      await pumpUntil(tester, key('transactions-scroll'));
      await pumpFor(tester, const Duration(milliseconds: 1100));
      await tester.fling(
        key('transactions-scroll'),
        const Offset(0, -500),
        1200,
      );
      await pumpFor(tester, const Duration(milliseconds: 1300));
      await tester.fling(
        key('transactions-scroll'),
        const Offset(0, 500),
        1200,
      );
      await pumpFor(tester, const Duration(milliseconds: 900));
      await typeInto(tester, 'transactions-search', 'Priya');
      await pumpFor(tester, const Duration(milliseconds: 1600));
      await typeInto(tester, 'transactions-search', '');
      await hideKeyboard(tester);
      await pumpFor(tester, const Duration(milliseconds: 800));
      await tapKey(tester, 'filter-sent');
      await pumpFor(tester, const Duration(milliseconds: 1300));
      await tapKey(tester, 'filter-all');
      await pumpFor(tester, const Duration(milliseconds: 900));
      final row = keyPrefix('tx-');
      if (row.evaluate().isNotEmpty) {
        await tester.timedDrag(
          row.first,
          const Offset(-230, 0),
          const Duration(milliseconds: 600),
        );
        await pumpFor(tester, const Duration(milliseconds: 1000));
        final delete = find.text('Delete');
        if (delete.evaluate().isNotEmpty) {
          await tester.tap(delete.first);
          await pumpFor(tester, const Duration(milliseconds: 1300));
          final undo = find.text('Undo');
          if (undo.evaluate().isNotEmpty) {
            await tester.tap(undo.first);
            await pumpFor(tester, const Duration(milliseconds: 1500));
          }
        }
      }
    });

    // 10. Parallax header, NeoPOP toggles, logout sheet.
    await clip('profile', () async {
      // A root-navigator page (history) covers the shell, and offstage
      // tabs are invisible to finders: pop back to the shell first.
      if (key('transactions-scroll').evaluate().isNotEmpty) {
        await tester.binding.handlePopRoute();
        await pumpUntilGone(tester, key('transactions-scroll'));
        await pumpFor(tester, const Duration(milliseconds: 600));
      }
      await tapTab(tester, 'Profile');
      await pumpUntil(tester, key('profile-scroll'));
      await pumpFor(tester, const Duration(milliseconds: 900));
      await tester.timedDrag(
        key('profile-scroll'),
        const Offset(0, -220),
        const Duration(milliseconds: 600),
      );
      await pumpFor(tester, const Duration(milliseconds: 700));
      await tester.timedDrag(
        key('profile-scroll'),
        const Offset(0, 220),
        const Duration(milliseconds: 600),
      );
      await pumpFor(tester, const Duration(milliseconds: 700));
      for (final setting in ['setting-haptics', 'setting-hide-balance']) {
        await tester.ensureVisible(key(setting));
        await tester.pump();
        await tester.tap(key(setting));
        await pumpFor(tester, const Duration(milliseconds: 900));
        await tester.tap(key(setting));
        await pumpFor(tester, const Duration(milliseconds: 700));
      }
      await tester.ensureVisible(key('profile-logout'));
      await tester.pump();
      await tapKey(tester, 'profile-logout');
      await pumpUntil(tester, key('logout-sheet'));
      await pumpFor(tester, const Duration(milliseconds: 1900));
      await tapKey(tester, 'logout-cancel');
      await pumpFor(tester, const Duration(milliseconds: 900));
    });

    debugPrint('[rec] all done ${DateTime.now().millisecondsSinceEpoch}');
  });
}
