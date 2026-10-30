import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for [AppSettings].
abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// [SettingsRepository] on `shared_preferences`.
class SharedPreferencesSettingsRepository implements SettingsRepository {
  SharedPreferencesSettingsRepository([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String _haptics = 'settings.hapticsEnabled';
  static const String _reduceMotion = 'settings.reduceMotion';
  static const String _hideBalance = 'settings.hideBalance';
  static const String _onboardingSeen = 'settings.onboardingSeen';
  static const String _biometricEnabled = 'settings.biometricEnabled';

  @override
  Future<AppSettings> load() async {
    try {
      return AppSettings(
        hapticsEnabled: await _prefs.getBool(_haptics) ?? true,
        reduceMotion: await _prefs.getBool(_reduceMotion) ?? false,
        hideBalance: await _prefs.getBool(_hideBalance) ?? false,
        onboardingSeen: await _prefs.getBool(_onboardingSeen) ?? false,
        biometricEnabled: await _prefs.getBool(_biometricEnabled) ?? false,
      );
    } on Exception {
      return AppSettings.defaults;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_haptics, settings.hapticsEnabled);
    await _prefs.setBool(_reduceMotion, settings.reduceMotion);
    await _prefs.setBool(_hideBalance, settings.hideBalance);
    await _prefs.setBool(_onboardingSeen, settings.onboardingSeen);
    await _prefs.setBool(_biometricEnabled, settings.biometricEnabled);
  }
}

/// In-memory [SettingsRepository] for tests.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this.settings = AppSettings.defaults]);

  AppSettings settings;

  /// When true, [save] throws.
  bool failing = false;

  int saves = 0;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    if (failing) throw Exception('disk full');
    saves++;
    this.settings = settings;
  }
}
