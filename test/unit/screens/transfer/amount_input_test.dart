import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/screens/transfer/transfer/amount_input.dart';
import 'package:fin_pay/screens/transfer/transfer/transfer_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmountInput keypad', () {
    test('starts empty with zero paise', () {
      expect(AmountInput.empty.text, '');
      expect(AmountInput.empty.paise, 0);
      expect(AmountInput.empty.isEmpty, isTrue);
      expect(AmountInput.empty.money, Money.zero);
    });

    test('digits append and parse as rupees', () {
      final a = AmountInput.empty.digit(1).digit(2).digit(3).digit(4);
      expect(a.text, '1234');
      expect(a.paise, 123400);
    });

    test('a leading zero is replaced by the next digit', () {
      expect(AmountInput.empty.digit(0).text, '0');
      expect(AmountInput.empty.digit(0).digit(0).text, '0');
      expect(AmountInput.empty.digit(0).digit(5).text, '5');
    });

    test('the decimal point is accepted once and seeds a zero', () {
      expect(AmountInput.empty.decimal().text, '0.');
      expect(AmountInput.empty.decimal().decimal().text, '0.');
      expect(AmountInput.empty.digit(5).decimal().digit(5).text, '5.5');
      expect(AmountInput.empty.digit(5).decimal().digit(5).paise, 550);
      expect(AmountInput.empty.decimal().digit(5).paise, 50);
    });

    test('at most two fraction digits', () {
      final a = AmountInput.empty.digit(1).decimal().digit(2).digit(3).digit(4);
      expect(a.text, '1.23');
      expect(a.paise, 123);
    });

    test('at most seven integer digits (₹99,99,999)', () {
      var a = AmountInput.empty;
      for (var i = 0; i < 12; i++) {
        a = a.digit(9);
      }
      expect(a.text, '9999999');
      expect(a.paise, 999999900);
      // A decimal can still follow.
      expect(a.decimal().digit(5).text, '9999999.5');
    });

    test('backspace removes one character and rolls back', () {
      final a = AmountInput.empty.digit(1).digit(2).decimal().digit(5);
      expect(a.backspace().text, '12.');
      expect(a.backspace().backspace().text, '12');
      expect(a.backspace().backspace().backspace().text, '1');
      expect(a.backspace().backspace().backspace().backspace().text, '');
      expect(AmountInput.empty.backspace(), AmountInput.empty);
    });

    test('out-of-range digits are rejected', () {
      expect(() => AmountInput.empty.digit(10), throwsArgumentError);
      expect(() => AmountInput.empty.digit(-1), throwsArgumentError);
    });

    test('is a value type', () {
      expect(AmountInput.empty.digit(1), AmountInput.empty.digit(1));
      expect(AmountInput.empty.digit(1), isNot(AmountInput.empty.digit(2)));
    });

    test('fromPaise renders rupees without trailing .00', () {
      expect(AmountInput.fromPaise(50000).text, '500');
      expect(AmountInput.fromPaise(50050).text, '500.5');
      expect(AmountInput.fromPaise(50055).text, '500.55');
      expect(AmountInput.fromPaise(5).text, '0.05');
      expect(AmountInput.fromPaise(0).text, '');
    });
  });

  group('AmountInput.fromText (paste)', () {
    test('accepts plain, grouped and prefixed rupees', () {
      expect(AmountInput.fromText('1234')?.text, '1234');
      expect(AmountInput.fromText('1,23,456.78')?.text, '123456.78');
      expect(AmountInput.fromText('₹ 500')?.text, '500');
      expect(AmountInput.fromText('Rs. 42.5')?.text, '42.5');
      expect(AmountInput.fromText('  99  ')?.text, '99');
    });

    test('normalises fullwidth, Arabic-Indic and Devanagari digits', () {
      expect(AmountInput.fromText('１２３４')?.text, '1234');
      expect(AmountInput.fromText('٣٤٥')?.text, '345');
      expect(AmountInput.fromText('१२३.५०')?.text, '123.5');
    });

    test('rejects zero, negative and non-numeric input', () {
      expect(AmountInput.fromText('0'), isNull);
      expect(AmountInput.fromText('0.00'), isNull);
      expect(AmountInput.fromText('-5'), isNull);
      expect(AmountInput.fromText('−5'), isNull);
      expect(AmountInput.fromText(''), isNull);
      expect(AmountInput.fromText('abc'), isNull);
      expect(AmountInput.fromText('1e5'), isNull);
      expect(AmountInput.fromText('12abc'), isNull);
      expect(AmountInput.fromText('😀'), isNull);
      expect(AmountInput.fromText('1.2.3'), isNull);
      expect(AmountInput.fromText('<script>1</script>'), isNull);
      expect(AmountInput.fromText("' OR 1=1 --"), isNull);
    });

    test('rejects a bidi override that could reorder digits', () {
      expect(AmountInput.fromText('\u202E123'), isNull);
    });

    test('rejects amounts past the keypad limit and int64 paise', () {
      expect(AmountInput.fromText('9999999')?.text, '9999999');
      expect(AmountInput.fromText('10000000'), isNull);
      expect(AmountInput.fromText('92233720368547758.07'), isNull);
      expect(AmountInput.fromText('92233720368547758.08'), isNull);
      expect(AmountInput.fromText('99999999999999999999999'), isNull);
    });

    test('rejects a 100,000-character paste quickly', () {
      final sw = Stopwatch()..start();
      expect(AmountInput.fromText('9' * 100000), isNull);
      expect(AmountInput.fromText('${'1' * 50000}.${'2' * 50000}'), isNull);
      expect(AmountInput.fromText('\u200B' * 100000), isNull);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('rounds a third decimal half away from zero', () {
      expect(AmountInput.fromText('1.005')?.text, '1.01');
      expect(AmountInput.fromText('1.004')?.text, '1');
    });
  });

  group('AmountRules', () {
    const balance = Money.paise(5624690);

    test('the per-transfer maximum is ₹1,00,000', () {
      expect(AmountRules.maxPerTransfer, const Money.paise(10000000));
    });

    test('validate flags over-max before over-balance', () {
      expect(
        AmountRules.validate(const Money.paise(10000000), balance: balance),
        AmountError.overBalance,
      );
      expect(
        AmountRules.validate(
          const Money.paise(10000001),
          balance: const Money.paise(99999999999),
        ),
        AmountError.overMax,
      );
      expect(
        AmountRules.validate(const Money.paise(10000001), balance: balance),
        AmountError.overMax,
      );
      expect(
        AmountRules.validate(const Money.paise(5624690), balance: balance),
        isNull,
      );
      expect(
        AmountRules.validate(const Money.paise(5624691), balance: balance),
        AmountError.overBalance,
      );
      expect(
        AmountRules.validate(const Money.paise(1), balance: balance),
        isNull,
      );
    });

    test('zero and negative amounts are never valid', () {
      expect(
        AmountRules.validate(Money.zero, balance: balance),
        AmountError.empty,
      );
      expect(
        AmountRules.validate(const Money.paise(-1), balance: balance),
        AmountError.empty,
      );
      expect(
        AmountRules.validate(Money.min, balance: balance),
        AmountError.empty,
      );
    });

    test('int64 extremes are over max, never an exception', () {
      expect(
        AmountRules.validate(Money.max, balance: balance),
        AmountError.overMax,
      );
      expect(
        AmountRules.validate(Money.max, balance: Money.max),
        AmountError.overMax,
      );
    });

    test('canContinue needs a positive, valid amount', () {
      expect(
        AmountRules.canContinue(AmountInput.empty, balance: balance),
        isFalse,
      );
      expect(
        AmountRules.canContinue(AmountInput.empty.digit(0), balance: balance),
        isFalse,
      );
      expect(
        AmountRules.canContinue(AmountInput.empty.digit(5), balance: balance),
        isTrue,
      );
      expect(
        AmountRules.canContinue(
          AmountInput.fromPaise(5624691),
          balance: balance,
        ),
        isFalse,
      );
    });

    test('messages name the limit', () {
      expect(
        AmountRules.message(AmountError.overMax, balance: balance),
        contains('₹1,00,000'),
      );
      expect(
        AmountRules.message(AmountError.overBalance, balance: balance),
        contains('₹56,246.90'),
      );
      expect(
        AmountRules.message(AmountError.empty, balance: balance),
        isNotEmpty,
      );
    });

    test('quick amounts are the four chips, all within the maximum', () {
      expect(AmountRules.quickAmounts, [
        const Money.paise(50000),
        const Money.paise(100000),
        const Money.paise(200000),
        const Money.paise(500000),
      ]);
      for (final q in AmountRules.quickAmounts) {
        expect(q <= AmountRules.maxPerTransfer, isTrue);
      }
    });
  });

  group('TransferNote', () {
    test('trims, collapses whitespace and caps at 40 characters', () {
      expect(TransferNote.sanitise('  rent   for  may  '), 'rent for may');
      expect(TransferNote.sanitise('a' * 100).length, TransferNote.maxLength);
      expect(TransferNote.sanitise(''), '');
    });

    test('strips control characters, bidi overrides and zero-width marks', () {
      expect(TransferNote.sanitise('ok\u0000\u0007\u001B[31m'), 'ok[31m');
      expect(TransferNote.sanitise('\u202Erent\u202C'), 'rent');
      expect(TransferNote.sanitise('re\u200Bnt'), 'rent');
      expect(TransferNote.sanitise('line\nbreak\ttab'), 'line break tab');
    });

    test('keeps emoji and non-Latin text', () {
      expect(TransferNote.sanitise('चाय ☕ 😀'), 'चाय ☕ 😀');
    });

    test('a 100,000-character note is capped, not rejected', () {
      final note = TransferNote.sanitise('😀' * 100000);
      expect(note.runes.length, TransferNote.maxLength);
    });
  });
}
