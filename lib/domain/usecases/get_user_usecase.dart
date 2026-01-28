import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';

/// Use case for getting the current user
/// 
/// This follows the Clean Architecture principle where business logic
/// is separated from data sources and presentation.
class GetUserUseCase {

  GetUserUseCase(this._userRepository);
  final IUserRepository _userRepository;

  /// Execute the use case
  Future<Result<User?>> call() async {
    return _userRepository.getCurrentUser();
  }
}

