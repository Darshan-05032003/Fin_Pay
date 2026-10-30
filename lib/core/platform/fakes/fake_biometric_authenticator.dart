import 'package:fin_pay/core/platform/biometric_authenticator.dart';

/// Scriptable [BiometricAuthenticator] for tests.
class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({
    this.available = true,
    this.result = BiometricResult.success,
  });

  bool available;
  BiometricResult result;

  /// Reasons passed to [authenticate], in order.
  final List<String> prompts = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    prompts.add(reason);
    return available ? result : BiometricResult.notAvailable;
  }
}
