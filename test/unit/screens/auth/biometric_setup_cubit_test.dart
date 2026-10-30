import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/core/platform/biometric_authenticator.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/screens/auth/fingerprint/biometric_setup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeBiometricAuthenticator biometrics;
  late InMemorySettingsRepository repo;
  late SettingsCubit settings;

  setUp(() {
    biometrics = FakeBiometricAuthenticator();
    repo = InMemorySettingsRepository();
    settings = SettingsCubit(repo);
  });

  tearDown(() => settings.close());

  BiometricSetupCubit build() =>
      BiometricSetupCubit(biometrics: biometrics, settings: settings);

  blocTest<BiometricSetupCubit, BiometricSetupState>(
    'check: available → ready',
    build: build,
    act: (c) => c.check(),
    expect: () => const [BiometricSetupState(phase: BiometricPhase.ready)],
  );

  blocTest<BiometricSetupCubit, BiometricSetupState>(
    'check: not available → unavailable with a message',
    build: () {
      biometrics.available = false;
      return build();
    },
    act: (c) => c.check(),
    expect: () => const [
      BiometricSetupState(
        phase: BiometricPhase.unavailable,
        result: BiometricResult.notAvailable,
      ),
    ],
    verify: (c) => expect(c.state.message, contains('not available')),
  );

  blocTest<BiometricSetupCubit, BiometricSetupState>(
    'authenticate: success persists the preference',
    build: build,
    act: (c) async {
      await c.check();
      await c.authenticate();
    },
    skip: 1,
    expect: () => const [
      BiometricSetupState(phase: BiometricPhase.scanning),
      BiometricSetupState(
        phase: BiometricPhase.success,
        result: BiometricResult.success,
        attempts: 1,
      ),
    ],
    verify: (_) {
      expect(repo.settings.biometricEnabled, isTrue);
      expect(biometrics.prompts, ['Confirm your fingerprint to set up FinPay']);
    },
  );

  for (final (result, phase, snippet) in [
    (BiometricResult.failed, BiometricPhase.failed, 'Not recognised'),
    (BiometricResult.lockedOut, BiometricPhase.failed, 'locked'),
    (BiometricResult.error, BiometricPhase.failed, 'went wrong'),
    (BiometricResult.notEnrolled, BiometricPhase.unavailable, 'enrolled'),
    (BiometricResult.notAvailable, BiometricPhase.unavailable, 'not available'),
  ]) {
    blocTest<BiometricSetupCubit, BiometricSetupState>(
      'authenticate: ${result.name} → ${phase.name}',
      build: () {
        biometrics.result = result;
        return build();
      },
      act: (c) async {
        await c.check();
        await c.authenticate();
      },
      verify: (c) {
        expect(c.state.phase, phase);
        expect(c.state.result, result);
        expect(c.state.message, contains(snippet));
        expect(repo.settings.biometricEnabled, isFalse);
      },
    );
  }

  blocTest<BiometricSetupCubit, BiometricSetupState>(
    'a failed attempt can be retried',
    build: () {
      biometrics.result = BiometricResult.failed;
      return build();
    },
    act: (c) async {
      await c.check();
      await c.authenticate();
      biometrics.result = BiometricResult.success;
      await c.authenticate();
    },
    verify: (c) {
      expect(c.state.phase, BiometricPhase.success);
      expect(c.state.attempts, 2);
      expect(biometrics.prompts.length, 2);
    },
  );

  test('concurrent authenticate calls prompt once', () async {
    final cubit = build();
    await cubit.check();
    await Future.wait([cubit.authenticate(), cubit.authenticate()]);
    expect(biometrics.prompts.length, 1);
    await cubit.close();
  });

  test('authenticate after success or while unavailable is ignored', () async {
    final cubit = build();
    await cubit.check();
    await cubit.authenticate();
    await cubit.authenticate();
    expect(biometrics.prompts.length, 1);
    biometrics.available = false;
    final other = build();
    await other.check();
    await other.authenticate();
    expect(biometrics.prompts.length, 1);
    await cubit.close();
    await other.close();
  });

  blocTest<BiometricSetupCubit, BiometricSetupState>(
    'skip records the choice',
    build: build,
    act: (c) => c.skip(),
    expect: () => const [BiometricSetupState(phase: BiometricPhase.skipped)],
    verify: (_) => expect(repo.settings.biometricEnabled, isFalse),
  );
}
