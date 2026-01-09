import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final DatabaseService _db = DatabaseService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  double get balance => _user?.balance ?? 0.0;
  String get userName => _user?.fullName ?? 'User';

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _db.getUser();
      if (_user == null) {
        // Initialize default user if none exists
        await UserService.init();
        _user = await _db.getUser();
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _db.updateUser(user);
      _user = user;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating user: $e');
    }
  }

  Future<void> updateBalance(double newBalance) async {
    if (_user != null) {
      final updatedUser = _user!.copyWith(balance: newBalance);
      await updateUser(updatedUser);
    }
  }

  Future<void> logout() async {
    _user = null;
    notifyListeners();
  }
}

