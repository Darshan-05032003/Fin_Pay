import '../models/user.dart';
import '../services/database_service.dart';
import '../core/logger.dart';

/// Repository pattern for user data management
class UserRepository {
  final DatabaseService _db = DatabaseService();

  Future<User?> getUser() async {
    try {
      return await _db.getUser();
    } catch (e) {
      Logger.error('Failed to get user', e);
      return null;
    }
  }

  Future<void> saveUser(User user) async {
    try {
      await _db.insertUser(user);
      Logger.info('User saved successfully');
    } catch (e) {
      Logger.error('Failed to save user', e);
      rethrow;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _db.updateUser(user);
      Logger.info('User updated successfully');
    } catch (e) {
      Logger.error('Failed to update user', e);
      rethrow;
    }
  }

  Future<void> deleteUser() async {
    try {
      await _db.deleteUser();
      Logger.info('User deleted successfully');
    } catch (e) {
      Logger.error('Failed to delete user', e);
      rethrow;
    }
  }
}

