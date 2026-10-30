import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';

/// [IUserRepository] over the local data source.
class UserRepositoryImpl implements IUserRepository {
  UserRepositoryImpl(this._localDataSource);

  final LocalDataSource _localDataSource;

  @override
  Future<Result<User?>> getCurrentUser() => _localDataSource.getUser();

  @override
  Future<Result<void>> saveUser(User user) => _localDataSource.saveUser(user);

  @override
  Future<Result<void>> updateUser(User user) =>
      _localDataSource.updateUser(user);

  @override
  Future<Result<void>> deleteUser() => _localDataSource.deleteUser();

  @override
  Future<Result<void>> updateBalance(Money balance) async {
    final userResult = await getCurrentUser();
    return await userResult.flatMapAsync((user) async {
      if (user == null) return const Failure('No user found');
      return await updateUser(user.copyWith(balance: balance));
    });
  }
}
