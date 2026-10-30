import 'package:fin_pay/utils/constants.dart';
import 'package:intl/intl.dart';

/// Helper utility functions
class Helpers {
  /// Format currency
  static String formatCurrency(double amount) {
    return NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(amount);
  }

  /// Format date
  static String formatDate(DateTime date) {
    return DateFormat(AppConstants.dateFormat).format(date);
  }

  /// Format time
  static String formatTime(DateTime date) {
    return DateFormat(AppConstants.timeFormat).format(date);
  }

  /// Format date and time
  static String formatDateTime(DateTime date) {
    return DateFormat(AppConstants.dateTimeFormat).format(date);
  }

  /// Get relative time (e.g., "2 hours ago")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Mask card number
  static String maskCardNumber(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;
    final last4 = cardNumber.substring(cardNumber.length - 4);
    return '**** **** **** $last4';
  }

  /// Mask account number
  static String maskAccountNumber(String accountNumber) {
    if (accountNumber.length < 4) return accountNumber;
    final last4 = accountNumber.substring(accountNumber.length - 4);
    return '****$last4';
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate phone format
  static bool isValidPhone(String phone) {
    return RegExp(
      r'^[0-9]{10}$',
    ).hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }
}
