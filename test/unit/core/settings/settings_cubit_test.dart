import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySettingsRepository repo;

  setUp(() {
    repo = InMemorySettingsRepository();
    Logger.sink = (_) {};
  });

  group('AppSettings', () {
    test('defaults, copyWith and JSON', () {
      expect(AppSettings.defaults.hapticsEnabled, isTrue);
      expect(AppSettings.defaults.reduceMotion, isFalse);
      expect(AppSettings.defaults.hideBalance, isFalse);
      expect(AppSettings.defaults.onboardingSeen, isFalse);
      expect(AppSettings.defaults.biometricEnabled, isFalse);
      const changed = AppSettings(reduceMotion: true);
      expect(AppSettings.fromJson(changed.toJson()), changed);
      expect(AppSettings.fromJson(const {}), AppSettings.defaults);
      expect(changed.copyWith(hideBalance: true).hideBalance, isTrue);
      const flags = AppSettings(onboardingSeen: true, biometricEnabled: true);
      expect(AppSettings.fromJson(flags.toJson()), flags);
      expect(flags.copyWith(biometricEnabled: false).biometricEnabled, isFalse);
      expect(flags.copyWith(onboardingSeen: false).onboardingSeen, isFalse);
    });
  });

  group('SettingsCubit', () {
    test('initial state is defaults, not loaded', () {
      final cubit = SettingsCubit(repo);
      expect(cubit.state.settings, AppSettings.defaults);
      expect(cubit.state.loaded, isFalse);
    });

    blocTest<SettingsCubit, SettingsState>(
      'load reads persisted settings',
      build: () {
        repo.settings = const AppSettings(hapticsEnabled: false);
        return SettingsCubit(repo);
      },
      act: (c) => c.load(),
      expect: () => const [
        SettingsState(
          settings: AppSettings(hapticsEnabled: false),
          loaded: true,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggles emit optimistically and persist',
      build: () => SettingsCubit(repo),
      act: (c) async {
        await c.setHapticsEnabled(enabled: false);
        await c.setReduceMotion(enabled: true);
        await c.toggleHideBalance();
      },
      expect: () => const [
        SettingsState(settings: AppSettings(hapticsEnabled: false)),
        SettingsState(
          settings: AppSettings(hapticsEnabled: false, reduceMotion: true),
        ),
        SettingsState(
          settings: AppSettings(
            hapticsEnabled: false,
            reduceMotion: true,
            hideBalance: true,
          ),
        ),
      ],
      verify: (_) {
        expect(repo.saves, 3);
        expect(repo.settings.hideBalance, isTrue);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'onboarding seen and biometric preference persist',
      build: () => SettingsCubit(repo),
      act: (c) async {
        await c.setOnboardingSeen(seen: true);
        await c.setBiometricEnabled(enabled: true);
      },
      expect: () => const [
        SettingsState(settings: AppSettings(onboardingSeen: true)),
        SettingsState(
          settings: AppSettings(onboardingSeen: true, biometricEnabled: true),
        ),
      ],
      verify: (c) {
        expect(repo.settings.onboardingSeen, isTrue);
        expect(repo.settings.biometricEnabled, isTrue);
        expect(c.state.onboardingSeen, isTrue);
        expect(c.state.biometricEnabled, isTrue);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'setting the same value again emits nothing',
      build: () => SettingsCubit(repo),
      act: (c) => c.setHapticsEnabled(enabled: true),
      expect: () => const <SettingsState>[],
      verify: (_) => expect(repo.saves, 0),
    );

    blocTest<SettingsCubit, SettingsState>(
      'a failed save rolls back to the previous state',
      build: () {
        repo.failing = true;
        return SettingsCubit(repo);
      },
      act: (c) => c.setReduceMotion(enabled: true),
      expect: () => const [
        SettingsState(settings: AppSettings(reduceMotion: true)),
        SettingsState(settings: AppSettings.defaults),
      ],
    );
  });
}
