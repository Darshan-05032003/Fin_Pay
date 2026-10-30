import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/core/settings/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State of [SettingsCubit]: the current settings and whether they have
/// been read from disk yet.
class SettingsState extends Equatable {
  const SettingsState({required this.settings, this.loaded = false});

  final AppSettings settings;
  final bool loaded;

  bool get hapticsEnabled => settings.hapticsEnabled;
  bool get reduceMotion => settings.reduceMotion;
  bool get hideBalance => settings.hideBalance;

  @override
  List<Object?> get props => [settings, loaded];
}

/// Loads, exposes and persists [AppSettings].
///
/// Toggles update the state immediately (optimistic) and persist in the
/// background; a failed save is logged and the previous value restored.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository)
    : super(const SettingsState(settings: AppSettings.defaults));

  final SettingsRepository _repository;

  Future<void> load() async {
    final settings = await _repository.load();
    emit(SettingsState(settings: settings, loaded: true));
  }

  Future<void> setHapticsEnabled({required bool enabled}) =>
      _update(state.settings.copyWith(hapticsEnabled: enabled));

  Future<void> setReduceMotion({required bool enabled}) =>
      _update(state.settings.copyWith(reduceMotion: enabled));

  Future<void> setHideBalance({required bool hidden}) =>
      _update(state.settings.copyWith(hideBalance: hidden));

  Future<void> toggleHideBalance() =>
      setHideBalance(hidden: !state.settings.hideBalance);

  Future<void> _update(AppSettings next) async {
    final previous = state;
    if (next == previous.settings) return;
    emit(SettingsState(settings: next, loaded: previous.loaded));
    try {
      await _repository.save(next);
    } on Exception catch (e) {
      Logger.error('Could not save settings', e);
      if (!isClosed) emit(previous);
    }
  }
}
