import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/routes/app_routes.dart';

/// The auth redirect, as a pure function so every route × session state can
/// be unit-tested without a widget tree.
abstract final class AppRedirect {
  /// Returns the path to redirect to, or null to let navigation proceed.
  ///
  /// * [SessionUnknown]: everything but the welcome splash goes to the
  ///   splash until the session is restored.
  /// * Signed out: protected routes (including `/cards/<id>`) go to the
  ///   login screen.
  /// * Signed in: guest-only routes go home.
  /// * [AppRoutes.gallery] exists only when [isDebug] is true.
  /// * [AppRoutes.onboarding] is skipped (→ login) once [onboardingSeen].
  /// * Unknown paths are left alone so the router's error page handles them.
  static String? resolve({
    required String location,
    required SessionState session,
    required bool isDebug,
    bool onboardingSeen = false,
  }) {
    final path = Uri.parse(location).path;
    final authenticated = session is SessionAuthenticated;

    if (session is SessionUnknown) {
      return path == AppRoutes.welcome ? null : AppRoutes.welcome;
    }

    if (path == AppRoutes.gallery) {
      if (isDebug) return null;
      return authenticated ? AppRoutes.home : AppRoutes.login;
    }

    if (AppRoutes.isProtected(path) && !authenticated) {
      return AppRoutes.login;
    }
    if (AppRoutes.guestOnly.contains(path) && authenticated) {
      return AppRoutes.home;
    }
    if (path == AppRoutes.onboarding && onboardingSeen) {
      return AppRoutes.login;
    }
    return null;
  }
}
