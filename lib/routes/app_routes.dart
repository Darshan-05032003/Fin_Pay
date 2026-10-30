/// Every route path in the app, plus the sets the auth redirect uses.
abstract final class AppRoutes {
  static const String welcome = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String createAccount = '/create-account';
  static const String verification = '/verification';
  static const String fingerprintSetup = '/fingerprint-setup';
  static const String passwordReset = '/forgot-password';
  static const String home = '/home';
  static const String transactions = '/transactions';
  static const String transfer = '/transfer';
  static const String transferReview = '/transfer-review';
  static const String transferSuccess = '/transfer-success';
  static const String cards = '/cards';
  static const String addCard = '/add-card';
  static const String profile = '/profile';
  static const String statistics = '/statistics';
  static const String notifications = '/notifications';

  /// Debug-only widget gallery (owned by the design system).
  static const String gallery = '/gallery';

  /// Reachable only while signed out; a signed-in user is sent [home].
  static const Set<String> guestOnly = {
    welcome,
    onboarding,
    login,
    createAccount,
    passwordReset,
  };

  /// Reachable in either state (mid sign-up steps).
  static const Set<String> neutral = {verification, fingerprintSetup};

  /// Require a session; a signed-out user is sent to [login].
  static const Set<String> protected = {
    home,
    transactions,
    transfer,
    transferReview,
    transferSuccess,
    cards,
    addCard,
    profile,
    statistics,
    notifications,
  };

  /// Every known path.
  static const Set<String> all = {
    ...guestOnly,
    ...neutral,
    ...protected,
    gallery,
  };

  /// The four bottom-navigation roots.
  static const List<String> tabs = [home, statistics, cards, profile];
}
