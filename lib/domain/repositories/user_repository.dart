import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/models/user.dart';

/// Repository interface for user operations
/// 
/// This follows the Repository pattern, providing an abstraction
/// over data sources and allowing for easy testing and swapping
/// of implementations.
abstract class IUserRepository {
  /// Get current user
  Future<Result<User?>> getCurrentUser();
  
  /// Save user
  Future<Result<void>> saveUser(User user);
  
  /// Update user
  Future<Result<void>> updateUser(User user);
  
  /// Delete user (logout)
  Future<Result<void>> deleteUser();
  
  /// Update user balance
  Future<Result<void>> updateBalance(double balance);
  
  /// Authenticate user
  Future<Result<User>> authenticate(String email, String password);
}

