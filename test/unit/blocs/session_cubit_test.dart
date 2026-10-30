import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticate extends Mock implements AuthenticateUserUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthenticate authenticate;
  late MockAuthRepository authRepository;
  late List<SessionEffect> effects;
  final user = User(
    id: 'u1',
    fullName: 'U',
    email: 'u@x.com',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    Logger.sink = (_) {};
    authenticate = MockAuthenticate();
    authRepository = MockAuthRepository();
    effects = [];
    when(() => authRepository.signOut()).thenAnswer((_) async {});
  });

  SessionCubit build() {
    final cubit = SessionCubit(
      authenticate: authenticate,
      authRepository: authRepository,
    );
    cubit.effects.listen(effects.add);
    return cubit;
  }

  test('starts unknown', () async {
    final cubit = build();
    expect(cubit.state, const SessionUnknown());
    expect(cubit.isAuthenticated, isFalse);
    await cubit.close();
  });

  blocTest<SessionCubit, SessionState>(
    'restore: authenticated when a session exists',
    build: () {
      when(() => authRepository.restoreSession()).thenAnswer((_) async => 'u1');
      return build();
    },
    act: (c) => c.restore(),
    expect: () => [const SessionAuthenticated('u1')],
    verify: (c) => expect(c.isAuthenticated, isTrue),
  );

  blocTest<SessionCubit, SessionState>(
    'restore: unauthenticated otherwise',
    build: () {
      when(() => authRepository.restoreSession()).thenAnswer((_) async => null);
      return build();
    },
    act: (c) => c.restore(),
    expect: () => [const SessionUnauthenticated()],
  );

  blocTest<SessionCubit, SessionState>(
    'signIn success: authenticating → authenticated + SignedIn effect',
    build: () {
      when(
        () => authenticate('u@x.com', 'pw'),
      ).thenAnswer((_) async => AuthSuccess(user));
      return build();
    },
    act: (c) => c.signIn('u@x.com', 'pw'),
    expect: () => [
      const SessionAuthenticating(),
      const SessionAuthenticated('u1'),
    ],
    verify: (_) => expect(effects, [SignedIn(user)]),
  );

  blocTest<SessionCubit, SessionState>(
    'signIn failure: unauthenticated with the failure + effect',
    build: () {
      when(() => authenticate('u@x.com', 'pw')).thenAnswer(
        (_) async => const AuthFailed(InvalidCredentials(remainingAttempts: 3)),
      );
      return build();
    },
    act: (c) => c.signIn('u@x.com', 'pw'),
    expect: () => [
      const SessionAuthenticating(),
      const SessionUnauthenticated(
        failure: InvalidCredentials(remainingAttempts: 3),
      ),
    ],
    verify: (_) => expect(effects, [
      const SignInFailed(InvalidCredentials(remainingAttempts: 3)),
    ]),
  );

  blocTest<SessionCubit, SessionState>(
    'a second signIn while one is in flight is ignored (double tap)',
    build: () {
      when(() => authenticate('u@x.com', 'pw')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return AuthSuccess(user);
      });
      return build();
    },
    act: (c) async {
      final first = c.signIn('u@x.com', 'pw');
      await c.signIn('u@x.com', 'pw');
      await first;
    },
    expect: () => [
      const SessionAuthenticating(),
      const SessionAuthenticated('u1'),
    ],
    verify: (_) {
      verify(() => authenticate('u@x.com', 'pw')).called(1);
      expect(effects, hasLength(1));
    },
  );

  blocTest<SessionCubit, SessionState>(
    'signOut clears the session and emits SignedOut',
    build: () {
      when(() => authRepository.restoreSession()).thenAnswer((_) async => 'u1');
      return build();
    },
    act: (c) async {
      await c.restore();
      await c.signOut();
    },
    expect: () => [
      const SessionAuthenticated('u1'),
      const SessionUnauthenticated(),
    ],
    verify: (_) {
      verify(() => authRepository.signOut()).called(1);
      expect(effects, [const SignedOut()]);
    },
  );

  test('locked-out failure carries the time left', () {
    final failure = AccountLocked(
      until: DateTime.utc(2026),
      remaining: const Duration(seconds: 12),
    );
    expect(failure.message, contains('12 s'));
    expect(
      const InvalidCredentials(remainingAttempts: 1).message,
      contains('1 attempt left'),
    );
    expect(
      const InvalidCredentials(remainingAttempts: 0).message,
      isNot(contains('left')),
    );
    expect(const CredentialStoreUnavailable('x').message, isNotEmpty);
  });
}
