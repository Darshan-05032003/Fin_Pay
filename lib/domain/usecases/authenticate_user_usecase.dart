import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';

/// Validates sign-in input and delegates to the [AuthRepository].
class AuthenticateUserUseCase {
  AuthenticateUserUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Longest password accepted before hashing; longer input is treated as
  /// wrong without doing 10k PBKDF2 rounds on it.
  static const int maxPasswordLength = 256;

  /// Longest email accepted.
  static const int maxEmailLength = 254;

  Future<AuthResult> call(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty ||
        password.isEmpty ||
        trimmedEmail.length > maxEmailLength ||
        password.length > maxPasswordLength) {
      return const AuthFailed(InvalidCredentials(remainingAttempts: -1));
    }
    return await _authRepository.signIn(
      email: trimmedEmail,
      password: password,
    );
  }
}
