import '../services/user_service.dart';

/// Route guard for authentication
class RouteGuard {
  static Future<bool> isAuthenticated() async {
    final user = await UserService.getCurrentUser();
    return user != null;
  }

  static Future<String> getInitialRoute() async {
    final isAuth = await isAuthenticated();
    return isAuth ? '/home' : '/';
  }
}

