import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  late AuthenticateUserUseCase useCase;
  final user = User(
    id: 'u',
    fullName: 'U',
    email: 'u@x.com',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    repo = MockAuthRepository();
    useCase = AuthenticateUserUseCase(repo);
    when(
      () => repo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => AuthSuccess(user));
  });

  test(
    'rejects empty email or password without touching the repository',
    () async {
      expect(await useCase('', 'pw'), isA<AuthFailed>());
      expect(await useCase('   ', 'pw'), isA<AuthFailed>());
      expect(await useCase('u@x.com', ''), isA<AuthFailed>());
      verifyNever(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  test('rejects oversized input before hashing', () async {
    expect(await useCase('u@x.com', 'p' * 257), isA<AuthFailed>());
    expect(await useCase('${'u' * 250}@x.com', 'pw'), isA<AuthFailed>());
    verifyNever(
      () => repo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('trims the email and forwards the password untouched', () async {
    final result = await useCase('  u@x.com ', ' pw ');
    expect(result, AuthSuccess(user));
    verify(() => repo.signIn(email: 'u@x.com', password: ' pw ')).called(1);
  });

  test('passes repository failures through', () async {
    when(
      () => repo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const AuthFailed(InvalidCredentials(remainingAttempts: 2)),
    );
    expect(
      await useCase('u@x.com', 'pw'),
      const AuthFailed(InvalidCredentials(remainingAttempts: 2)),
    );
  });
}
