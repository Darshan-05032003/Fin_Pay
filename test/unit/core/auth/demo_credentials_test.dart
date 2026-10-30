import 'dart:io';

import 'package:fin_pay/core/auth/demo_credentials.dart';
import 'package:fin_pay/core/auth/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoCredentials', () {
    test('the precomputed hash verifies the documented demo password', () {
      const hasher = PasswordHasher();
      expect(hasher.verify('FinPay123', DemoCredentials.hashed), isTrue);
      expect(hasher.verify('finpay123', DemoCredentials.hashed), isFalse);
      expect(DemoCredentials.hashed.iterations, 10000);
    });

    test('no plaintext secret or password assignment exists under lib/', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'run from the package root');
      final pattern = RegExp(
        r"api_key|apikey|secret|AIza|password\s*=\s*'",
        caseSensitive: false,
      );
      final offenders = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('FinPay123') || pattern.hasMatch(line)) {
            // Words such as "secrets" in comments about secure storage are
            // allowed; only identifiers and literals are flagged.
            final code = line.split('//').first;
            if (code.contains('FinPay123') || pattern.hasMatch(code)) {
              offenders.add('${entity.path}:${i + 1}: $line');
            }
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
