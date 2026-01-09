import 'package:flutter/foundation.dart';

/// App configuration based on environment
class AppConfig {
  static const bool isProduction = kReleaseMode;
  static const bool isDevelopment = kDebugMode;
  
  // API Configuration
  static String get apiBaseUrl {
    if (isProduction) {
      return 'https://api.finpay.com';
    } else {
      return 'https://api-dev.finpay.com';
    }
  }
  
  // Feature Flags
  static const bool enableBiometric = true;
  static const bool enableNotifications = true;
  static const bool enableAnalytics = true;
  
  // App Settings
  static const int sessionTimeoutMinutes = 30;
  static const int maxRetryAttempts = 3;
}

