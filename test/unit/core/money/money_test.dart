import 'package:fin_pay/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money construction', () {
    test('paise constructor stores the exact integer', () {
      expect(const Money.paise(12345678).paise, 12345678);
    });

    test('rupees(int) multiplies by 100', () {
      expect(Money.rupees(1234), const Money.paise(123400));
    });

    test('rupees(double) rounds half away from zero to the nearest paisa', () {
      expect(Money.rupees(1.005), const Money.paise(101));
      expect(Money.rupees(-1.005), const Money.paise(-101));
      expect(Money.rupees(0.1 + 0.2), const Money.paise(30));
      expect(Money.rupees(420.90), const Money.paise(42090));
    });

    test('rupees rejects NaN and infinity', () {
      expect(() => Money.rupees(double.nan), throwsArgumentError);
      expect(() => Money.rupees(double.infinity), throwsArgumentError);
      expect(() => Money.rupees(double.negativeInfinity), throwsArgumentError);
    });

    test('rupees(int) overflows past the int64 bound', () {
      expect(
        () => Money.rupees(Money.max.paise ~/ 100 + 1),
        throwsMoneyOverflow,
      );
      expect(
        () => Money.rupees(Money.min.paise ~/ 100 - 1),
        throwsMoneyOverflow,
      );
      expect(
        Money.rupees(Money.max.paise ~/ 100).paise,
        Money.max.paise ~/ 100 * 100,
      );
    });

    test('rupees(double) overflows past the int64 bound', () {
      expect(() => Money.rupees(1e17), throwsMoneyOverflow);
      expect(() => Money.rupees(-1e17), throwsMoneyOverflow);
    });

    test('zero, max and min constants', () {
      expect(Money.zero.paise, 0);
      expect(Money.max.paise, 9223372036854775807);
      expect(Money.min.paise, -9223372036854775808);
    });
  });

  group('Money.parse', () {
    test('parses Indian grouped decimal input', () {
      expect(Money.parse('1,23,456.78'), const Money.paise(12345678));
    });

    test('parses western grouping too', () {
      expect(Money.parse('123,456.78'), const Money.paise(12345678));
    });

    test('accepts the rupee symbol and Rs prefixes', () {
      expect(Money.parse('₹1,23,456.78'), const Money.paise(12345678));
      expect(Money.parse('Rs. 500'), const Money.paise(50000));
      expect(Money.parse('Rs 500'), const Money.paise(50000));
      expect(Money.parse('INR 500'), const Money.paise(50000));
      expect(Money.parse('rs.500'), const Money.paise(50000));
    });

    test('parses negative and signed amounts', () {
      expect(Money.parse('-42.50'), const Money.paise(-4250));
      expect(Money.parse('-₹42.50'), const Money.paise(-4250));
      expect(Money.parse('₹-42.50'), const Money.paise(-4250));
      expect(Money.parse('+42.50'), const Money.paise(4250));
    });

    test('parses zero in its many spellings', () {
      expect(Money.parse('0'), Money.zero);
      expect(Money.parse('0.00'), Money.zero);
      expect(Money.parse('-0'), Money.zero);
      expect(Money.parse('.0'), Money.zero);
    });

    test('parses a single decimal digit as tens of paise', () {
      expect(Money.parse('1.5'), const Money.paise(150));
      expect(Money.parse('.5'), const Money.paise(50));
      expect(Money.parse('5.'), const Money.paise(500));
    });

    test('rounds a third decimal digit half away from zero', () {
      expect(Money.parse('1.005'), const Money.paise(101));
      expect(Money.parse('1.004'), const Money.paise(100));
      expect(Money.parse('-1.005'), const Money.paise(-101));
      expect(Money.parse('0.999'), const Money.paise(100));
    });

    test('tolerates pasted whitespace, NBSP and bidi control marks', () {
      expect(Money.parse('  1,234.50 \n'), const Money.paise(123450));
      expect(Money.parse('\u00a01\u00a0234.50'), const Money.paise(123450));
      expect(Money.parse('\u200e₹1,234.50\u200f'), const Money.paise(123450));
      expect(Money.parse('\u202b1,234.50\u202c'), const Money.paise(123450));
      expect(Money.parse('\ufeff1234'), const Money.paise(123400));
    });

    test('accepts non-ASCII decimal digits (Devanagari, Arabic-Indic, '
        'fullwidth)', () {
      expect(Money.parse('१२३.४५'), const Money.paise(12345));
      expect(Money.parse('١٢٣.٤٥'), const Money.paise(12345));
      expect(Money.parse('１２３．４５'), const Money.paise(12345));
    });

    test('rejects emoji, letters and other garbage', () {
      expect(() => Money.parse('💸100'), throwsFormatException);
      expect(() => Money.parse('100💸'), throwsFormatException);
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse('1e5'), throwsFormatException);
      expect(() => Money.parse('0x10'), throwsFormatException);
      expect(() => Money.parse('1,2,3,4.5.6'), throwsFormatException);
      expect(() => Money.parse('--5'), throwsFormatException);
      expect(() => Money.parse('5-'), throwsFormatException);
      expect(() => Money.parse('₹'), throwsFormatException);
      expect(() => Money.parse(''), throwsFormatException);
      expect(() => Money.parse('   '), throwsFormatException);
      expect(() => Money.parse('.'), throwsFormatException);
      expect(() => Money.parse('Infinity'), throwsFormatException);
      expect(() => Money.parse('NaN'), throwsFormatException);
    });

    test('rejects an RTL override that reorders the digits', () {
      // U+202E (RIGHT-TO-LEFT OVERRIDE) makes "001" render as "100".
      expect(() => Money.parse('\u202e001'), throwsFormatException);
    });

    test('overflow: more than int64 paise is an error, not a wrap', () {
      expect(() => Money.parse('92233720368547758.08'), throwsMoneyOverflow);
      expect(() => Money.parse('99999999999999999999'), throwsMoneyOverflow);
      expect(() => Money.parse('-92233720368547758.09'), throwsMoneyOverflow);
      expect(Money.parse('92233720368547758.07'), Money.max);
      expect(Money.parse('-92233720368547758.08'), Money.min);
    });

    test('huge pasted strings are rejected quickly', () {
      final huge = '9' * 100000;
      expect(() => Money.parse(huge), throwsMoneyOverflow);
      final hugeJunk = '💸' * 100000;
      expect(() => Money.parse(hugeJunk), throwsFormatException);
    });

    test('tryParse returns null instead of throwing', () {
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('99999999999999999999'), isNull);
      expect(Money.tryParse('12.34'), const Money.paise(1234));
    });
  });

  group('Money arithmetic', () {
    test('addition and subtraction', () {
      expect(
        const Money.paise(100) + const Money.paise(250),
        const Money.paise(350),
      );
      expect(
        const Money.paise(100) - const Money.paise(250),
        const Money.paise(-150),
      );
    });

    test('unary minus and abs', () {
      expect(-const Money.paise(100), const Money.paise(-100));
      expect(const Money.paise(-100).abs(), const Money.paise(100));
      expect(const Money.paise(100).abs(), const Money.paise(100));
    });

    test('multiplication by an integer factor', () {
      expect(const Money.paise(150) * 3, const Money.paise(450));
      expect(const Money.paise(150) * -1, const Money.paise(-150));
      expect(const Money.paise(150) * 0, Money.zero);
    });

    test('addition overflow throws instead of wrapping', () {
      expect(() => Money.max + const Money.paise(1), throwsMoneyOverflow);
      expect(() => Money.min + const Money.paise(-1), throwsMoneyOverflow);
      expect(Money.max + Money.zero, Money.max);
    });

    test('subtraction overflow throws instead of wrapping', () {
      expect(() => Money.min - const Money.paise(1), throwsMoneyOverflow);
      expect(() => Money.max - const Money.paise(-1), throwsMoneyOverflow);
    });

    test('negating min overflows', () {
      expect(() => -Money.min, throwsMoneyOverflow);
      expect(() => Money.min.abs(), throwsMoneyOverflow);
    });

    test('multiplication overflow throws instead of wrapping', () {
      expect(() => Money.max * 2, throwsMoneyOverflow);
      expect(() => Money.min * -1, throwsMoneyOverflow);
      expect(() => const Money.paise(1 << 40) * (1 << 40), throwsMoneyOverflow);
    });

    test('predicates', () {
      expect(const Money.paise(-1).isNegative, isTrue);
      expect(Money.zero.isNegative, isFalse);
      expect(Money.zero.isZero, isTrue);
      expect(const Money.paise(1).isPositive, isTrue);
      expect(Money.zero.isPositive, isFalse);
    });

    test('comparison operators and compareTo', () {
      const a = Money.paise(1);
      const b = Money.paise(2);
      expect(a < b, isTrue);
      expect(a <= b, isTrue);
      expect(b > a, isTrue);
      expect(b >= a, isTrue);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(const Money.paise(1)), 0);
      final sorted = [b, a, Money.zero]..sort();
      expect(sorted, [Money.zero, a, b]);
    });

    test('value equality and hashCode', () {
      expect(const Money.paise(5), const Money.paise(5));
      expect(const Money.paise(5).hashCode, const Money.paise(5).hashCode);
      expect(const Money.paise(5), isNot(const Money.paise(6)));
    });

    test('rupees getter is a display-only double', () {
      expect(const Money.paise(12345).rupees, 123.45);
      expect(const Money.paise(-50).rupees, -0.5);
    });
  });

  group('Money formatting (en_IN)', () {
    test('formats with lakh/crore grouping and two decimals', () {
      expect(const Money.paise(12345678).format(), '₹1,23,456.78');
    });

    test('formats small and zero values', () {
      expect(Money.zero.format(), '₹0.00');
      expect(const Money.paise(5).format(), '₹0.05');
      expect(const Money.paise(99900).format(), '₹999.00');
      expect(const Money.paise(100000).format(), '₹1,000.00');
    });

    test('formats negative values with a leading minus', () {
      expect(const Money.paise(-12345678).format(), '-₹1,23,456.78');
      expect(const Money.paise(-5).format(), '-₹0.05');
    });

    test('formats crores and the int64 extremes exactly', () {
      expect(const Money.paise(999999999999).format(), '₹9,99,99,99,999.99');
      expect(Money.max.format(), '₹92,23,37,20,36,85,47,758.07');
      expect(Money.min.format(), '-₹92,23,37,20,36,85,47,758.08');
    });

    test('showSign adds a plus for positive values', () {
      expect(const Money.paise(100).format(showSign: true), '+₹1.00');
      expect(const Money.paise(-100).format(showSign: true), '-₹1.00');
      expect(Money.zero.format(showSign: true), '₹0.00');
    });

    test('symbol can be omitted', () {
      expect(const Money.paise(12345678).format(symbol: false), '1,23,456.78');
      expect(const Money.paise(-100).format(symbol: false), '-1.00');
    });

    test('compact form uses K, L and Cr', () {
      expect(const Money.paise(12345600).formatCompact(), '₹1.23L');
      expect(const Money.paise(3400000000).formatCompact(), '₹3.4Cr');
      expect(const Money.paise(1500000).formatCompact(), '₹15K');
      expect(const Money.paise(99900).formatCompact(), '₹999');
      expect(const Money.paise(-12345600).formatCompact(), '-₹1.23L');
      expect(Money.zero.formatCompact(), '₹0');
    });

    test('format round-trips through parse', () {
      for (final paise in [0, 1, 99, 100, 12345678, -12345678, 999999999999]) {
        final money = Money.paise(paise);
        expect(Money.parse(money.format()), money);
      }
    });

    test('toString is the formatted value', () {
      expect(const Money.paise(12345678).toString(), '₹1,23,456.78');
    });
  });

  group('Money JSON', () {
    test('toJson is the integer paise', () {
      expect(const Money.paise(4321).toJson(), 4321);
    });

    test('fromJson accepts an int', () {
      expect(Money.fromJson(4321), const Money.paise(4321));
    });

    test('fromJson rejects doubles and strings', () {
      expect(() => Money.fromJson(43.21), throwsFormatException);
      expect(() => Money.fromJson('4321'), throwsFormatException);
      expect(() => Money.fromJson(null), throwsFormatException);
    });
  });
}

final Matcher throwsMoneyOverflow = throwsA(isA<MoneyOverflowException>());
