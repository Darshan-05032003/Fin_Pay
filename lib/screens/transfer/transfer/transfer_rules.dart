import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/screens/transfer/transfer/amount_input.dart';

/// Why an amount cannot be sent.
enum AmountError { empty, overMax, overBalance }

/// Business rules of a transfer amount.
abstract final class AmountRules {
  /// Per-transfer ceiling (UPI-style ₹1,00,000).
  static const Money maxPerTransfer = Money.paise(10000000);

  /// The quick-amount chips.
  static const List<Money> quickAmounts = [
    Money.paise(50000),
    Money.paise(100000),
    Money.paise(200000),
    Money.paise(500000),
  ];

  /// Null when [amount] can be sent from [balance].
  static AmountError? validate(Money amount, {required Money balance}) {
    if (!amount.isPositive) return AmountError.empty;
    if (amount > maxPerTransfer) return AmountError.overMax;
    if (amount > balance) return AmountError.overBalance;
    return null;
  }

  /// True when the Continue button may be enabled.
  static bool canContinue(AmountInput input, {required Money balance}) =>
      !input.isEmpty && validate(input.money, balance: balance) == null;

  /// Inline message for [error].
  static String message(AmountError error, {required Money balance}) =>
      switch (error) {
        AmountError.empty => 'Enter an amount',
        AmountError.overMax =>
          'Maximum ${_wholeRupees(maxPerTransfer)} per transfer',
        AmountError.overBalance =>
          "That's more than your balance (${balance.format()})",
      };

  static String _wholeRupees(Money money) {
    final text = money.format();
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }
}

/// The optional note on a transfer: free text, bounded and free of control
/// characters so it renders the same on the review, the receipt and the
/// clipboard.
abstract final class TransferNote {
  /// Maximum length in code points.
  static const int maxLength = 40;

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Drops control, bidi-control and zero-width characters, collapses
  /// whitespace, trims and caps at [maxLength] code points.
  static String sanitise(String raw) {
    final kept = StringBuffer();
    for (final rune in raw.runes) {
      if (_isDropped(rune)) continue;
      kept.writeCharCode(rune);
    }
    final collapsed = kept.toString().replaceAll(_whitespace, ' ').trim();
    final runes = collapsed.runes.toList();
    if (runes.length <= maxLength) return collapsed;
    return String.fromCharCodes(runes.take(maxLength)).trimRight();
  }

  static bool _isDropped(int rune) {
    if (rune == 0x09 || rune == 0x0A || rune == 0x0D) return false;
    if (rune < 0x20 || rune == 0x7F) return true;
    if (rune >= 0x80 && rune <= 0x9F) return true;
    if (rune >= 0x200B && rune <= 0x200F) return true;
    if (rune >= 0x202A && rune <= 0x202E) return true;
    if (rune >= 0x2060 && rune <= 0x2064) return true;
    if (rune >= 0x2066 && rune <= 0x2069) return true;
    if (rune == 0xFEFF) return true;
    return false;
  }
}
