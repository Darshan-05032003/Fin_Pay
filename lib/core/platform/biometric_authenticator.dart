import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of a biometric prompt.
enum BiometricResult {
  /// The user was recognised.
  success,

  /// The user cancelled or was not recognised.
  failed,

  /// No biometric hardware, or it is disabled.
  notAvailable,

  /// Hardware exists but nothing is enrolled.
  notEnrolled,

  /// Too many failed attempts; the OS locked biometrics out.
  lockedOut,

  /// Any other platform error.
  error,
}

/// Device biometrics behind an interface so screens can be tested with
/// `FakeBiometricAuthenticator`.
abstract interface class BiometricAuthenticator {
  /// True when the device can prompt for a fingerprint/face right now.
  Future<bool> isAvailable();

  /// Shows the system prompt with [reason] and reports the outcome.
  Future<BiometricResult> authenticate({required String reason});
}

/// [BiometricAuthenticator] on `local_auth`.
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? localAuth])
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      if (!await _localAuth.canCheckBiometrics) return false;
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      return mapErrorCode(e.code);
    } on MissingPluginException {
      return BiometricResult.notAvailable;
    }
  }

  /// Maps `local_auth` error codes to [BiometricResult].
  static BiometricResult mapErrorCode(String code) => switch (code) {
    'NotAvailable' || 'PasscodeNotSet' => BiometricResult.notAvailable,
    'NotEnrolled' => BiometricResult.notEnrolled,
    'LockedOut' || 'PermanentlyLockedOut' => BiometricResult.lockedOut,
    _ => BiometricResult.error,
  };
}
