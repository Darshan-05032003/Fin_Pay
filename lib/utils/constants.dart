/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'FinPay';
  static const String appVersion = '1.0.0';
  
  // API Endpoints (for future use)
  static const String baseUrl = 'https://api.finpay.com';
  
  // Storage Keys
  static const String keyUserId = 'user_id';
  static const String keyUserToken = 'user_token';
  static const String keyBiometricEnabled = 'biometric_enabled';
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Pagination
  static const int transactionsPerPage = 20;
  static const int notificationsPerPage = 10;
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 20;
  
  // Limits
  static const double minTransferAmount = 1;
  static const double maxTransferAmount = 100000;
  
  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
}

