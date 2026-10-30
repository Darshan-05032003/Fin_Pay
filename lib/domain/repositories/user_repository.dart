import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/models/user.dart';

/// Repository interface for the account holder.
abstract interface class IUserRepository {
  /// The stored user, or null before first run.
  Future<Result<User?>> getCurrentUser();

  /// Inserts or replaces the user.
  Future<Result<void>> saveUser(User user);

  /// Updates an existing user.
  Future<Result<void>> updateUser(User user);

  /// Removes the user row.
  Future<Result<void>> deleteUser();

  /// Sets the balance to an absolute value.
  Future<Result<void>> updateBalance(Money balance);
}
