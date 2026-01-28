import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';

/// Use case for user authentication
class AuthenticateUserUseCase {

  AuthenticateUserUseCase(this._userRepository);
  final IUserRepository _userRepository;

  /// Execute the use case
  Future<Result<User>> call(String email, String password) async {
    // Validate input
    if (email.trim().isEmpty || password.isEmpty) {
      return const Failure('Email and password are required');
    }

    // Authenticate
    return _userRepository.authenticate(email, password);
  }
}

