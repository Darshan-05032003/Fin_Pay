import 'package:fin_pay/models/payment_card.dart';
import 'package:flutter/services.dart';

/// Card network detected from the first digits (BIN) of a PAN.
enum CardNetwork {
  visa('Visa', CardType.visa),
  mastercard('Mastercard', CardType.mastercard),
  rupay('RuPay', CardType.rupay),
  unknown('Card', null);

  const CardNetwork(this.label, this.cardType);

  /// Neutral text label (no trademarked wordmark artwork).
  final String label;

  /// The stored type, null when unsupported.
  final CardType? cardType;

  /// The network for a stored [CardType].
  static CardNetwork forType(CardType type) => switch (type) {
    CardType.visa => visa,
    CardType.mastercard => mastercard,
    CardType.rupay => rupay,
    CardType.amex => unknown,
  };
}

/// Pure validation and formatting for the add-card form. Every function is
/// total: hostile input (other scripts' digits, bidi marks, emoji, 10k-char
/// pastes) is reduced to ASCII digits or rejected with a message.
abstract final class CardValidators {
  /// Digits in a Visa / Mastercard / RuPay PAN.
  static const int panLength = 16;

  /// Digits in a CVV.
  static const int cvvLength = 3;

  /// Digits in an expiry (`MMYY`).
  static const int expiryDigits = 4;

  /// Longest holder name accepted.
  static const int maxNameLength = 26;

  /// Cards expiring further ahead than this are rejected.
  static const int maxExpiryYears = 10;

  static final RegExp _notAsciiDigit = RegExp('[^0-9]');
  static final RegExp _name = RegExp(r"^[A-Za-z][A-Za-z '.\-]*$");

  /// Keeps only ASCII digits (digits of other scripts are dropped, never
  /// converted) and caps the length at [max]. Scans at most the first
  /// 4,096 code units so a huge paste is cheap.
  static String digitsOnly(String input, {int max = panLength}) {
    final sample = input.length > 4096 ? input.substring(0, 4096) : input;
    final digits = sample.replaceAll(_notAsciiDigit, '');
    return digits.length > max ? digits.substring(0, max) : digits;
  }

  /// `4111111111111111` → `4111 1111 1111 1111`.
  static String formatPan(String digits) => _group(digitsOnly(digits));

  /// The PAN as shown on the live preview: typed digits grouped, the rest
  /// as bullets (`4111 11•• •••• ••••`).
  static String previewPan(String digits) =>
      _group(digitsOnly(digits).padRight(panLength, '•'));

  static String _group(String chars) {
    final buffer = StringBuffer();
    final units = chars.runes.toList();
    for (var i = 0; i < units.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.writeCharCode(units[i]);
    }
    return buffer.toString();
  }

  /// Network from the leading digits: Visa 4; Mastercard 51–55 and
  /// 2221–2720; RuPay 60, 65, 81, 82 and 508.
  static CardNetwork detectNetwork(String digits) {
    final d = digitsOnly(digits);
    if (d.isEmpty) return CardNetwork.unknown;
    if (d.startsWith('4')) return CardNetwork.visa;
    if (d.length >= 2) {
      final two = int.parse(d.substring(0, 2));
      if (two >= 51 && two <= 55) return CardNetwork.mastercard;
      if (two == 60 || two == 65 || two == 81 || two == 82) {
        return CardNetwork.rupay;
      }
    }
    if (d.length >= 3 && d.startsWith('508')) return CardNetwork.rupay;
    if (d.length >= 4) {
      final four = int.parse(d.substring(0, 4));
      if (four >= 2221 && four <= 2720) return CardNetwork.mastercard;
    }
    return CardNetwork.unknown;
  }

  /// Luhn checksum over ASCII digits.
  static bool luhn(String digits) {
    if (digits.isEmpty || _notAsciiDigit.hasMatch(digits)) return false;
    var sum = 0;
    var doubleIt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 0x30;
      if (doubleIt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
  }

  static String? validateNumber(String digits) {
    final d = digitsOnly(digits);
    if (d.isEmpty) return 'Card number is required';
    if (d.length < panLength) return 'Enter all $panLength digits';
    if (detectNetwork(d) == CardNetwork.unknown) {
      return 'We support Visa, Mastercard and RuPay';
    }
    if (!luhn(d)) return 'Check the card number';
    return null;
  }

  /// Holder name: ASCII letters, spaces, apostrophes, dots and hyphens
  /// (as embossed on a card), 2–[maxNameLength] characters.
  static String? validateName(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Name on card is required';
    if (v.length < 2) return 'Use at least 2 characters';
    if (v.length > maxNameLength) {
      return 'Use at most $maxNameLength characters';
    }
    if (!_name.hasMatch(v)) return 'Use letters only, as printed on the card';
    return null;
  }

  /// `1228` → `12/28`; a first digit above 1 is taken as a month (`5` →
  /// `05/`).
  static String formatExpiry(String input) {
    var d = digitsOnly(input, max: expiryDigits);
    var padded = false;
    if (d.isNotEmpty && d.length < expiryDigits && int.parse(d[0]) > 1) {
      d = '0$d';
      padded = true;
      if (d.length > expiryDigits) d = d.substring(0, expiryDigits);
    }
    if (d.length < 2) return d;
    // A padded month is complete, so show the slash and move on to the year.
    if (d.length == 2) return padded ? '$d/' : d;
    return '${d.substring(0, 2)}/${d.substring(2)}';
  }

  /// Parses `MM/YY` (or `MMYY`) into a month and a four-digit year.
  static ({int month, int year})? parseExpiry(String value) {
    final d = digitsOnly(value, max: expiryDigits);
    if (d.length != expiryDigits) return null;
    final month = int.parse(d.substring(0, 2));
    final year = 2000 + int.parse(d.substring(2));
    if (month < 1 || month > 12) return null;
    return (month: month, year: year);
  }

  /// Not expired at [now] and at most [maxExpiryYears] ahead. A card is
  /// valid through the last day of its expiry month.
  static String? validateExpiry(String value, {required DateTime now}) {
    final d = digitsOnly(value, max: expiryDigits);
    if (d.isEmpty) return 'Expiry is required';
    if (d.length < expiryDigits) return 'Use MM/YY';
    final parsed = parseExpiry(d);
    if (parsed == null) return 'Month must be 01 to 12';
    final endOfMonth = DateTime(parsed.year, parsed.month + 1);
    if (!endOfMonth.isAfter(now)) return 'This card has expired';
    final limit = DateTime(now.year + maxExpiryYears, now.month + 1);
    if (endOfMonth.isAfter(limit)) {
      return 'Expiry is more than $maxExpiryYears years away';
    }
    return null;
  }

  static String? validateCvv(String digits) {
    final d = digitsOnly(digits, max: cvvLength + 1);
    if (d.isEmpty) return 'CVV is required';
    if (d.length != cvvLength) return 'CVV is $cvvLength digits';
    return null;
  }
}

/// Groups the PAN 4-4-4-4 as the user types or pastes; drops anything that
/// is not an ASCII digit; caps at 16 digits.
class CardNumberInputFormatter extends TextInputFormatter {
  const CardNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = CardValidators.formatPan(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// `MM/YY` with the slash inserted automatically; digits only; caps at 4.
class ExpiryInputFormatter extends TextInputFormatter {
  const ExpiryInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Backspacing over the slash should remove the month's last digit too,
    // otherwise the slash is re-inserted and the key does nothing.
    var raw = newValue.text;
    if (oldValue.text.endsWith('/') &&
        raw.length == oldValue.text.length - 1 &&
        !raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }
    final text = CardValidators.formatExpiry(raw);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// ASCII digits only, capped at [max].
class DigitsInputFormatter extends TextInputFormatter {
  const DigitsInputFormatter({required this.max});

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = CardValidators.digitsOnly(newValue.text, max: max);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Upper-cases the holder name as embossed; caps the length.
class CardNameInputFormatter extends TextInputFormatter {
  const CardNameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (text.length > CardValidators.maxNameLength) {
      text = text.substring(0, CardValidators.maxNameLength);
    }
    text = text.toUpperCase();
    final offset = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
