import 'package:flutter/foundation.dart';

/// Production-ready logger
class Logger {
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
      if (error != null) {
        debugPrint('[ERROR] $error');
      }
      if (stackTrace != null) {
        debugPrint('[STACK] $stackTrace');
      }
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARNING] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    if (error != null) {
      debugPrint('[ERROR DETAIL] $error');
    }
    if (stackTrace != null) {
      debugPrint('[STACK TRACE] $stackTrace');
    }
  }
}

