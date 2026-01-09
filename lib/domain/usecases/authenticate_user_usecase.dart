import '../../core/result/result.dart';
import '../../models/user.dart';
import '../../core/errors/app_exception.dart';
import '../repositories/user_repository.dart';

/// Use case for user authentication
class AuthenticateUserUseCase {
  final IUserRepository _userRepository;

  AuthenticateUserUseCase(this._userRepository);

  /// Execute the use case
  Future<Result<User>> call(String email, String password) async {
    // Validate input
    if (email.trim().isEmpty || password.isEmpty) {
      return const Failure('Email and password are required');
    }

    // Authenticate
    return await _userRepository.authenticate(email, password);
  }
}

