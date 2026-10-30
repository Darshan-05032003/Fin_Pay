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
      const changed = AppSettings(reduceMotion: true);
      expect(AppSettings.fromJson(changed.toJson()), changed);
      expect(AppSettings.fromJson(const {}), AppSettings.defaults);
      expect(changed.copyWith(hideBalance: true).hideBalance, isTrue);
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
