import 'package:flutter/foundation.dart';
import '../../models/user.dart';
import '../../core/result/result.dart';
import '../../core/di/dependency_injection.dart';
import '../../domain/usecases/get_user_usecase.dart';
import '../../domain/usecases/update_user_usecase.dart';
import '../../domain/usecases/authenticate_user_usecase.dart';
import '../../core/logger.dart';

/// User provider for state management
/// 
/// This provider uses use cases to interact with the domain layer,
/// following Clean Architecture principles.
class UserProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Use cases
  final GetUserUseCase _getUserUseCase;
  final UpdateUserUseCase _updateUserUseCase;
  final AuthenticateUserUseCase _authenticateUserUseCase;

  UserProvider()
      : _getUserUseCase = DependencyInjection.get<GetUserUseCase>(),
        _updateUserUseCase = DependencyInjection.get<UpdateUserUseCase>(),
        _authenticateUserUseCase = DependencyInjection.get<AuthenticateUserUseCase>();

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get balance => _user?.balance ?? 0.0;
  String get userName => _user?.fullName ?? 'User';
  bool get isAuthenticated => _user != null;

  /// Load user from repository
  Future<void> loadUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _getUserUseCase();

    result
        .onSuccess((user) {
          _user = user;
          Logger.info('User loaded: ${user?.email ?? 'null'}');
        })
        .onFailure((message, error) {
          _errorMessage = message;
          Logger.error('Failed to load user: $message', error);
        });

    _isLoading = false;
    notifyListeners();
  }

  /// Update user information
  Future<Result<void>> updateUser(User user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _updateUserUseCase(user);

    result
        .onSuccess((_) {
          _user = user;
          Logger.info('User updated successfully');
        })
        .onFailure((message, error) {
          _errorMessage = message;
          Logger.error('Failed to update user: $message', error);
        });

    _isLoading = false;
    notifyListeners();

    return result;
  }

  /// Update user balance
  Future<void> updateBalance(double newBalance) async {
    if (_user != null) {
      final updatedUser = _user!.copyWith(balance: newBalance);
      await updateUser(updatedUser);
    }
  }

  /// Authenticate user
  Future<Result<User>> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authenticateUserUseCase(email, password);

    result
        .onSuccess((user) {
          _user = user;
          Logger.info('User authenticated: ${user.email}');
        })
        .onFailure((message, error) {
          _errorMessage = message;
          Logger.error('Authentication failed: $message', error);
        });

    _isLoading = false;
    notifyListeners();

    return result;
  }

  /// Logout user
  Future<void> logout() async {
    _user = null;
    _errorMessage = null;
    notifyListeners();
    Logger.info('User logged out');
  }
}

