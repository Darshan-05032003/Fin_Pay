import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/services/user_service.dart';

/// Implementation of IUserRepository
class UserRepositoryImpl implements IUserRepository {

  UserRepositoryImpl(this._localDataSource);
  final LocalDataSource _localDataSource;

  @override
  Future<Result<User?>> getCurrentUser() async {
    return _localDataSource.getUser();
  }

  @override
  Future<Result<void>> saveUser(User user) async {
    return _localDataSource.saveUser(user);
  }

  @override
  Future<Result<void>> updateUser(User user) async {
    return _localDataSource.updateUser(user);
  }

  @override
  Future<Result<void>> deleteUser() async {
    return _localDataSource.deleteUser();
  }

  @override
  Future<Result<void>> updateBalance(double balance) async {
    final userResult = await getCurrentUser();
    return userResult.flatMapAsync((user) async {
      if (user == null) {
        return const Failure('No user found');
      }
      final updatedUser = user.copyWith(balance: balance);
      return updateUser(updatedUser);
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

