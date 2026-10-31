import 'package:animations/animations.dart';
import 'package:fin_pay/app.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/routes/app_page_transitions.dart';
import 'package:fin_pay/routes/app_router.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository auth;
  late SessionCubit session;
  late GoRouter router;

  final user = User(
    id: 'u1',
    fullName: 'U',
    email: 'u@x.com',
    createdAt: DateTime.utc(2026),
  );

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => null);
    when(() => auth.signOut()).thenAnswer((_) async {});
    await di.init(
      overrides: di.DiOverrides(
        haptics: FakeHapticService(),
        biometrics: FakeBiometricAuthenticator(),
        motionSensor: FakeMotionSensor(),
        screenProtector: FakeScreenProtector(),
        secureStorage: FakeSecureStorage(),
        settingsRepository: InMemorySettingsRepository(),
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        authRepository: auth,
      ),
    );
    session = di.sl<SessionCubit>();
    AppPageTransitions.builder = AppPageTransitions.fade;
  });

  tearDown(() async {
    router.dispose();
    await di.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool isDebug = true,
    bool withSettings = false,
  }) async {
    router = AppRouter.build(
      session: session,
      settings: withSettings ? di.sl<SettingsCubit>() : null,
      isDebug: isDebug,
    );
    await tester.pumpWidget(FinPayApp(router: router));
    await tester.pump();
  }

  /// Legacy screens schedule delayed entrance animations; flush them so the
  /// test ends without pending timers.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('signed out: /home is redirected to /login', (tester) async {
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.home);
    await tester.pump();
    expect(location(), AppRoutes.login);
    await settle(tester);
  });

  testWidgets('signed in: /login is redirected to /home and /home stays', (
    tester,
  ) async {
    when(() => auth.restoreSession()).thenAnswer((_) async => 'u1');
    await session.restore();
    await pump(tester);
    expect(location(), AppRoutes.home);
    router.go(AppRoutes.login);
    await tester.pump();
    expect(location(), AppRoutes.home);
    await settle(tester);
  });

  testWidgets('signing in moves the app from login to home automatically', (
    tester,
  ) async {
    await session.restore();
    when(
      () => auth.signIn(email: 'u@x.com', password: 'pw'),
    ).thenAnswer((_) async => AuthSuccess(user));
    await pump(tester);
    router.go(AppRoutes.login);
    await tester.pump();
    expect(location(), AppRoutes.login);

    await session.signIn('u@x.com', 'pw');
    await tester.pump();
    await tester.pump();
    expect(location(), AppRoutes.home);
    expect(session.state, const SessionAuthenticated('u1'));
    await settle(tester);
  });

  testWidgets('signing out sends a protected screen back to login', (
    tester,
  ) async {
    when(() => auth.restoreSession()).thenAnswer((_) async => 'u1');
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.profile);
    await tester.pump();
    expect(location(), AppRoutes.profile);
    await session.signOut();
    await tester.pump();
    await tester.pump();
    expect(location(), AppRoutes.login);
    await settle(tester);
  });

  testWidgets('/gallery is a placeholder in debug and redirected in release', (
    tester,
  ) async {
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.gallery);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(location(), AppRoutes.gallery);
    expect(find.text('Widget gallery (F2)'), findsOneWidget);
    await settle(tester);
    router.dispose();
    // A new FinPayApp State is needed for the new router.
    await tester.pumpWidget(const SizedBox());

    await pump(tester, isDebug: false);
    router.go(AppRoutes.gallery);
    await tester.pump();
    expect(location(), AppRoutes.login);
    await settle(tester);
  });

  testWidgets('unknown path shows the not-found screen', (tester) async {
    await session.restore();
    await pump(tester);
    router.go('/nope');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No route defined for /nope'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('transfer review without a typed draft shows a guard screen', (
    tester,
  ) async {
    when(() => auth.restoreSession()).thenAnswer((_) async => 'u1');
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.transferReview, extra: {'amount': '420.90'});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Start a transfer from the home screen.'), findsOneWidget);
    const draft = TransferDraft(
      recipientName: 'Kelvin Habit',
      recipientAccount: 'kelvin@okaxis',
      amount: Money.paise(42090),
      idempotencyKey: 'k',
    );
    // A bare draft never renders a receipt (it could be a crafted extra).
    router.go(AppRoutes.transferSuccess, extra: draft);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Start a transfer from the home screen.'), findsOneWidget);
    router.go(
      AppRoutes.transferSuccess,
      extra: PaymentReceipt(
        draft: draft,
        reference: 'FPTEST000001',
        paidAt: DateTime.utc(2026, 10, 31),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Kelvin Habit'), findsWidgets);
    await settle(tester);
  });

  testWidgets('the page transition hook is used for every route', (
    tester,
  ) async {
    var calls = 0;
    AppPageTransitions.builder = <T>({required state, required child}) {
      calls++;
      return MaterialPage<T>(key: state.pageKey, child: child);
    };
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.login);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, greaterThanOrEqualTo(2));
    await settle(tester);
  });

  testWidgets('the default builder renders design-system transitions', (
    tester,
  ) async {
    AppPageTransitions.builder = AppPageTransitions.fp;
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.login);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SharedAxisTransition), findsWidgets);
    await settle(tester);
    router.go(AppRoutes.welcome);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FadeThroughTransition), findsWidgets);
    await settle(tester);
  });

  testWidgets('onboarding seen: /onboarding goes to login, and the router '
      'reacts when the flag flips', (tester) async {
    await session.restore();
    await pump(tester, withSettings: true);
    router.go(AppRoutes.onboarding);
    await tester.pump();
    expect(location(), AppRoutes.onboarding);
    await di.sl<SettingsCubit>().setOnboardingSeen(seen: true);
    await tester.pump();
    await tester.pump();
    expect(location(), AppRoutes.login);
    await settle(tester);
  });

  testWidgets('a pushed /verification without a sign-up shows the guard, and '
      'nothing travels in extra', (tester) async {
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.verification);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Start again'), findsOneWidget);
    expect(router.state.extra, isNull);
    await settle(tester);
  });

  testWidgets('fingerprint setup while signed out cannot reach home', (
    tester,
  ) async {
    await session.restore();
    await pump(tester);
    router.go(AppRoutes.fingerprintSetup);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(location(), AppRoutes.fingerprintSetup);
    await tester.tap(find.text('NOT NOW'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(location(), AppRoutes.login);
    await settle(tester);
  });
}
