import '../../models/user.dart';
import '../../core/result/result.dart';
import '../../core/errors/app_exception.dart';
import '../../data/datasources/local_datasource.dart';
import '../../services/user_service.dart';
import 'user_repository.dart';

/// Implementation of IUserRepository
class UserRepositoryImpl implements IUserRepository {
  final LocalDataSource _localDataSource;

  UserRepositoryImpl(this._localDataSource);

  @override
  Future<Result<User?>> getCurrentUser() async {
    return await _localDataSource.getUser();
  }

  @override
  Future<Result<void>> saveUser(User user) async {
    return await _localDataSource.saveUser(user);
  }

  @override
  Future<Result<void>> updateUser(User user) async {
    return await _localDataSource.updateUser(user);
  }

  @override
  Future<Result<void>> deleteUser() async {
    return await _localDataSource.deleteUser();
  }

  @override
  Future<Result<void>> updateBalance(double balance) async {
    final userResult = await getCurrentUser();
    return await userResult.flatMapAsync((user) async {
      if (user == null) {
        return const Failure('No user found');
      }
      final updatedUser = user.copyWith(balance: balance);
      return await updateUser(updatedUser);
    });
  }

  @override
  Future<Result<User>> authenticate(String email, String password) async {
    // Only allow default credentials for now
    if (email.trim().toLowerCase() == UserService.defaultEmail.toLowerCase() &&
        password == UserService.defaultPassword) {
      // Ensure default user exists
      await UserService.init();
      final userResult = await getCurrentUser();
      return userResult.flatMap((user) {
        if (user == null) {
          return const Failure('User not found');
        }
        return Success(user);
      });
    }
    return const Failure('Invalid credentials');
  }
}

