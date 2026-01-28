import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';

/// Use case for updating user information
class UpdateUserUseCase {

  UpdateUserUseCase(this._userRepository);
  final IUserRepository _userRepository;

  /// Execute the use case
  Future<Result<void>> call(User user) async {
    // Add validation logic here if needed
    return _userRepository.updateUser(user);
  }
}

