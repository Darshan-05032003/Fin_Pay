import 'dart:math';

import 'package:fin_pay/screens/auth/verification/otp_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = OtpState();

  group('OtpMachine.sanitize', () {
    test('keeps only ASCII digits, at most six', () {
      expect(OtpMachine.sanitize('123456'), '123456');
      expect(OtpMachine.sanitize('12 34-56'), '123456');
      expect(OtpMachine.sanitize('Your code is 987654!'), '987654');
      expect(OtpMachine.sanitize('1234567890'), '123456');
      expect(OtpMachine.sanitize('abc'), '');
      expect(OtpMachine.sanitize('١٢٣٤٥٦'), '');
      expect(OtpMachine.sanitize('😀1‮2\u00003'), '123');
      expect(OtpMachine.sanitize(''), '');
    });
  });

  group('OtpMachine.input (the hidden field hands over its whole text)', () {
    test('auto-advances: the active cell follows the typed digits', () {
      var s = OtpMachine.input(start, '1');
      expect(s.digits, '1');
      expect(s.activeIndex, 1);
      s = OtpMachine.input(s, '12');
      expect(s.activeIndex, 2);
      expect(s.complete, isFalse);
      s = OtpMachine.input(s, '123456');
      expect(s.complete, isTrue);
      expect(s.activeIndex, 5);
      expect(s.phase, OtpPhase.entering);
    });

    test('paste fills every cell and strips junk', () {
      final s = OtpMachine.input(start, 'code: 24-68-10 ok');
      expect(s.digits, '246810');
      expect(s.complete, isTrue);
    });

    test('never exceeds six digits', () {
      final s = OtpMachine.input(start, '1234567890123');
      expect(s.digits.length, 6);
    });

    test('typing after a wrong code returns to entering', () {
      final wrong = OtpMachine.verify(
        OtpMachine.input(start, '000000'),
        '123456',
      );
      expect(wrong.phase, OtpPhase.wrong);
      expect(wrong.digits, isEmpty);
      final again = OtpMachine.input(wrong, '1');
      expect(again.phase, OtpPhase.entering);
      expect(again.digits, '1');
    });

    test('ignores input while locked, verifying or verified', () {
      for (final phase in [
        OtpPhase.locked,
        OtpPhase.verifying,
        OtpPhase.verified,
      ]) {
        final s = OtpMachine.input(start.copyWith(phase: phase), '1');
        expect(s.digits, isEmpty, reason: phase.name);
        expect(s.phase, phase);
      }
    });
  });

  group('OtpMachine.backspace', () {
    test('moves back one cell', () {
      var s = OtpMachine.input(start, '123');
      s = OtpMachine.backspace(s);
      expect(s.digits, '12');
      expect(s.activeIndex, 2);
      s = OtpMachine.backspace(OtpMachine.backspace(s));
      expect(s.digits, isEmpty);
      expect(OtpMachine.backspace(s).digits, isEmpty);
    });
  });

  group('OtpMachine.verify', () {
    test('a correct code verifies and keeps the digits', () {
      final s = OtpMachine.verify(OtpMachine.input(start, '123456'), '123456');
      expect(s.phase, OtpPhase.verified);
      expect(s.digits, '123456');
    });

    test('an incomplete code is not an attempt', () {
      final s = OtpMachine.verify(OtpMachine.input(start, '123'), '123456');
      expect(s.phase, OtpPhase.entering);
      expect(s.attempts, 0);
    });

    test('a wrong code counts an attempt and clears the digits', () {
      final s = OtpMachine.verify(OtpMachine.input(start, '654321'), '123456');
      expect(s.phase, OtpPhase.wrong);
      expect(s.attempts, 1);
      expect(s.remainingAttempts, OtpState.maxAttempts - 1);
      expect(s.digits, isEmpty);
    });

    test('the fifth wrong code locks the flow', () {
      var s = start;
      for (var i = 1; i <= OtpState.maxAttempts; i++) {
        s = OtpMachine.verify(OtpMachine.input(s, '000000'), '123456');
        expect(s.attempts, i);
      }
      expect(s.phase, OtpPhase.locked);
      expect(s.remainingAttempts, 0);
      // Locked stays locked: input and verify are no-ops.
      expect(OtpMachine.input(s, '123456').digits, isEmpty);
      expect(OtpMachine.verify(s, '123456').phase, OtpPhase.locked);
    });

    test('comparison is constant-time safe for unequal lengths', () {
      expect(OtpMachine.codesMatch('123456', '123456'), isTrue);
      expect(OtpMachine.codesMatch('123456', '12345'), isFalse);
      expect(OtpMachine.codesMatch('', ''), isFalse);
      expect(OtpMachine.codesMatch('123456', '123457'), isFalse);
    });
  });

  group('OtpMachine.resend', () {
    test('clears the digits and a wrong phase, keeps attempts', () {
      final wrong = OtpMachine.verify(
        OtpMachine.input(start, '000000'),
        '123456',
      );
      final s = OtpMachine.resend(wrong);
      expect(s.phase, OtpPhase.entering);
      expect(s.digits, isEmpty);
      expect(s.attempts, 1);
      expect(s.resends, 1);
    });

    test('is a no-op when locked or verified', () {
      expect(
        OtpMachine.resend(start.copyWith(phase: OtpPhase.locked)).resends,
        0,
      );
      expect(
        OtpMachine.resend(start.copyWith(phase: OtpPhase.verified)).resends,
        0,
      );
    });
  });

  test('10,000 random inputs never throw and never exceed six digits', () {
    final rng = Random(7);
    const alphabet = '0123456789abc 😀‮\u0000-+()٣٤日本\n\t<>;\'"%\$';
    final runes = alphabet.runes.toList();
    var s = start;
    for (var i = 0; i < 10000; i++) {
      final len = rng.nextInt(40);
      final raw = String.fromCharCodes(
        List.generate(len, (_) => runes[rng.nextInt(runes.length)]),
      );
      s = switch (rng.nextInt(5)) {
        0 => OtpMachine.backspace(s),
        1 => OtpMachine.verify(s, '123456'),
        2 => OtpMachine.resend(s),
        _ => OtpMachine.input(s, raw),
      };
      expect(s.digits.length, lessThanOrEqualTo(OtpState.length));
      expect(s.attempts, lessThanOrEqualTo(OtpState.maxAttempts));
      expect(s.activeIndex, inInclusiveRange(0, OtpState.length - 1));
    }
  });
}
