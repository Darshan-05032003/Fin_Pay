import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';

/// The amount being typed on the transfer keypad, as canonical text:
/// `''`, `'12'`, `'12.'`, `'12.5'` or `'12.50'`.
///
/// Rules: at most [maxIntegerDigits] integer digits (₹99,99,999), at most
/// [maxFractionDigits] fraction digits, one decimal point, no leading
/// zeros. Pasted text goes through [fromText], which normalises any
/// Unicode decimal digit and rejects everything that is not a positive
/// rupee amount within the keypad's range.
class AmountInput extends Equatable {
  const AmountInput._(this.text);

  /// Canonical text for a known amount (quick chips).
  factory AmountInput.fromPaise(int paise) {
    if (paise <= 0) return empty;
    final rupees = paise ~/ 100;
    final cents = paise % 100;
    if (cents == 0) return AmountInput._('$rupees');
    final fraction = cents.toString().padLeft(2, '0');
    return AmountInput._(
      '$rupees.${fraction.endsWith('0') ? fraction[0] : fraction}',
    );
  }

  /// Nothing typed.
  static const AmountInput empty = AmountInput._('');

  /// ₹99,99,999 is the largest typeable amount (seven digits).
  static const int maxIntegerDigits = 7;
  static const int maxFractionDigits = 2;

  /// Largest paise value the keypad can hold.
  static const int maxPaise = 999999999;

  /// Canonical text (ASCII digits and at most one `.`).
  final String text;

  bool get isEmpty => text.isEmpty;
  bool get hasDecimal => text.contains('.');

  /// The amount in paise (`''` and `'0.'` are 0).
  int get paise {
    if (text.isEmpty) return 0;
    final dot = text.indexOf('.');
    final whole = dot < 0 ? text : text.substring(0, dot);
    final fraction = dot < 0 ? '' : text.substring(dot + 1);
    final rupees = whole.isEmpty ? 0 : int.parse(whole);
    final cents = int.parse(fraction.padRight(2, '0'));
    return rupees * 100 + cents;
  }

  Money get money => Money.paise(paise);

  /// Appends [digit] (0–9); ignored when the integer or fraction part is
  /// full. A lone leading zero is replaced by the next digit.
  AmountInput digit(int digit) {
    if (digit < 0 || digit > 9) {
      throw ArgumentError.value(digit, 'digit', 'must be 0-9');
    }
    final dot = text.indexOf('.');
    if (dot >= 0) {
      if (text.length - dot - 1 >= maxFractionDigits) return this;
      return AmountInput._('$text$digit');
    }
    if (text == '0') return AmountInput._('$digit');
    if (text.length >= maxIntegerDigits) return this;
    return AmountInput._('$text$digit');
  }

  /// Adds the decimal point once (`''` becomes `'0.'`).
  AmountInput decimal() {
    if (hasDecimal) return this;
    return AmountInput._('${text.isEmpty ? '0' : text}.');
  }

  /// Removes the last character.
  AmountInput backspace() =>
      text.isEmpty ? this : AmountInput._(text.substring(0, text.length - 1));

  /// Parses pasted text. Returns null for anything that is not a positive
  /// amount within [maxPaise]: letters, emoji, exponents, bidi overrides,
  /// negative or zero values, int64 overflow, or a 100,000-character paste
  /// (rejected before it is scanned).
  static AmountInput? fromText(String raw) {
    final money = Money.tryParse(raw);
    if (money == null || !money.isPositive || money.paise > maxPaise) {
      return null;
    }
    return AmountInput.fromPaise(money.paise);
  }

  @override
  List<Object?> get props => [text];

  @override
  String toString() => 'AmountInput';
}
