/// How strong a password is, from [none] (empty) to [strong].
enum PasswordStrength {
  none(0, 'Too short'),
  weak(1, 'Weak'),
  fair(2, 'Fair'),
  good(3, 'Good'),
  strong(4, 'Strong');

  const PasswordStrength(this.score, this.label);

  /// 0 (empty) to 4 (strong), for meters.
  final int score;

  /// Short user-facing label.
  final String label;
}

/// Input validation for the auth forms. Every function returns a
/// user-facing message, or null when the value is acceptable.
///
/// Rules are deliberately strict about what can change meaning (control
/// and bidi characters, injection punctuation) and tolerant about harmless
/// formatting (surrounding whitespace, phone separators).
abstract final class Validators {
  /// Longest email accepted (RFC 5321 path limit).
  static const int maxEmailLength = 254;

  /// Password length bounds, in code points.
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;

  /// Name length bounds, in code points.
  static const int minNameLength = 2;
  static const int maxNameLength = 60;

  /// Digits in an Indian mobile number.
  static const int phoneDigits = 10;

  // ASCII-only local part and dotted labels, each label 1–63 characters,
  // TLD at least two letters. ASCII only means injection punctuation,
  // control, bidi and emoji characters are rejected by construction.
  static final RegExp _email = RegExp(
    '^[A-Za-z0-9](?:[A-Za-z0-9._%+-]{0,63})@'
    r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
    r'[A-Za-z]{2,24}$',
  );

  // Letters (any script, with combining marks), spaces, apostrophes, dots
  // and hyphens.
  static final RegExp _name = RegExp(
    r"^[\p{L}\p{M}][\p{L}\p{M} '.\-]*$",
    unicode: true,
  );

  // Any Unicode letter / mark; used to reject emoji, digits and symbols
  // without listing scripts.
  static final RegExp _control = RegExp(
    r'[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁦-⁩﻿]',
  );

  static final RegExp _asciiDigit = RegExp('[0-9]');
  static final RegExp _lower = RegExp('[a-z]');
  static final RegExp _upper = RegExp('[A-Z]');
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9\s]');

  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (v.length > maxEmailLength || !_email.hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    final length = value.runes.length;
    if (length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    if (length > maxPasswordLength) {
      return 'Use at most $maxPasswordLength characters';
    }
    return null;
  }

  /// A simple, total strength estimate: one point for ≥ 8 code points, one
  /// more at 12, 16 and 24 (long passphrases are strong on length alone),
  /// one each for mixed case, digits and symbols; capped at four.
  static PasswordStrength passwordStrength(String value) {
    if (value.isEmpty) return PasswordStrength.none;
    final length = value.runes.length;
    if (length < minPasswordLength) return PasswordStrength.weak;
    // Scan at most the first 256 code units; strength does not need more
    // and this keeps hostile 10k-character input cheap.
    final sample = value.length > 256 ? value.substring(0, 256) : value;
    var score = 1;
    if (length >= 12) score++;
    if (length >= 16) score++;
    if (length >= 24) score++;
    if (_lower.hasMatch(sample) && _upper.hasMatch(sample)) score++;
    if (_asciiDigit.hasMatch(sample)) score++;
    if (_symbol.hasMatch(sample)) score++;
    return switch (score.clamp(1, 4)) {
      1 => PasswordStrength.weak,
      2 => PasswordStrength.fair,
      3 => PasswordStrength.good,
      _ => PasswordStrength.strong,
    };
  }

  static String? validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    final length = v.runes.length;
    if (length < minNameLength) return 'Use at least $minNameLength characters';
    if (length > maxNameLength) return 'Use at most $maxNameLength characters';
    if (_control.hasMatch(v) || !_name.hasMatch(v)) return 'Use letters only';
    return null;
  }

  /// Keeps the national 10 digits of an Indian mobile number: separators
  /// are dropped, a `+91` / `91` country code or a leading `0` is removed.
  /// Returns an empty string when nothing usable is left. Only ASCII digits
  /// count; other scripts' digits are not silently converted.
  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length == phoneDigits + 2 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == phoneDigits + 1 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final digits = normalizePhone(value);
    // Indian mobiles start with 6–9.
    if (digits.length != phoneDigits || !RegExp('^[6-9]').hasMatch(digits)) {
      return 'Enter a 10-digit mobile number';
    }
    return null;
  }
}
