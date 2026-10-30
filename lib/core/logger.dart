import 'package:flutter/foundation.dart';

/// Debug-only logger.
///
/// Every level is a no-op in release builds (`kReleaseMode`), and every
/// message passes through [redact] so card numbers, CVVs and passwords never
/// reach the console even in debug.
abstract final class Logger {
  /// Sink for output; overridable in tests. Defaults to [debugPrint].
  @visibleForTesting
  static void Function(String message) sink = (m) => debugPrint(m);

  /// Set in tests to exercise the release path without a release build.
  @visibleForTesting
  static bool forceSilent = false;

  static bool get _enabled => !kReleaseMode && !forceSilent;

  static void debug(String message, [Object? error, StackTrace? stackTrace]) =>
      _log('DEBUG', message, error, stackTrace);

  static void info(String message) => _log('INFO', message);

  static void warning(String message) => _log('WARNING', message);

  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log('ERROR', message, error, stackTrace);

  static void _log(
    String level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_enabled) return;
    sink('[$level] ${redact(message)}');
    if (error != null) sink('[$level DETAIL] ${redact(error.toString())}');
    if (stackTrace != null) sink('[STACK] $stackTrace');
  }

  /// Masks anything that looks like a card number (13–19 digits with
  /// optional spaces/dashes that pass the Luhn check), a CVV (`cvv: 123`),
  /// and password / PIN / OTP / token fields in `key: value`, `key=value`
  /// or JSON form. The last four digits of a PAN are kept.
  static String redact(String input) {
    var out = input.replaceAllMapped(_pan, (m) {
      final digits = m[0]!.replaceAll(RegExp(r'\D'), '');
      if (!passesLuhn(digits)) return m[0]!;
      return '**** **** **** ${digits.substring(digits.length - 4)}';
    });
    out = out.replaceAllMapped(_cvv, (m) => '${m[1]}***');
    out = out.replaceAllMapped(_credential, (m) => '${m[1]}[REDACTED]');
    return out;
  }

  /// Luhn checksum, used to tell card numbers from ids and timestamps.
  static bool passesLuhn(String digits) {
    var sum = 0;
    var doubleIt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 0x30;
      if (d < 0 || d > 9) return false;
      if (doubleIt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      doubleIt = !doubleIt;
    }
    return digits.isNotEmpty && sum % 10 == 0;
  }

  static final RegExp _pan = RegExp(r'\b(?:\d[ -]?){12,18}\d\b');
  static final RegExp _cvv = RegExp(
    r'(\bcvv2?\b["\x27]?\s*[:=]?\s*["\x27]?)\d{3,4}',
    caseSensitive: false,
  );
  static final RegExp _credential = RegExp(
    r'((?:password|passwd|pwd|pin|otp|token)\b["\x27]?\s*[:=]\s*)'
    r'(?:"[^"]*"|\x27[^\x27]*\x27|[^\s,}]+)',
    caseSensitive: false,
  );
}
