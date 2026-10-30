import 'dart:convert';
import 'dart:typed_data';

import 'package:fin_pay/core/auth/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hasher = PasswordHasher(iterations: 1000);

  group('PasswordHasher', () {
    test('PBKDF2-HMAC-SHA256 matches the RFC 6070 / known test vector', () {
      // PBKDF2-HMAC-SHA256("password", "salt", 1, 32)
      final out = PasswordHasher.pbkdf2(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 1,
        length: 32,
      );
      expect(
        _hex(out),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      final out4096 = PasswordHasher.pbkdf2(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 4096,
        length: 32,
      );
      expect(
        _hex(out4096),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('hash produces a fresh 16-byte salt every time', () {
      final a = hasher.hash('FinPay123');
      final b = hasher.hash('FinPay123');
      expect(base64Decode(a.salt).length, 16);
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(a.iterations, 1000);
    });

    test('verify accepts the right password and rejects others', () {
      final stored = hasher.hash('FinPay123');
      expect(hasher.verify('FinPay123', stored), isTrue);
      expect(hasher.verify('finpay123', stored), isFalse);
      expect(hasher.verify('FinPay1234', stored), isFalse);
      expect(hasher.verify('', stored), isFalse);
    });

    test('verify uses the iteration count stored with the hash', () {
      final stored = const PasswordHasher(iterations: 2000).hash('x');
      expect(hasher.verify('x', stored), isTrue);
    });

    test('unicode, emoji and RTL passwords round-trip', () {
      for (final password in ['पासवर्ड', '🔐🔑', '\u202eabc', 'ñ' * 500]) {
        final stored = hasher.hash(password);
        expect(hasher.verify(password, stored), isTrue, reason: password);
      }
    });

    test('a huge password is hashed without blowing up', () {
      final huge = 'a' * 100000;
      final stored = hasher.hash(huge);
      expect(hasher.verify(huge, stored), isTrue);
      expect(hasher.verify('a' * 99999, stored), isFalse);
    });

    test('constantTimeEquals compares lengths and bytes', () {
      expect(
        PasswordHasher.constantTimeEquals(
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([1, 2, 3]),
        ),
        isTrue,
      );
      expect(
        PasswordHasher.constantTimeEquals(
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([1, 2, 4]),
        ),
        isFalse,
      );
      expect(
        PasswordHasher.constantTimeEquals(
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([1, 2]),
        ),
        isFalse,
      );
    });

    test('HashedPassword JSON round-trip', () {
      final stored = hasher.hash('pw');
      final json = stored.toJson();
      expect(HashedPassword.fromJson(json), stored);
      expect(
        HashedPassword.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        ),
        stored,
      );
    });

    test('a corrupt stored record never verifies', () {
      const corrupt = HashedPassword(
        salt: 'not base64!!',
        hash: '',
        iterations: 1,
      );
      expect(hasher.verify('pw', corrupt), isFalse);
    });

    test('the default iteration count is 10,000', () {
      expect(const PasswordHasher().iterations, 10000);
    });
  });
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
