import '../../core/result/result.dart';
import '../../models/user.dart';
import '../repositories/user_repository.dart';

/// Use case for updating user information
class UpdateUserUseCase {
  final IUserRepository _userRepository;

  UpdateUserUseCase(this._userRepository);

  /// Execute the use case
  Future<Result<void>> call(User user) async {
    // Add validation logic here if needed
    return await _userRepository.updateUser(user);
  }
}

