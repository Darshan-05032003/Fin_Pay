import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Thrown when an arithmetic result or a parsed value does not fit in the
/// signed 64-bit paise range.
class MoneyOverflowException implements Exception {
  const MoneyOverflowException(this.operation);

  /// The operation that overflowed, for diagnostics.
  final String operation;

  @override
  String toString() => 'MoneyOverflowException: $operation';
}

/// An amount of Indian rupees stored as an exact integer number of paise.
///
/// Money is never a `double`: every constructor, parser and operator produces
/// or checks an `int`, and every arithmetic operation throws
/// [MoneyOverflowException] instead of wrapping past the int64 bounds.
class Money extends Equatable implements Comparable<Money> {
  /// Creates an amount from an exact number of paise.
  const Money.paise(this.paise);

  /// Creates an amount from rupees. Doubles are rounded half away from zero
  /// to the nearest paisa; NaN and infinities are rejected.
  factory Money.rupees(num rupees) {
    if (rupees is int) {
      return Money.paise(_checkedMultiply(rupees, 100, 'Money.rupees'));
    }
    final value = rupees.toDouble();
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(rupees, 'rupees', 'must be a finite number');
    }
    final scaled = value * 100;
    if (scaled >= _maxPaiseAsDouble || scaled < _minPaiseAsDouble) {
      throw const MoneyOverflowException('Money.rupees');
    }
    return Money.paise(_roundHalfAwayFromZero(scaled));
  }

  /// Reads an amount back from JSON written by [toJson].
  factory Money.fromJson(Object? json) {
    if (json is int) return Money.paise(json);
    throw FormatException('Money.fromJson expects an int, got $json');
  }

  /// Parses user or pasted input such as `1,23,456.78`, `₹1,234.5`,
  /// `Rs. 500` or `-42`.
  ///
  /// Grouping separators (`,` and spaces), currency markers (`₹`, `Rs`, `Rs.`,
  /// `INR`), surrounding whitespace, NBSP and bidirectional *marks* are
  /// tolerated. Any Unicode decimal digit is accepted. A bidirectional
  /// *override* (which can visually reorder the digits), letters, emoji,
  /// exponents and more than one decimal point throw a [FormatException].
  /// Values outside the int64 paise range throw [MoneyOverflowException].
  factory Money.parse(String input) {
    final source = input.trim();

    final buffer = StringBuffer();
    var negative = false;
    var signSeen = false;
    var digitsSeen = false;
    var decimalSeen = false;
    var fractionDigits = 0;

    final runes = source.runes.toList();
    var i = 0;
    while (i < runes.length) {
      final rune = runes[i];
      if (_isIgnorable(rune)) {
        i++;
        continue;
      }
      if (_isBidiOverride(rune)) {
        throw FormatException('Bidirectional override is not allowed', input);
      }
      if (rune == 0x2B /* + */ ||
          rune == 0x2D /* - */ ||
          rune == 0x2212 /* − */ ) {
        if (signSeen || digitsSeen || decimalSeen) {
          throw FormatException('Misplaced sign', input);
        }
        signSeen = true;
        negative = rune != 0x2B;
        i++;
        continue;
      }
      final prefixLength = _currencyPrefixLength(runes, i);
      if (prefixLength > 0) {
        if (digitsSeen || decimalSeen) {
          throw FormatException('Currency marker after digits', input);
        }
        i += prefixLength;
        continue;
      }
      if (rune == 0x2E /* . */ || rune == 0xFF0E /* ． */ ) {
        if (decimalSeen) {
          throw FormatException('More than one decimal point', input);
        }
        decimalSeen = true;
        i++;
        continue;
      }
      if (rune == 0x2C /* , */ || rune == 0xFF0C /* ， */ ) {
        if (decimalSeen || !digitsSeen) {
          throw FormatException('Misplaced grouping separator', input);
        }
        i++;
        continue;
      }
      final digit = _decimalDigitValue(rune);
      if (digit == null) {
        throw FormatException('Unexpected character', input);
      }
      digitsSeen = true;
      if (!decimalSeen && buffer.length > _maxIntegerDigits) {
        // More integer digits than int64 paise can hold: reject before
        // scanning a pasted megabyte of digits.
        throw const MoneyOverflowException('Money.parse');
      }
      if (decimalSeen) {
        fractionDigits++;
        if (fractionDigits > 3) {
          // Only the third decimal matters for rounding.
          i++;
          continue;
        }
      }
      buffer.writeCharCode(0x30 + digit);
      i++;
    }

    if (!digitsSeen) {
      throw FormatException('No digits found', input);
    }

    final digits = buffer.toString();
    final intPartLength =
        digits.length - (fractionDigits > 3 ? 3 : fractionDigits);
    final intDigits = digits.substring(0, intPartLength);
    final fracDigits = digits.substring(intPartLength).padRight(3, '0');

    final bigPaise =
        BigInt.parse(
          '${intDigits.isEmpty ? '0' : intDigits}'
          '${fracDigits.substring(0, 2)}',
        ) *
        (negative ? -BigInt.one : BigInt.one);
    final roundUp = fracDigits.codeUnitAt(2) >= 0x35; // '5'
    final rounded = roundUp
        ? (negative ? bigPaise - BigInt.one : bigPaise + BigInt.one)
        : bigPaise;
    if (rounded > _maxBig || rounded < _minBig) {
      throw const MoneyOverflowException('Money.parse');
    }
    return Money.paise(rounded.toInt());
  }

  /// Like [Money.parse] but returns `null` for invalid or overflowing input.
  static Money? tryParse(String input) {
    try {
      return Money.parse(input);
    } on FormatException {
      return null;
    } on MoneyOverflowException {
      return null;
    }
  }

  /// The exact amount in paise.
  final int paise;

  /// ₹0.00.
  static const Money zero = Money.paise(0);

  /// The largest representable amount.
  static const Money max = Money.paise(9223372036854775807);

  /// The smallest (most negative) representable amount.
  static const Money min = Money.paise(-9223372036854775808);

  static const int _maxIntegerDigits = 20;
  static final BigInt _maxBig = BigInt.from(max.paise);
  static final BigInt _minBig = BigInt.from(min.paise);
  static final double _maxPaiseAsDouble = max.paise.toDouble();
  static final double _minPaiseAsDouble = min.paise.toDouble();

  static final NumberFormat _rupeeGrouping = NumberFormat('#,##,##0', 'en_IN');
  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
  );

  /// The currency symbol used by [format].
  static const String symbol = '₹';

  /// Display-only conversion to rupees as a double. Never use the result for
  /// arithmetic or storage; it loses precision above 2^53 paise.
  double get rupees => paise / 100;

  /// True for amounts below zero.
  bool get isNegative => paise < 0;

  /// True for exactly zero.
  bool get isZero => paise == 0;

  /// True for amounts above zero.
  bool get isPositive => paise > 0;

  /// The magnitude of this amount.
  Money abs() => isNegative ? -this : this;

  Money operator -() {
    if (paise == min.paise) throw const MoneyOverflowException('negate');
    return Money.paise(-paise);
  }

  Money operator +(Money other) {
    final sum = paise + other.paise;
    // Overflow iff both operands share a sign that the result does not.
    if ((paise ^ sum) & (other.paise ^ sum) < 0) {
      throw const MoneyOverflowException('add');
    }
    return Money.paise(sum);
  }

  Money operator -(Money other) {
    final difference = paise - other.paise;
    // Overflow iff the operands have different signs and the result's sign
    // differs from the minuend's.
    if ((paise ^ other.paise) & (paise ^ difference) < 0) {
      throw const MoneyOverflowException('subtract');
    }
    return Money.paise(difference);
  }

  Money operator *(int factor) =>
      Money.paise(_checkedMultiply(paise, factor, 'multiply'));

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  /// Formats as `₹1,23,456.78` (en_IN lakh/crore grouping, two decimals).
  ///
  /// Negative amounts get a leading minus (`-₹1.00`); [showSign] adds a plus
  /// to positive amounts; [symbol] = false drops the rupee sign.
  String format({bool showSign = false, bool symbol = true}) {
    final negative = isNegative;
    // Work on the magnitude without negating (min cannot be negated).
    final magnitudeRupees = (paise ~/ 100).abs();
    final magnitudePaise = paise.remainder(100).abs();
    final whole = _rupeeGrouping.format(magnitudeRupees);
    final cents = magnitudePaise.toString().padLeft(2, '0');
    final sign = negative
        ? '-'
        : showSign && isPositive
        ? '+'
        : '';
    return '$sign${symbol ? Money.symbol : ''}$whole.$cents';
  }

  /// Short form for headers: `₹999`, `₹15K`, `₹1.23L`, `₹3.4Cr`.
  String formatCompact() {
    final whole = paise ~/ 100;
    if (whole == 0) return '${Money.symbol}0';
    final text = _compact.format(whole.abs());
    return whole < 0 ? '-$text' : text;
  }

  /// Serialises as the integer paise.
  int toJson() => paise;

  @override
  List<Object?> get props => [paise];

  @override
  String toString() => format();

  static int _roundHalfAwayFromZero(double value) {
    // `round()` already rounds half away from zero, but binary doubles such
    // as 1.005 * 100 = 100.49999... need a tiny epsilon to behave like the
    // decimal the user typed.
    final adjusted = value + (value.isNegative ? -1e-9 : 1e-9);
    return adjusted.round();
  }

  static int _checkedMultiply(int a, int b, String operation) {
    if (a == 0 || b == 0) return 0;
    final product = a * b;
    if (product ~/ b != a ||
        (a == -1 && b == min.paise) ||
        (b == -1 && a == min.paise)) {
      throw MoneyOverflowException(operation);
    }
    return product;
  }

  static bool _isIgnorable(int rune) =>
      rune == 0x20 ||
      rune == 0x09 ||
      rune == 0x0A ||
      rune == 0x0D ||
      rune == 0xA0 || // NBSP
      rune == 0x202F || // narrow NBSP
      rune == 0x2009 || // thin space
      rune == 0xFEFF || // BOM / ZWNBSP
      rune == 0x200B || // zero-width space
      rune == 0x200E || // LRM
      rune == 0x200F || // RLM
      rune == 0x202A || // LRE
      rune == 0x202B || // RLE
      rune == 0x202C || // PDF
      rune == 0x2066 || // LRI
      rune == 0x2067 || // RLI
      rune == 0x2068 || // FSI
      rune == 0x2069; // PDI

  static bool _isBidiOverride(int rune) => rune == 0x202D || rune == 0x202E;

  static int _currencyPrefixLength(List<int> runes, int start) {
    final rune = runes[start];
    if (rune == 0x20B9 /* ₹ */ ) return 1;
    // "Rs", "Rs.", "INR" in any case, optionally followed by a dot.
    final rest = String.fromCharCodes(runes.skip(start).take(4)).toUpperCase();
    if (rest.startsWith('INR')) return 3;
    if (rest.startsWith('RS.')) return 3;
    if (rest.startsWith('RS')) return 2;
    return 0;
  }

  /// Returns the numeric value of any Unicode `Nd` digit, or null.
  static int? _decimalDigitValue(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return rune - 0x30;
    for (final zero in _digitZeros) {
      if (rune >= zero && rune <= zero + 9) return rune - zero;
    }
    return null;
  }

  // Zero code points of the Unicode decimal digit blocks that Indian and
  // common keyboards can produce.
  static const List<int> _digitZeros = [
    0x0660, // Arabic-Indic
    0x06F0, // Extended Arabic-Indic
    0x0966, // Devanagari
    0x09E6, // Bengali
    0x0A66, // Gurmukhi
    0x0AE6, // Gujarati
    0x0B66, // Oriya
    0x0BE6, // Tamil
    0x0C66, // Telugu
    0x0CE6, // Kannada
    0x0D66, // Malayalam
    0xFF10, // Fullwidth
  ];
}
