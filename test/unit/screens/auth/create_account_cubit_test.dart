import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/auth/demo_credentials.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/screens/auth/create_account/create_account_cubit.dart';
import 'package:fin_pay/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticate extends Mock implements AuthenticateUserUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUsers extends Mock implements IUserRepository {}

class FakeUser extends Fake implements User {}

void main() {
  late MockAuthenticate authenticate;
  late MockAuthRepository auth;
  late MockUsers users;
  late SessionCubit session;
  final clock = Clock.fixed(DateTime.utc(2026, 10, 31));
  final demo = User(
    id: DemoCredentials.userId,
    fullName: DemoCredentials.fullName,
    email: DemoCredentials.email,
    balance: DemoCredentials.openingBalance,
    createdAt: DateTime.utc(2026),
  );

  setUpAll(() => registerFallbackValue(FakeUser()));

  setUp(() {
    Logger.sink = (_) {};
    authenticate = MockAuthenticate();
    auth = MockAuthRepository();
    users = MockUsers();
    session = SessionCubit(authenticate: authenticate, authRepository: auth);
    when(
      () => auth.setCredentials(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => users.updateUser(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => users.saveUser(any()),
    ).thenAnswer((_) async => const Success(null));
  });

  tearDown(() => session.close());

  CreateAccountCubit build() => CreateAccountCubit(
    auth: auth,
    users: users,
    session: session,
    clock: clock,
  );

  void fill(CreateAccountCubit c) {
    c
      ..nameChanged('Aarav Mehta')
      ..emailChanged('aarav@example.com')
      ..phoneChanged('+91 98765 43210')
      ..passwordChanged('Str0ng!pass');
  }

  test('initial state', () {
    final cubit = build();
    expect(cubit.state, const CreateAccountState());
    expect(cubit.state.strength, PasswordStrength.none);
    expect(cubit.expectedOtp, isEmpty);
    unawaited(cubit.close());
  });

  blocTest<CreateAccountCubit, CreateAccountState>(
    'submit validates every field and reports strength',
    build: build,
    act: (c) {
      c
        ..passwordChanged('abc')
        ..submit();
    },
    expect: () => const [
      CreateAccountState(strength: PasswordStrength.weak),
      CreateAccountState(
        strength: PasswordStrength.weak,
        submitted: true,
        nameError: 'Name is required',
        emailError: 'Email is required',
        phoneError: 'Phone number is required',
        passwordError: 'Use at least 8 characters',
      ),
    ],
  );

  blocTest<CreateAccountCubit, CreateAccountState>(
    'valid input moves to pending verification; OTP is derived locally',
    build: build,
    act: (c) {
      fill(c);
      c.submit();
    },
    skip: 4,
    expect: () => const [
      CreateAccountState(
        name: 'Aarav Mehta',
        email: 'aarav@example.com',
        phone: '9876543210',
        strength: PasswordStrength.strong,
        submitted: true,
        status: CreateAccountStatus.pendingVerification,
      ),
    ],
    verify: (c) {
      expect(c.expectedOtp, '543210');
      expect(CreateAccountCubit.otpFor('9876543210'), '543210');
      expect(c.state.maskedPhone, '+91 ••••• •3210');
    },
  );

  blocTest<CreateAccountCubit, CreateAccountState>(
    'completeSignUp re-keys the on-device account and signs in',
    build: () {
      when(() => users.getCurrentUser()).thenAnswer((_) async => Success(demo));
      when(() => authenticate('aarav@example.com', 'Str0ng!pass')).thenAnswer(
        (_) async => AuthSuccess(demo.copyWith(email: 'aarav@example.com')),
      );
      return build();
    },
    act: (c) async {
      fill(c);
      c.submit();
      await c.completeSignUp();
    },
    skip: 5,
    expect: () => const [
      CreateAccountState(
        name: 'Aarav Mehta',
        email: 'aarav@example.com',
        phone: '9876543210',
        strength: PasswordStrength.strong,
        submitted: true,
        status: CreateAccountStatus.completing,
      ),
      CreateAccountState(
        name: 'Aarav Mehta',
        email: 'aarav@example.com',
        phone: '9876543210',
        strength: PasswordStrength.strong,
        submitted: true,
        status: CreateAccountStatus.completed,
      ),
    ],
    verify: (_) {
      verify(
        () => auth.setCredentials(
          email: 'aarav@example.com',
          password: 'Str0ng!pass',
        ),
      ).called(1);
      final saved =
          verify(() => users.updateUser(captureAny())).captured.single as User;
      expect(saved.id, DemoCredentials.userId);
      expect(saved.fullName, 'Aarav Mehta');
      expect(saved.email, 'aarav@example.com');
      expect(saved.phone, '9876543210');
      expect(saved.balance, DemoCredentials.openingBalance);
      verifyNever(() => users.saveUser(any()));
      expect(session.state, isA<SessionAuthenticated>());
    },
  );

  blocTest<CreateAccountCubit, CreateAccountState>(
    'completeSignUp creates the account row when the device has none',
    build: () {
      when(
        () => users.getCurrentUser(),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => authenticate(any(), any()),
      ).thenAnswer((_) async => AuthSuccess(demo));
      return build();
    },
    act: (c) async {
      fill(c);
      c.submit();
      await c.completeSignUp();
    },
    verify: (c) {
      final saved =
          verify(() => users.saveUser(captureAny())).captured.single as User;
      expect(saved.email, 'aarav@example.com');
      expect(saved.createdAt, clock.now());
      expect(saved.balance, DemoCredentials.openingBalance);
      expect(c.state.status, CreateAccountStatus.completed);
    },
  );

  blocTest<CreateAccountCubit, CreateAccountState>(
    'a storage failure is reported and the flow can retry',
    build: () {
      when(
        () => auth.setCredentials(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Failure('Could not store credentials'));
      return build();
    },
    act: (c) async {
      fill(c);
      c.submit();
      await c.completeSignUp();
    },
    verify: (c) {
      expect(c.state.status, CreateAccountStatus.failed);
      expect(c.state.errorMessage, 'Could not store credentials');
      verifyNever(() => users.getCurrentUser());
      verifyNever(() => authenticate(any(), any()));
    },
  );

  blocTest<CreateAccountCubit, CreateAccountState>(
    'a sign-in failure after saving is reported',
    build: () {
      when(() => users.getCurrentUser()).thenAnswer((_) async => Success(demo));
      when(() => authenticate(any(), any())).thenAnswer(
        (_) async => const AuthFailed(CredentialStoreUnavailable('x')),
      );
      return build();
    },
    act: (c) async {
      fill(c);
      c.submit();
      await c.completeSignUp();
    },
    verify: (c) {
      expect(c.state.status, CreateAccountStatus.failed);
      expect(c.state.errorMessage, isNotEmpty);
    },
  );

  test('completeSignUp is ignored unless verification is pending', () async {
    final cubit = build();
    await cubit.completeSignUp();
    expect(cubit.state.status, CreateAccountStatus.editing);
    verifyNever(
      () => auth.setCredentials(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
    await cubit.close();
  });

  test('concurrent completeSignUp calls store credentials once', () async {
    when(() => users.getCurrentUser()).thenAnswer((_) async => Success(demo));
    when(
      () => authenticate(any(), any()),
    ).thenAnswer((_) async => AuthSuccess(demo));
    final cubit = build();
    fill(cubit);
    cubit.submit();
    await Future.wait([
      cubit.completeSignUp(),
      cubit.completeSignUp(),
      cubit.completeSignUp(),
    ]);
    verify(
      () => auth.setCredentials(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);
    await cubit.close();
  });

  test('the password never appears in the state; the OTP is not a field', () {
    final cubit = build();
    fill(cubit);
    cubit.submit();
    final dump = '${cubit.state}${cubit.state.props.join()}';
    expect(dump, isNot(contains('Str0ng')));
    // The phone number is shown (masked) to the user, so its digits are in
    // the state; the derived code must never be a field of its own.
    expect(cubit.state.props, isNot(contains(cubit.expectedOtp)));
    unawaited(cubit.close());
  });

  test('edit after pending verification returns to editing', () {
    final cubit = build();
    fill(cubit);
    cubit.submit();
    expect(cubit.state.status, CreateAccountStatus.pendingVerification);
    cubit.phoneChanged('9000000000');
    expect(cubit.state.status, CreateAccountStatus.editing);
    expect(cubit.expectedOtp, isEmpty);
    unawaited(cubit.close());
  });

  blocTest<CreateAccountCubit, CreateAccountState>(
    'password visibility toggles and can be forced hidden',
    build: build,
    act: (c) {
      c
        ..togglePasswordVisibility()
        ..hidePassword();
    },
    expect: () => const [
      CreateAccountState(showPassword: true),
      CreateAccountState(),
    ],
  );
}
