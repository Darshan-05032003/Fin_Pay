import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/screens/auth/login/login_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticate extends Mock implements AuthenticateUserUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthenticate authenticate;
  late SessionCubit session;
  final user = User(
    id: 'u1',
    fullName: 'U',
    email: 'user@finpay.com',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    Logger.sink = (_) {};
    authenticate = MockAuthenticate();
    session = SessionCubit(
      authenticate: authenticate,
      authRepository: MockAuthRepository(),
    );
  });

  tearDown(() => session.close());

  LoginCubit build() => LoginCubit(session: session);

  test('initial state: empty, idle, nothing to show', () {
    final cubit = build();
    expect(cubit.state, const LoginState());
    expect(cubit.state.canSubmit, isTrue);
    expect(cubit.state.isLocked, isFalse);
    expect(cubit.state.message, isNull);
    unawaited(cubit.close());
  });

  blocTest<LoginCubit, LoginState>(
    'submit validates both fields before touching the session',
    build: build,
    act: (c) => c.submit(),
    expect: () => const [
      LoginState(
        submitted: true,
        emailError: 'Email is required',
        passwordError: 'Password is required',
      ),
    ],
    verify: (_) => verifyNever(() => authenticate(any(), any())),
  );

  blocTest<LoginCubit, LoginState>(
    'errors are live only after the first submit',
    build: build,
    act: (c) {
      c.emailChanged('nope');
      unawaited(c.submit());
      c
        ..emailChanged('user@finpay.com')
        ..passwordChanged('FinPay123');
    },
    expect: () => const [
      LoginState(email: 'nope'),
      LoginState(
        email: 'nope',
        submitted: true,
        emailError: 'Enter a valid email address',
        passwordError: 'Password is required',
      ),
      LoginState(
        email: 'user@finpay.com',
        submitted: true,
        passwordError: 'Password is required',
      ),
      LoginState(email: 'user@finpay.com', submitted: true),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'successful sign-in: submitting → success, session authenticated',
    build: () {
      when(
        () => authenticate('user@finpay.com', 'FinPay123'),
      ).thenAnswer((_) async => AuthSuccess(user));
      return build();
    },
    act: (c) async {
      c
        ..emailChanged('user@finpay.com')
        ..passwordChanged('FinPay123');
      await c.submit();
    },
    expect: () => const [
      LoginState(email: 'user@finpay.com'),
      LoginState(
        email: 'user@finpay.com',
        submitted: true,
        status: LoginStatus.submitting,
      ),
      LoginState(
        email: 'user@finpay.com',
        submitted: true,
        status: LoginStatus.success,
      ),
    ],
    verify: (_) {
      expect(session.state, const SessionAuthenticated('u1'));
      verify(() => authenticate('user@finpay.com', 'FinPay123')).called(1);
    },
  );

  blocTest<LoginCubit, LoginState>(
    'wrong credentials surface the typed failure inline',
    build: () {
      when(() => authenticate(any(), any())).thenAnswer(
        (_) async => const AuthFailed(InvalidCredentials(remainingAttempts: 3)),
      );
      return build();
    },
    act: (c) async {
      c
        ..emailChanged('user@finpay.com')
        ..passwordChanged('wrongpass');
      await c.submit();
    },
    skip: 2,
    expect: () => const [
      LoginState(
        email: 'user@finpay.com',
        submitted: true,
        status: LoginStatus.failure,
        failure: InvalidCredentials(remainingAttempts: 3),
        failures: 1,
      ),
    ],
    verify: (c) {
      expect(c.state.message, contains('3 attempts left'));
      expect(c.state.canSubmit, isTrue);
    },
  );

  blocTest<LoginCubit, LoginState>(
    'a storage failure is distinguishable from wrong credentials',
    build: () {
      when(() => authenticate(any(), any())).thenAnswer(
        (_) async => const AuthFailed(CredentialStoreUnavailable('keystore')),
      );
      return build();
    },
    act: (c) async {
      c
        ..emailChanged('user@finpay.com')
        ..passwordChanged('FinPay123');
      await c.submit();
    },
    verify: (c) {
      expect(c.state.failure, isA<CredentialStoreUnavailable>());
      expect(
        c.state.message,
        'Could not check your credentials. Please try again.',
      );
    },
  );

  test('lockout shows a live countdown and re-enables when it ends', () {
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2026));
      when(() => authenticate(any(), any())).thenAnswer(
        (_) async => AuthFailed(
          AccountLocked(
            until: clock.now().add(const Duration(seconds: 30)),
            remaining: const Duration(seconds: 30),
          ),
        ),
      );
      final cubit = LoginCubit(session: session, clock: clock)
        ..emailChanged('user@finpay.com')
        ..passwordChanged('x' * 8);
      unawaited(cubit.submit());
      async.flushMicrotasks();
      expect(cubit.state.status, LoginStatus.failure);
      expect(cubit.state.isLocked, isTrue);
      expect(cubit.state.canSubmit, isFalse);
      expect(cubit.state.message, 'Too many attempts. Try again in 30 s.');
      async.elapse(const Duration(seconds: 12));
      expect(cubit.state.message, 'Too many attempts. Try again in 18 s.');
      // A submit while locked never reaches the use case.
      unawaited(cubit.submit());
      async.flushMicrotasks();
      verify(() => authenticate(any(), any())).called(1);
      async.elapse(const Duration(seconds: 18));
      expect(cubit.state.isLocked, isFalse);
      expect(cubit.state.canSubmit, isTrue);
      expect(cubit.state.message, isNull);
      expect(cubit.state.status, LoginStatus.idle);
      unawaited(cubit.close());
      async.flushTimers();
    });
  });

  test('a clock jump backwards cannot extend the lockout', () {
    fakeAsync((async) {
      var offset = Duration.zero;
      final base = async.getClock(DateTime.utc(2026));
      final clock = Clock(() => base.now().add(offset));
      when(() => authenticate(any(), any())).thenAnswer(
        (_) async => AuthFailed(
          AccountLocked(
            until: clock.now().add(const Duration(seconds: 30)),
            remaining: const Duration(seconds: 30),
          ),
        ),
      );
      final cubit = LoginCubit(session: session, clock: clock)
        ..emailChanged('user@finpay.com')
        ..passwordChanged('x' * 8);
      unawaited(cubit.submit());
      async.flushMicrotasks();
      offset = const Duration(hours: -1);
      async.elapse(const Duration(seconds: 1));
      expect(
        cubit.state.lockRemaining,
        lessThanOrEqualTo(const Duration(seconds: 30)),
      );
      unawaited(cubit.close());
      async.flushTimers();
    });
  });

  test('1,000 submits while one is in flight call authenticate once', () async {
    final gate = Completer<AuthResult>();
    when(() => authenticate(any(), any())).thenAnswer((_) => gate.future);
    final cubit = build()
      ..emailChanged('user@finpay.com')
      ..passwordChanged('FinPay123');
    final futures = <Future<void>>[];
    for (var i = 0; i < 1000; i++) {
      futures.add(cubit.submit());
    }
    gate.complete(AuthSuccess(user));
    await Future.wait(futures);
    verify(() => authenticate(any(), any())).called(1);
    expect(cubit.state.status, LoginStatus.success);
    await cubit.close();
  });

  blocTest<LoginCubit, LoginState>(
    'password visibility toggles and can be forced hidden (backgrounding)',
    build: build,
    act: (c) {
      c
        ..togglePasswordVisibility()
        ..hidePassword()
        ..hidePassword();
    },
    expect: () => const [LoginState(showPassword: true), LoginState()],
  );

  test('the password never appears in the state', () {
    final cubit = build()..passwordChanged('S3cret!pw');
    expect(cubit.state.toString(), isNot(contains('S3cret')));
    expect(cubit.state.props.join(), isNot(contains('S3cret')));
    unawaited(cubit.close());
  });

  test('hostile input does not throw', () async {
    final cubit = build()
      ..emailChanged('\u202E' * 5000)
      ..passwordChanged('😀' * 5000)
      ..emailChanged("' OR 1=1 --")
      ..passwordChanged('%s%n');
    await cubit.submit();
    expect(cubit.state.emailError, isNotNull);
    verifyNever(() => authenticate(any(), any()));
    await cubit.close();
  });
}
