import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/screens/cards/add_card/card_validators.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31);

  group('digitsOnly', () {
    test('keeps ASCII digits, drops separators, caps the length', () {
      expect(
        CardValidators.digitsOnly('4111-1111 1111.1111'),
        '4111111111111111',
      );
      expect(CardValidators.digitsOnly('41111111111111119999'), hasLength(16));
      expect(CardValidators.digitsOnly('12', max: 1), '1');
    });

    test('never converts Devanagari, Arabic-Indic or fullwidth digits', () {
      expect(CardValidators.digitsOnly('४१११'), isEmpty);
      expect(CardValidators.digitsOnly('٤١١١'), isEmpty);
      expect(CardValidators.digitsOnly('４１１１'), isEmpty);
      expect(CardValidators.digitsOnly('4१1١1４1'), '4111');
    });

    test('ignores bidi marks, zero-width characters, emoji and NUL', () {
      expect(
        CardValidators.digitsOnly('\u202E4111\u200B1111\u00001111😀1111\u202C'),
        '4111111111111111',
      );
    });

    test('a 100,000-character paste is handled and capped', () {
      final huge = '4' * 100000;
      expect(CardValidators.digitsOnly(huge), '4' * 16);
      expect(CardValidators.digitsOnly('x' * 100000), isEmpty);
    });
  });

  group('luhn', () {
    test('known-good PANs pass', () {
      for (final pan in [
        '4111111111111111',
        '4012888888881881',
        '5555555555554444',
        '5105105105105100',
        '2223000048400011',
        '6011111111111117',
        '6521020000000005',
        '79927398713',
      ]) {
        expect(CardValidators.luhn(pan), isTrue, reason: pan);
      }
    });

    test('a single changed digit, letters and empty input fail', () {
      expect(CardValidators.luhn('4111111111111112'), isFalse);
      expect(CardValidators.luhn('411111111111111a'), isFalse);
      expect(CardValidators.luhn(''), isFalse);
      expect(CardValidators.luhn('0'), isTrue);
    });
  });

  group('detectNetwork', () {
    test('Visa from a single 4', () {
      expect(CardValidators.detectNetwork('4'), CardNetwork.visa);
      expect(CardValidators.detectNetwork('4111'), CardNetwork.visa);
    });

    test('Mastercard 51–55 and 2221–2720', () {
      for (final bin in ['51', '53', '55', '5555', '2221', '2500', '2720']) {
        expect(
          CardValidators.detectNetwork(bin),
          CardNetwork.mastercard,
          reason: bin,
        );
      }
      for (final bin in ['50', '56', '2220', '2721', '22', '222']) {
        expect(
          CardValidators.detectNetwork(bin),
          isNot(CardNetwork.mastercard),
          reason: bin,
        );
      }
    });

    test('RuPay 60, 65, 81, 82, 508', () {
      for (final bin in ['60', '65', '81', '82', '508', '6012', '5081']) {
        expect(
          CardValidators.detectNetwork(bin),
          CardNetwork.rupay,
          reason: bin,
        );
      }
      expect(CardValidators.detectNetwork('50'), CardNetwork.unknown);
      expect(CardValidators.detectNetwork('509'), CardNetwork.unknown);
      expect(CardValidators.detectNetwork('6'), CardNetwork.unknown);
    });

    test('unknown for empty, other prefixes and hostile input', () {
      expect(CardValidators.detectNetwork(''), CardNetwork.unknown);
      expect(CardValidators.detectNetwork('3'), CardNetwork.unknown);
      expect(CardValidators.detectNetwork('9999'), CardNetwork.unknown);
      expect(CardValidators.detectNetwork('abc'), CardNetwork.unknown);
      expect(CardValidators.detectNetwork('٤'), CardNetwork.unknown);
    });

    test('maps to the stored CardType and back', () {
      expect(CardNetwork.visa.cardType, CardType.visa);
      expect(CardNetwork.mastercard.cardType, CardType.mastercard);
      expect(CardNetwork.rupay.cardType, CardType.rupay);
      expect(CardNetwork.unknown.cardType, isNull);
      expect(CardNetwork.forType(CardType.amex), CardNetwork.unknown);
      expect(CardNetwork.forType(CardType.rupay), CardNetwork.rupay);
    });
  });

  group('validateNumber', () {
    test('messages per failure', () {
      expect(CardValidators.validateNumber(''), 'Card number is required');
      expect(CardValidators.validateNumber('4111 1111'), 'Enter all 16 digits');
      expect(
        CardValidators.validateNumber('3782822463100051'),
        'We support Visa, Mastercard and RuPay',
      );
      expect(
        CardValidators.validateNumber('4111111111111112'),
        'Check the card number',
      );
      expect(CardValidators.validateNumber('4111 1111 1111 1111'), isNull);
      expect(CardValidators.validateNumber('6521020000000005'), isNull);
    });

    test('hostile input is reduced before it is judged', () {
      expect(
        CardValidators.validateNumber('😀' * 500),
        'Card number is required',
      );
      expect(
        CardValidators.validateNumber('\u202E${'4' * 16}'),
        'Check the card number',
      );
    });
  });

  group('formatPan and previewPan', () {
    test('groups 4-4-4-4', () {
      expect(
        CardValidators.formatPan('4111111111111111'),
        '4111 1111 1111 1111',
      );
      expect(CardValidators.formatPan('41111'), '4111 1');
      expect(CardValidators.formatPan(''), '');
    });

    test('preview pads with bullets', () {
      expect(CardValidators.previewPan(''), '•••• •••• •••• ••••');
      expect(CardValidators.previewPan('411111'), '4111 11•• •••• ••••');
      expect(
        CardValidators.previewPan('4111111111111111'),
        '4111 1111 1111 1111',
      );
    });
  });

  group('expiry', () {
    test('formatExpiry inserts the slash and pads a leading month digit', () {
      expect(CardValidators.formatExpiry(''), '');
      expect(CardValidators.formatExpiry('1'), '1');
      expect(CardValidators.formatExpiry('5'), '05/');
      expect(CardValidators.formatExpiry('12'), '12');
      expect(CardValidators.formatExpiry('122'), '12/2');
      expect(CardValidators.formatExpiry('1228'), '12/28');
      expect(CardValidators.formatExpiry('12/28'), '12/28');
      expect(CardValidators.formatExpiry('122899'), '12/28');
    });

    test('parseExpiry', () {
      expect(CardValidators.parseExpiry('12/28'), (month: 12, year: 2028));
      expect(CardValidators.parseExpiry('0130'), (month: 1, year: 2030));
      expect(CardValidators.parseExpiry('13/28'), isNull);
      expect(CardValidators.parseExpiry('00/28'), isNull);
      expect(CardValidators.parseExpiry('1/28'), isNull);
    });

    test('validateExpiry: required, format, month, past, too far', () {
      String? v(String s) => CardValidators.validateExpiry(s, now: now);
      expect(v(''), 'Expiry is required');
      expect(v('12'), 'Use MM/YY');
      expect(v('13/28'), 'Month must be 01 to 12');
      expect(v('00/28'), 'Month must be 01 to 12');
      expect(v('09/26'), 'This card has expired');
      expect(v('10/26'), isNull, reason: 'valid through the end of the month');
      expect(v('11/26'), isNull);
      expect(v('10/36'), isNull, reason: 'exactly ten years ahead');
      expect(v('11/36'), 'Expiry is more than 10 years away');
      expect(v('12/99'), 'Expiry is more than 10 years away');
    });

    test('validateExpiry ignores non-ASCII digits and junk', () {
      expect(
        CardValidators.validateExpiry('१२/२८', now: now),
        'Expiry is required',
      );
      expect(
        CardValidators.validateExpiry('ab/cd', now: now),
        'Expiry is required',
      );
    });
  });

  group('validateCvv', () {
    test('three ASCII digits only', () {
      expect(CardValidators.validateCvv(''), 'CVV is required');
      expect(CardValidators.validateCvv('12'), 'CVV is 3 digits');
      expect(CardValidators.validateCvv('1234'), 'CVV is 3 digits');
      expect(CardValidators.validateCvv('123'), isNull);
      expect(CardValidators.validateCvv('१२३'), 'CVV is required');
      expect(CardValidators.validateCvv('1 2 3'), isNull);
    });
  });

  group('validateName', () {
    test('embossed-style names only', () {
      expect(CardValidators.validateName(''), 'Name on card is required');
      expect(CardValidators.validateName('A'), 'Use at least 2 characters');
      expect(
        CardValidators.validateName('A' * 27),
        'Use at most 26 characters',
      );
      expect(CardValidators.validateName('AARAV MEHTA'), isNull);
      expect(CardValidators.validateName("O'BRIEN-SMITH JR."), isNull);
      expect(
        CardValidators.validateName('AARAV 😀'),
        'Use letters only, as printed on the card',
      );
      expect(
        CardValidators.validateName('\u202EAARAV'),
        'Use letters only, as printed on the card',
      );
      expect(
        CardValidators.validateName('ААРАВ'),
        'Use letters only, as printed on the card',
      );
      expect(
        CardValidators.validateName('123'),
        'Use letters only, as printed on the card',
      );
    });
  });

  group('input formatters', () {
    TextEditingValue fmt(TextInputFormatter f, String old, String next) =>
        f.formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          ),
        );

    test('card number groups and caps, cursor at the end', () {
      const f = CardNumberInputFormatter();
      final v = fmt(f, '4111 111', '4111 1111');
      expect(v.text, '4111 1111');
      expect(v.selection.baseOffset, 9);
      expect(fmt(f, '', '4111111111111111999').text, '4111 1111 1111 1111');
      expect(fmt(f, '', '4١11').text, '411');
    });

    test('expiry inserts the slash and backspaces over it', () {
      const f = ExpiryInputFormatter();
      expect(fmt(f, '1', '12').text, '12');
      expect(fmt(f, '12', '122').text, '12/2');
      expect(fmt(f, '', '5').text, '05/');
      expect(fmt(f, '12/', '12').text, '1');
      expect(fmt(f, '12/2', '12/').text, '12');
      expect(fmt(f, '', '12/28xx').text, '12/28');
    });

    test('digits formatter and name formatter', () {
      const d = DigitsInputFormatter(max: 3);
      expect(fmt(d, '', '12a34').text, '123');
      const n = CardNameInputFormatter();
      final v = fmt(n, '', 'aarav mehta');
      expect(v.text, 'AARAV MEHTA');
      expect(v.selection.baseOffset, 11);
      expect(fmt(n, '', 'a' * 40).text, hasLength(26));
    });
  });
}
