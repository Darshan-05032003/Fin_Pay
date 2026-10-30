import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';

/// Credentials and session persistence.
///
/// Passwords are never stored or returned; only salted hashes live in
/// secure storage, and lockout state is tracked per email.
abstract interface class AuthRepository {
  /// Verifies [email]/[password] and, on success, persists the session.
  Future<AuthResult> signIn({required String email, required String password});

  /// Stores a new salted hash for [email] (registration / password change).
  Future<Result<void>> setCredentials({
    required String email,
    required String password,
  });

  /// Seeds the demo credentials and user row on first run. Idempotent.
  Future<Result<void>> ensureDemoAccount();

  /// The user id of the persisted session, or null.
  Future<String?> restoreSession();

  /// Clears the persisted session.
  Future<void> signOut();
}
