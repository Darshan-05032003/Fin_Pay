import 'package:fin_pay/app.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/routes/app_router.dart';
import 'package:fin_pay/screens/onboarding/welcome_screen.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Splash → first-frame hand-off (F7): `FinPayApp` renders the real first
/// route on its very first frame for every session state, under the
/// design-system theme whose scaffold colour equals the native splash
/// colour, so there is no placeholder, no white frame and no theme swap
/// between the splash and the app.
void main() {
  late MockAuthRepository auth;
  late SessionCubit session;
  late GoRouter router;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => null);
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<void> boot(
    WidgetTester tester, {
    AppSettings settings = AppSettings.defaults,
  }) async {
    await di.init(
      overrides: di.DiOverrides(
        haptics: FakeHapticService(),
        biometrics: FakeBiometricAuthenticator(),
        motionSensor: FakeMotionSensor(),
        screenProtector: FakeScreenProtector(),
        secureStorage: FakeSecureStorage(),
        settingsRepository: InMemorySettingsRepository(settings),
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        authRepository: auth,
      ),
    );
    session = di.sl<SessionCubit>();
    await di.sl<SettingsCubit>().load();
    router = AppRouter.build(
      session: session,
      settings: di.sl<SettingsCubit>(),
      isDebug: true,
    );
    addTearDown(() async {
      await tester.pump(const Duration(seconds: 5));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      router.dispose();
      await di.reset();
    });
  }

  /// Pumps the app once: exactly one frame, no settling.
  Future<void> firstFrame(WidgetTester tester) async {
    await tester.pumpWidget(FinPayApp(router: router));
    await tester.pump();
  }

  testWidgets('the theme is the design system and its background matches '
      'the splash colour', (tester) async {
    await boot(tester);
    await session.restore();
    await firstFrame(tester);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme!.extension<FpTokens>(), isNotNull);
    expect(app.darkTheme!.extension<FpTokens>(), isNotNull);
    expect(app.theme!.scaffoldBackgroundColor, FpColors.background);
    expect(app.darkTheme!.scaffoldBackgroundColor, FpColors.background);
    // The value the native splash is generated from (pubspec
    // `flutter_native_splash.color`).
    expect(FpColors.background.toARGB32(), 0xFF0B0B0D);
    expect(app.debugShowCheckedModeBanner, isFalse);
  });

  testWidgets('session unknown: the first frame is the welcome screen', (
    tester,
  ) async {
    await boot(tester);
    expect(session.state, const SessionUnknown());
    await firstFrame(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('signed out: the first frame is the welcome screen', (
    tester,
  ) async {
    await boot(tester);
    await session.restore();
    expect(session.state, isA<SessionUnauthenticated>());
    await firstFrame(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('signed out with onboarding seen: welcome offers sign-in', (
    tester,
  ) async {
    await boot(tester, settings: const AppSettings(onboardingSeen: true));
    await session.restore();
    await firstFrame(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('signed in: the first frame is already the home shell', (
    tester,
  ) async {
    when(() => auth.restoreSession()).thenAnswer((_) async => 'u1');
    await boot(tester);
    await session.restore();
    expect(session.state, const SessionAuthenticated('u1'));
    await firstFrame(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(router.state.uri.path, '/home');
  });
}
