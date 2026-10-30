import 'package:fin_pay/core/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> lines;

  setUp(() {
    lines = [];
    Logger.sink = lines.add;
    Logger.forceSilent = false;
  });

  tearDown(() {
    Logger.forceSilent = false;
  });

  group('Logger levels', () {
    test('every level writes to the sink in debug mode', () {
      Logger.debug('d');
      Logger.info('i');
      Logger.warning('w');
      Logger.error('e', Exception('boom'), StackTrace.current);
      expect(lines, hasLength(6));
      expect(lines[0], '[DEBUG] d');
      expect(lines[1], '[INFO] i');
      expect(lines[2], '[WARNING] w');
      expect(lines[3], '[ERROR] e');
      expect(lines[4], contains('boom'));
      expect(lines[5], startsWith('[STACK]'));
    });

    test('every level is silent in release mode', () {
      Logger.forceSilent = true;
      Logger.debug('d');
      Logger.info('i');
      Logger.warning('w');
      Logger.error('e', Exception('boom'));
      expect(lines, isEmpty);
    });
  });

  group('Logger.redact', () {
    test('masks card numbers with spaces, dashes or none, keeping last 4', () {
      expect(
        Logger.redact('card 4111 1111 1111 1111 saved'),
        'card **** **** **** 1111 saved',
      );
      expect(
        Logger.redact('card 5555-5555-5555-4444 saved'),
        'card **** **** **** 4444 saved',
      );
      expect(
        Logger.redact('card 4111111111111111 saved'),
        'card **** **** **** 1111 saved',
      );
      expect(Logger.redact('amex 378282246310005'), 'amex **** **** **** 0005');
    });

    test('leaves amounts, ids and non-Luhn digit runs alone', () {
      expect(Logger.redact('amount 12345678 paise'), 'amount 12345678 paise');
      expect(Logger.redact('id 1730000000000'), 'id 1730000000000');
      expect(Logger.redact('ref 4111111111111234'), 'ref 4111111111111234');
      expect(Logger.passesLuhn('4111111111111111'), isTrue);
      expect(Logger.passesLuhn('4111111111111112'), isFalse);
      expect(Logger.passesLuhn(''), isFalse);
    });

    test('masks CVVs', () {
      expect(Logger.redact('cvv: 123'), 'cvv: ***');
      expect(Logger.redact('CVV=9876'), 'CVV=***');
      expect(Logger.redact('{"cvv":"123"}'), '{"cvv":"***"}');
    });

    test('masks passwords, pins, otps and tokens', () {
      expect(Logger.redact('password: FinPay123'), 'password: [REDACTED]');
      expect(Logger.redact("password='hunter2'"), 'password=[REDACTED]');
      expect(Logger.redact('{"password":"x y"}'), '{"password":[REDACTED]}');
      expect(
        Logger.redact('pin=1234 otp: 999999'),
        'pin=[REDACTED] otp: [REDACTED]',
      );
      expect(Logger.redact('token: abc.def'), 'token: [REDACTED]');
    });

    test('redaction applies to messages and error details', () {
      Logger.error('saving 4111 1111 1111 1111', Exception('cvv: 123'));
      expect(lines[0], '[ERROR] saving **** **** **** 1111');
      expect(lines[1], '[ERROR DETAIL] Exception: cvv: ***');
    });
  });
}
