import 'package:fin_pay/core/auth/password_hasher.dart';
import 'package:fin_pay/core/money/money.dart';

/// The demo account that is seeded on first run.
///
/// Only the PBKDF2-HMAC-SHA256 digest lives in source; the plaintext
/// password is documented in the README (and asserted by a test) so it
/// never appears under `lib/`.
abstract final class DemoCredentials {
  static const String email = 'user@finpay.com';
  static const String fullName = 'John Doe';
  static const String userId = 'default_user_001';

  /// ₹56,246.90 opening balance.
  static const Money openingBalance = Money.paise(5624690);

  /// Precomputed with `PasswordHasher()` (10,000 iterations, 16-byte salt).
  static const HashedPassword hashed = HashedPassword(
    salt: 'v3U131zZSRs5dJ9t9PGwqA==',
    hash: 'Og8pIyOhYjtO2Zoq8fkb1ynFmCWO2oWGjLD6dapqIrg=',
    iterations: 10000,
  );
}
