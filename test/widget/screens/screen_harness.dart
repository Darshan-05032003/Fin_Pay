import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/routes/app_page_transitions.dart';
import 'package:fin_pay/routes/app_router.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// The demo user returned by a successful mocked sign-in.
final User harnessUser = User(
  id: 'u1',
  fullName: 'Aarav Mehta',
  email: 'user@finpay.com',
  balance: const Money.paise(5624690),
  createdAt: DateTime.utc(2026),
);

/// Phone-sized surface used by every screen test.
const Size phoneSize = Size(430, 932);

/// Boots the real router and DI with platform fakes, and pumps a route.
///
/// Every screen test goes through the real `AppRouter`, so redirects, the
/// auth shell route and page transitions are exercised as in the app.
class ScreenHarness {
  late MockAuthRepository auth;
  late FakeHapticService haptics;
  late FakeBiometricAuthenticator biometrics;
  late FakeScreenProtector protector;
  late InMemorySettingsRepository settingsRepo;
  late FakeSecureStorage storage;
  GoRouter? router;
  bool _disposed = false;

  SessionCubit get session => di.sl<SessionCubit>();
  SettingsCubit get settings => di.sl<SettingsCubit>();

  /// Registers fakes. [tester]'s fake clock backs `Clock`, so countdowns
  /// advance with `tester.pump(duration)`.
  Future<void> init(
    WidgetTester tester, {
    AppSettings initialSettings = AppSettings.defaults,
    bool signedIn = false,
    bool restore = true,
    Clock? clock,
  }) async {
    sqfliteFfiInit();
    Logger.sink = (_) {};
    auth = MockAuthRepository();
    haptics = FakeHapticService();
    biometrics = FakeBiometricAuthenticator();
    protector = FakeScreenProtector();
    settingsRepo = InMemorySettingsRepository(initialSettings);
    storage = FakeSecureStorage();
    when(
      () => auth.restoreSession(),
    ).thenAnswer((_) async => signedIn ? harnessUser.id : null);
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(
      () => auth.setCredentials(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const AuthFailed(InvalidCredentials(remainingAttempts: 4)),
    );
    SecureScreen.debugReset();
    AppPageTransitions.builder = AppPageTransitions.fp;
    // Always tear down, even when an expectation fails mid-test, so GetIt
    // is clean for the next test.
    addTearDown(() => dispose(tester));
    await di.init(
      overrides: di.DiOverrides(
        haptics: haptics,
        biometrics: biometrics,
        motionSensor: FakeMotionSensor(),
        screenProtector: protector,
        secureStorage: storage,
        settingsRepository: settingsRepo,
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        clock: clock ?? tester.binding.clock,
        authRepository: auth,
      ),
    );
    await settings.load();
    if (restore) await session.restore();
  }

  /// Makes the next mocked sign-in succeed.
  void signInSucceeds() {
    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => AuthSuccess(harnessUser));
  }

  /// Makes the next mocked sign-in fail with [failure].
  void signInFails(AuthFailure failure) {
    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => AuthFailed(failure));
  }

  Future<void> pump(
    WidgetTester tester,
    String location, {
    double textScale = 1,
    bool reduceMotion = false,
    Size size = phoneSize,
  }) async {
    await tester.binding.setSurfaceSize(size);
    router?.dispose();
    router = AppRouter.build(
      session: session,
      settings: settings,
      initialLocation: location,
      isDebug: true,
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionCubit>.value(value: session),
          BlocProvider<SettingsCubit>.value(value: settings),
          // The legacy home screen (where several flows end) needs these.
          BlocProvider(create: (_) => di.sl<UserBloc>()),
          BlocProvider(create: (_) => di.sl<TransactionBloc>()),
          BlocProvider(create: (_) => di.sl<CardBloc>()),
          BlocProvider(create: (_) => di.sl<NotificationBloc>()),
        ],
        child: MaterialApp.router(
          theme: FpTheme.dark(),
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The location on screen, including imperative pushes inside a shell.
  String get location => router!.state.uri.toString();

  Object? get extra => router!.state.extra;

  /// Lets real asynchronous work (the sqflite ffi worker) complete while
  /// still pumping frames; `tester.pump` alone only advances fake time.
  Future<void> flush(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Pumps enough frames for entrances, transitions and springs to end.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> dispose(WidgetTester tester) async {
    if (_disposed) return;
    _disposed = true;
    // Flush submit-guard timers and the legacy screens' delayed entrances
    // before unmounting, so no timer is pending when the test ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    router?.dispose();
    router = null;
    await tester.binding.setSurfaceSize(null);
    AppPageTransitions.builder = AppPageTransitions.fp;
    await di.reset();
  }
}

/// Types into the `EditableText` inside the widget with [key].
Future<void> typeInto(WidgetTester tester, Key key, String text) async {
  await tester.enterText(
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
    text,
  );
  await tester.pump();
}

/// Runs the three accessibility guidelines.
Future<void> expectGuidelines(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

/// Taps an `FpButton` by its (upper-cased) label.
Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.text(label.toUpperCase()));
  await tester.pump();
}
