import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'insights_activity_fixtures.dart';
import 'screen_harness.dart';

void main() {
  late ScreenHarness h;
  late InsightsRepos repos;

  setUp(() => h = ScreenHarness());

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    bool rm = false,
    AppSettings settings = AppSettings.defaults,
  }) async {
    repos = InsightsRepos();
    await repos.init(h, tester: tester, initialSettings: settings);
    await h.pump(tester, AppRoutes.profile, textScale: scale, reduceMotion: rm);
    await h.settle(tester);
  }

  Finder toggle(String key) => find.descendant(
    of: find.byKey(ValueKey('setting-$key')),
    matching: find.byType(FpToggle),
  );

  Future<void> flip(WidgetTester tester, String key) async {
    await tester.tap(toggle(key));
    await tester.pump();
    await h.settle(tester);
  }

  group('header', () {
    testWidgets('shows the user from UserBloc with initials, name, email', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Aarav Mehta'), findsOneWidget);
      expect(find.text('user@finpay.com'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(h.protector.enabled, isFalse, reason: 'no balances on profile');
    });

    testWidgets('loading: skeleton header until the user arrives', (
      tester,
    ) async {
      repos = InsightsRepos();
      final gate = Completer<Result<User?>>();
      when(repos.users.getCurrentUser).thenAnswer((_) => gate.future);
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.profile);
      await tester.pump();
      expect(find.byType(FpSkeleton), findsWidgets);
      expect(find.text('Aarav Mehta'), findsNothing);
      gate.complete(Success(harnessUser));
      await tester.pump();
      await h.settle(tester);
      expect(find.text('Aarav Mehta'), findsOneWidget);
    });

    testWidgets('no user row: a neutral placeholder, no crash', (tester) async {
      repos = InsightsRepos();
      when(
        repos.users.getCurrentUser,
      ).thenAnswer((_) async => const Success(null));
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.profile);
      await h.settle(tester);
      expect(find.text('FinPay user'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the header moves slower than the list (parallax)', (
      tester,
    ) async {
      // A short surface so the list has room to scroll.
      repos = InsightsRepos();
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.profile, size: const Size(430, 600));
      await h.settle(tester);
      final header = find.byKey(const ValueKey('profile-header'));
      final before = tester.getTopLeft(header).dy;
      await tester.drag(
        find.byKey(const ValueKey('profile-scroll')),
        const Offset(0, -100),
      );
      await tester.pump();
      final moved = before - tester.getTopLeft(header).dy;
      expect(moved, greaterThan(0));
      expect(moved, lessThan(100), reason: 'parallax factor < 1');
      expect(moved, closeTo(40, 1), reason: 'factor 0.4 → 40 of 100 px');
    });
  });

  group('settings toggles', () {
    testWidgets('each toggle flips the setting and persists once', (
      tester,
    ) async {
      await open(tester);
      expect(h.settingsRepo.saves, 0);
      await flip(tester, 'haptics');
      expect(h.settingsRepo.settings.hapticsEnabled, isFalse);
      await flip(tester, 'hide-balance');
      expect(h.settingsRepo.settings.hideBalance, isTrue);
      await flip(tester, 'biometric');
      expect(h.settingsRepo.settings.biometricEnabled, isTrue);
      await flip(tester, 'reduce-motion');
      expect(h.settingsRepo.settings.reduceMotion, isTrue);
      expect(h.settingsRepo.saves, 4);
      expect(h.settings.state.reduceMotion, isTrue);
      // Flip one back.
      await flip(tester, 'hide-balance');
      expect(h.settingsRepo.settings.hideBalance, isFalse);
      expect(h.settingsRepo.saves, 5);
      expect(h.haptics.calls, contains(HapticType.light));
    });

    testWidgets('toggles reflect persisted settings on open', (tester) async {
      await open(
        tester,
        settings: const AppSettings(hideBalance: true, hapticsEnabled: false),
      );
      expect(tester.widget<FpToggle>(toggle('hide-balance')).value, isTrue);
      expect(tester.widget<FpToggle>(toggle('haptics')).value, isFalse);
      expect(tester.widget<FpToggle>(toggle('reduce-motion')).value, isFalse);
    });

    testWidgets('a failing save restores the previous value', (tester) async {
      await open(tester);
      h.settingsRepo.failing = true;
      await flip(tester, 'hide-balance');
      expect(h.settings.state.hideBalance, isFalse);
      expect(tester.widget<FpToggle>(toggle('hide-balance')).value, isFalse);
    });

    testWidgets('toggles announce their state to screen readers', (
      tester,
    ) async {
      await open(tester);
      final handle = tester.ensureSemantics();
      await tester.pump();
      var node = tester.getSemantics(toggle('haptics'));
      expect(node.label, 'Haptics');
      expect(
        node.getSemanticsData().flagsCollection.isToggled,
        Tristate.isTrue,
      );
      await flip(tester, 'haptics');
      node = tester.getSemantics(toggle('haptics'));
      expect(
        node.getSemanticsData().flagsCollection.isToggled,
        Tristate.isFalse,
      );
      handle.dispose();
    });
  });

  group('rows', () {
    testWidgets('the design gallery row opens /gallery in debug', (
      tester,
    ) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-gallery')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('profile-gallery')));
      await tester.pump();
      await h.settle(tester);
      expect(h.location, AppRoutes.gallery);
    });

    testWidgets('the gallery row is hidden when not offered', (tester) async {
      repos = InsightsRepos();
      await repos.init(h, tester: tester);
      await tester.binding.setSurfaceSize(phoneSize);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SessionCubit>.value(value: h.session),
            BlocProvider<SettingsCubit>.value(value: h.settings),
            BlocProvider(create: (_) => di.sl<UserBloc>()),
          ],
          child: MaterialApp(
            theme: FpTheme.dark(),
            home: const ProfileScreen(showGallery: false),
          ),
        ),
      );
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('profile-gallery')), findsNothing);
      expect(find.byKey(const ValueKey('profile-about')), findsOneWidget);
    });

    testWidgets('About opens a sheet with the attribution', (tester) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-about')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('profile-about')));
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('about-sheet')), findsOneWidget);
      expect(find.text(ProfileScreen.aboutText), findsOneWidget);
      expect(
        ProfileScreen.aboutText,
        "FinPay — inspired by CRED's NeoPOP design language; not affiliated "
        'with CRED',
      );
      await tapButton(tester, 'Done');
      await h.settle(tester);
      expect(find.byKey(const ValueKey('about-sheet')), findsNothing);
    });
  });

  group('logout', () {
    Future<void> openLogout(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-logout')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('profile-logout')));
      await tester.pump();
      await h.settle(tester);
    }

    testWidgets('confirming signs out and the router lands on /login; '
        'protected routes stay closed', (tester) async {
      await open(tester);
      await openLogout(tester);
      expect(find.byKey(const ValueKey('logout-sheet')), findsOneWidget);
      expect(FpBottomSheet.isOpen, isTrue);
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.pump();
      await h.settle(tester);
      verify(() => h.auth.signOut()).called(1);
      expect(h.session.isAuthenticated, isFalse);
      expect(h.location, AppRoutes.login);
      expect(h.haptics.calls, contains(HapticType.success));
      // Deep-linking back into the app is refused while signed out.
      h.router!.go(AppRoutes.profile);
      await tester.pump();
      await h.settle(tester);
      expect(h.location, AppRoutes.login);
      h.router!.go(AppRoutes.transactions);
      await tester.pump();
      await h.settle(tester);
      expect(h.location, AppRoutes.login);
    });

    testWidgets('staying signed in closes the sheet and keeps the session', (
      tester,
    ) async {
      await open(tester);
      await openLogout(tester);
      await tester.tap(find.byKey(const ValueKey('logout-cancel')));
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('logout-sheet')), findsNothing);
      verifyNever(() => h.auth.signOut());
      expect(h.location, AppRoutes.profile);
    });

    testWidgets('dragging the sheet away cancels too', (tester) async {
      await open(tester);
      await openLogout(tester);
      await tester.tapAt(const Offset(20, 40)); // the scrim
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('logout-sheet')), findsNothing);
      verifyNever(() => h.auth.signOut());
    });

    testWidgets('a failing sign-out shows an error and stays', (tester) async {
      await open(tester);
      when(() => h.auth.signOut()).thenThrow(Exception('storage'));
      await openLogout(tester);
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.pump();
      await h.settle(tester);
      expect(find.text('Could not log out. Try again.'), findsOneWidget);
      expect(h.location, AppRoutes.profile);
      expect(h.haptics.calls, contains(HapticType.error));
    });
  });

  group('motion and accessibility', () {
    testWidgets('reduce motion renders everything', (tester) async {
      await open(tester, rm: true);
      expect(find.text('Aarav Mehta'), findsOneWidget);
      expect(toggle('haptics'), findsOneWidget);
    });

    testWidgets('1.3×: no overflow and guidelines met', (tester) async {
      await open(tester, scale: 1.3);
      expect(tester.takeException(), isNull);
      await expectGuidelines(tester);
    });
  });
}
