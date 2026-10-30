import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fin_pay/core/auth/demo_credentials.dart';
import 'package:fin_pay/core/auth/password_hasher.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/storage/secure_storage.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';

/// Lockout tuning for [AuthRepositoryImpl].
class LockoutPolicy {
  const LockoutPolicy({
    this.maxAttempts = 5,
    this.lockDuration = const Duration(seconds: 30),
  });

  /// Failures allowed before the account locks.
  final int maxAttempts;

  /// How long the lock lasts once triggered.
  final Duration lockDuration;
}

/// [AuthRepository] over [SecureStorage]: salted PBKDF2 hashes keyed by
/// normalised email, a persisted session marker and per-email lockout state.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required SecureStorage storage,
    required IUserRepository users,
    PasswordHasher hasher = const PasswordHasher(),
    Clock clock = const Clock(),
    LockoutPolicy policy = const LockoutPolicy(),
  }) : _storage = storage,
       _users = users,
       _hasher = hasher,
       _clock = clock,
       _policy = policy;

  final SecureStorage _storage;
  final IUserRepository _users;
  final PasswordHasher _hasher;
  final Clock _clock;
  final LockoutPolicy _policy;

  /// Secure-storage key of the credential record for [email].
  static String credentialKey(String email) => 'cred:${normalizeEmail(email)}';

  /// Secure-storage key of the lockout record for [email].
  static String lockoutKey(String email) => 'lock:${normalizeEmail(email)}';

  /// Secure-storage key of the session marker.
  static const String sessionKey = 'session:userId';

  /// Trims, lower-cases and strips bidi/zero-width characters.
  static String normalizeEmail(String email) =>
      email.replaceAll(_invisible, '').trim().toLowerCase();

  static final RegExp _invisible = RegExp(
    r'[\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]',
  );

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final now = _clock.now();
    try {
      final lock = await _readLockout(email);
      if (lock.lockedUntil != null && lock.lockedUntil!.isAfter(now)) {
        return AuthFailed(
          AccountLocked(
            until: lock.lockedUntil!,
            remaining: lock.lockedUntil!.difference(now),
          ),
        );
      }
      // An expired lock resets the counter.
      final failures = lock.lockedUntil == null ? lock.failures : 0;

      final stored = await _readCredentials(email);
      final verified = stored != null && _hasher.verify(password, stored);
      if (!verified) {
        final nextFailures = failures + 1;
        if (nextFailures >= _policy.maxAttempts) {
          final until = now.add(_policy.lockDuration);
          await _writeLockout(email, _Lockout(0, until));
          return AuthFailed(
            AccountLocked(until: until, remaining: _policy.lockDuration),
          );
        }
        await _writeLockout(email, _Lockout(nextFailures, null));
        return AuthFailed(
          InvalidCredentials(
            remainingAttempts: _policy.maxAttempts - nextFailures,
          ),
        );
      }

      await _storage.delete(lockoutKey(email));
      final userResult = await _users.getCurrentUser();
      return switch (userResult) {
        Success(data: final user) when user != null => await _startSession(
          user,
        ),
        Success() => const AuthFailed(
          CredentialStoreUnavailable('no user record'),
        ),
        Failure(message: final m) => AuthFailed(CredentialStoreUnavailable(m)),
      };
    } on SecureStorageException catch (e) {
      return AuthFailed(CredentialStoreUnavailable(e.message));
    }
  }

  Future<AuthResult> _startSession(User user) async {
    await _storage.write(sessionKey, user.id);
    return AuthSuccess(user);
  }

  static HashedPassword? _parseHashed(Object? json) {
    if (json case {
      'salt': final String salt,
      'hash': final String hash,
      'iterations': final int iterations,
    }) {
      return HashedPassword(salt: salt, hash: hash, iterations: iterations);
    }
    return null;
  }

  @override
  Future<Result<void>> setCredentials({
    required String email,
    required String password,
  }) async {
    try {
      await _storage.write(
        credentialKey(email),
        jsonEncode(_hasher.hash(password).toJson()),
      );
      return const Success(null);
    } on SecureStorageException catch (e) {
      return Failure('Could not store credentials', e);
    }
  }

  @override
  Future<Result<void>> ensureDemoAccount() async {
    try {
      final key = credentialKey(DemoCredentials.email);
      if (!await _storage.containsKey(key)) {
        await _storage.write(key, jsonEncode(DemoCredentials.hashed.toJson()));
      }
    } on SecureStorageException catch (e) {
      return Failure('Could not seed demo credentials', e);
    }
    final existing = await _users.getCurrentUser();
    return await existing.flatMapAsync((user) async {
      if (user != null) return const Success(null);
      return await _users.saveUser(
        User(
          id: DemoCredentials.userId,
          fullName: DemoCredentials.fullName,
          email: DemoCredentials.email,
          balance: DemoCredentials.openingBalance,
          createdAt: _clock.now(),
        ),
      );
    });
  }

  @override
  Future<String?> restoreSession() async {
    try {
      final id = await _storage.read(sessionKey);
      if (id == null) return null;
      // A session is only valid while its user row exists.
      final user = await _users.getCurrentUser();
      return switch (user) {
        Success(data: final u) when u != null && u.id == id => id,
        _ => null,
      };
    } on SecureStorageException {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _storage.delete(sessionKey);
    } on SecureStorageException {
      // Nothing persisted to clear.
    }
  }

  Future<HashedPassword?> _readCredentials(String email) async {
    final raw = await _storage.read(credentialKey(email));
    if (raw == null) return null;
    try {
      return _parseHashed(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<_Lockout> _readLockout(String email) async {
    final raw = await _storage.read(lockoutKey(email));
    if (raw == null) return const _Lockout(0, null);
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const _Lockout(0, null);
      final failures = json['failures'];
      final until = json['until'];
      return _Lockout(
        failures is int ? failures : 0,
        until is String ? DateTime.tryParse(until) : null,
      );
    } on FormatException {
      return const _Lockout(0, null);
    }
  }

  Future<void> _writeLockout(String email, _Lockout lock) => _storage.write(
    lockoutKey(email),
    jsonEncode({
      'failures': lock.failures,
      'until': lock.lockedUntil?.toUtc().toIso8601String(),
    }),
  );
}

class _Lockout {
  const _Lockout(this.failures, this.lockedUntil);

  final int failures;
  final DateTime? lockedUntil;
}
