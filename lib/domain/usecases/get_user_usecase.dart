import '../../core/result/result.dart';
import '../../models/user.dart';
import '../repositories/user_repository.dart';

/// Use case for getting the current user
/// 
/// This follows the Clean Architecture principle where business logic
/// is separated from data sources and presentation.
class GetUserUseCase {
  final IUserRepository _userRepository;

  GetUserUseCase(this._userRepository);

  /// Execute the use case
  Future<Result<User?>> call() async {
    return await _userRepository.getCurrentUser();
  }
}

