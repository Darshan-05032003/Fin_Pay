import 'package:fin_pay/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.validateEmail', () {
    test('accepts ordinary addresses and trims whitespace', () {
      expect(Validators.validateEmail('user@finpay.com'), isNull);
      expect(Validators.validateEmail('  user@finpay.com  '), isNull);
      expect(Validators.validateEmail('first.last+tag@sub.example.co'), isNull);
    });

    test('rejects empty, malformed and oversized input', () {
      expect(Validators.validateEmail(null), 'Email is required');
      expect(Validators.validateEmail(''), 'Email is required');
      expect(Validators.validateEmail('   '), 'Email is required');
      expect(Validators.validateEmail('user'), 'Enter a valid email address');
      expect(Validators.validateEmail('user@'), 'Enter a valid email address');
      expect(Validators.validateEmail('@x.com'), 'Enter a valid email address');
      expect(Validators.validateEmail('a@b'), 'Enter a valid email address');
      expect(
        Validators.validateEmail('${'a' * 250}@x.com'),
        'Enter a valid email address',
      );
    });

    test('rejects injection, control and bidi characters', () {
      for (final bad in [
        "' OR 1=1 --@x.com",
        'user\n@x.com',
        'user\u0000@x.com',
        'us‮er@x.com',
        'user@x.com;drop',
        '%s%n@x.com',
        'user@x.com<script>',
        '😀@x.com',
        'user@日本.com',
      ]) {
        expect(
          Validators.validateEmail(bad),
          'Enter a valid email address',
          reason: bad,
        );
      }
    });
  });

  group('Validators.validatePassword', () {
    test('requires 8 to 64 characters', () {
      expect(Validators.validatePassword(null), 'Password is required');
      expect(Validators.validatePassword(''), 'Password is required');
      expect(Validators.validatePassword('short'), 'Use at least 8 characters');
      expect(Validators.validatePassword('FinPay123'), isNull);
      expect(
        Validators.validatePassword('x' * 65),
        'Use at most 64 characters',
      );
      expect(Validators.validatePassword('x' * 64), isNull);
    });

    test('unicode passwords count code points, not bytes', () {
      expect(Validators.validatePassword('😀😀😀😀😀😀😀😀'), isNull);
      expect(
        Validators.validatePassword('😀' * 65),
        'Use at most 64 characters',
      );
    });
  });

  group('Validators.passwordStrength', () {
    test('scores length and character classes', () {
      expect(Validators.passwordStrength(''), PasswordStrength.none);
      expect(Validators.passwordStrength('abc'), PasswordStrength.weak);
      expect(Validators.passwordStrength('abcdefgh'), PasswordStrength.weak);
      expect(Validators.passwordStrength('abcdefg1'), PasswordStrength.fair);
      expect(Validators.passwordStrength('Abcdefg1'), PasswordStrength.good);
      expect(Validators.passwordStrength('Abcdefg1!'), PasswordStrength.strong);
      expect(
        Validators.passwordStrength('correct horse battery staple'),
        PasswordStrength.strong,
      );
    });

    test('is total and fast on hostile input', () {
      expect(Validators.passwordStrength('‮' * 10000), isA<PasswordStrength>());
      expect(Validators.passwordStrength('😀' * 100), isA<PasswordStrength>());
    });

    test('exposes a 0–4 score and a label', () {
      expect(PasswordStrength.none.score, 0);
      expect(PasswordStrength.strong.score, 4);
      expect(PasswordStrength.fair.label, 'Fair');
    });
  });

  group('Validators.validateName', () {
    test('accepts real names, trims and allows marks', () {
      expect(Validators.validateName('Aarav Mehta'), isNull);
      expect(Validators.validateName("  D'Souza-Rao  "), isNull);
      expect(Validators.validateName('José'), isNull);
      expect(Validators.validateName('राम'), isNull);
    });

    test('rejects empty, short, long and symbol names', () {
      expect(Validators.validateName(null), 'Name is required');
      expect(Validators.validateName(' '), 'Name is required');
      expect(Validators.validateName('A'), 'Use at least 2 characters');
      expect(Validators.validateName('a' * 61), 'Use at most 60 characters');
      expect(Validators.validateName('Bob<script>'), 'Use letters only');
      expect(Validators.validateName('123'), 'Use letters only');
      expect(Validators.validateName('😀😀'), 'Use letters only');
      expect(Validators.validateName('a‮b'), 'Use letters only');
    });
  });

  group('Validators.validatePhone', () {
    test('accepts 10-digit Indian mobiles with common formatting', () {
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('+91 98765 43210'), isNull);
      expect(Validators.validatePhone('098765-43210'), isNull);
      expect(Validators.validatePhone('(987) 654 3210'), isNull);
    });

    test('rejects empty, short, long and non-numeric input', () {
      expect(Validators.validatePhone(null), 'Phone number is required');
      expect(Validators.validatePhone(''), 'Phone number is required');
      expect(
        Validators.validatePhone('12345'),
        'Enter a 10-digit mobile number',
      );
      expect(
        Validators.validatePhone('1234567890123'),
        'Enter a 10-digit mobile number',
      );
      expect(
        Validators.validatePhone('abcdefghij'),
        'Enter a 10-digit mobile number',
      );
      expect(
        Validators.validatePhone('٩٨٧٦٥٤٣٢١٠'),
        'Enter a 10-digit mobile number',
      );
      expect(
        Validators.validatePhone('1234567890'),
        'Enter a 10-digit mobile number',
      );
    });

    test('normalizePhone keeps the national 10 digits', () {
      expect(Validators.normalizePhone('+91 98765 43210'), '9876543210');
      expect(Validators.normalizePhone('098765-43210'), '9876543210');
      expect(Validators.normalizePhone('9876543210'), '9876543210');
      expect(Validators.normalizePhone('abc'), '');
    });
  });
}
