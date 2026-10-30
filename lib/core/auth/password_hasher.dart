import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// A salted PBKDF2-HMAC-SHA256 digest, stored as base64 strings.
class HashedPassword extends Equatable {
  const HashedPassword({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  factory HashedPassword.fromJson(Map<String, dynamic> json) => HashedPassword(
    salt: json['salt'] as String,
    hash: json['hash'] as String,
    iterations: json['iterations'] as int,
  );

  final String salt;
  final String hash;
  final int iterations;

  Map<String, dynamic> toJson() => {
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
  };

  @override
  List<Object?> get props => [salt, hash, iterations];
}

/// Derives and verifies password hashes with PBKDF2-HMAC-SHA256.
///
/// Defaults: 10,000 iterations, a 16-byte random salt and a 32-byte digest,
/// compared in constant time. Pure Dart via `package:crypto`, so it runs the
/// same on every platform and in tests.
class PasswordHasher {
  const PasswordHasher({this.iterations = defaultIterations, Random? random})
    : _random = random;

  /// The iteration count used for new hashes.
  static const int defaultIterations = 10000;

  /// Salt length in bytes for new hashes.
  static const int saltLength = 16;

  /// Digest length in bytes.
  static const int hashLength = 32;

  final int iterations;
  final Random? _random;

  /// Hashes [password] with a fresh random salt.
  HashedPassword hash(String password) {
    final random = _random ?? Random.secure();
    final salt = Uint8List.fromList(
      List.generate(saltLength, (_) => random.nextInt(256)),
    );
    final digest = pbkdf2(
      password: utf8.encode(password),
      salt: salt,
      iterations: iterations,
      length: hashLength,
    );
    return HashedPassword(
      salt: base64Encode(salt),
      hash: base64Encode(digest),
      iterations: iterations,
    );
  }

  /// True when [password] produces [stored]'s digest. A corrupt record
  /// (bad base64, zero iterations) is simply a mismatch.
  bool verify(String password, HashedPassword stored) {
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Decode(stored.salt);
      expected = base64Decode(stored.hash);
    } on FormatException {
      return false;
    }
    if (stored.iterations < 1 || expected.isEmpty) return false;
    final actual = pbkdf2(
      password: utf8.encode(password),
      salt: salt,
      iterations: stored.iterations,
      length: expected.length,
    );
    return constantTimeEquals(actual, expected);
  }

  /// PBKDF2 with HMAC-SHA256 as the PRF (RFC 8018 §5.2).
  static Uint8List pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int length,
  }) {
    final prf = Hmac(sha256, password);
    final blockCount = (length / 32).ceil();
    final output = Uint8List(blockCount * 32);
    for (var block = 1; block <= blockCount; block++) {
      final blockIndex = Uint8List(4)..buffer.asByteData().setUint32(0, block);
      var u = Uint8List.fromList(prf.convert([...salt, ...blockIndex]).bytes);
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(prf.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.setRange((block - 1) * 32, block * 32, t);
    }
    return Uint8List.sublistView(output, 0, length);
  }

  /// Compares two byte strings without short-circuiting on the first
  /// mismatch, so timing does not leak how many leading bytes matched.
  static bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
