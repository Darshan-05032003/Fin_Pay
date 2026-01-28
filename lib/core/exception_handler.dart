import 'package:fin_pay/core/error_handler.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:flutter/material.dart';

/// Exception handling for the app
class ExceptionHandler {
  static void handleException(BuildContext? context, dynamic exception, [StackTrace? stackTrace]) {
    Logger.error('Exception occurred', exception, stackTrace);
    
    if (context != null) {
      var message = 'An error occurred. Please try again.';
      
      if (exception is FormatException) {
        message = 'Invalid data format. Please check your input.';
      } else if (exception is Exception) {
        message = exception.toString().replaceAll('Exception: ', '');
      }
      
      ErrorHandler.showError(context, message);
    }
  }
}

