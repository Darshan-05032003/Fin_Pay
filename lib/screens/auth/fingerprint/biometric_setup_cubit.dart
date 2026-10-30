import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/platform/biometric_authenticator.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where the fingerprint setup is.
enum BiometricPhase {
  /// Asking the device whether biometrics can be used.
  checking,

  /// Ready for a tap on the glyph.
  ready,

  /// The system prompt is up.
  scanning,

  /// Recognised; the preference is saved.
  success,

  /// Not recognised, cancelled, locked out or an error; retry is offered.
  failed,

  /// No hardware or nothing enrolled; only "skip" makes sense.
  unavailable,

  /// The user chose "not now".
  skipped,
}

class BiometricSetupState extends Equatable {
  const BiometricSetupState({
    this.phase = BiometricPhase.checking,
    this.result,
    this.attempts = 0,
  });

  final BiometricPhase phase;

  /// The last platform outcome, when there is one.
  final BiometricResult? result;
  final int attempts;

  bool get canAuthenticate =>
      phase == BiometricPhase.ready || phase == BiometricPhase.failed;

  /// User-facing explanation of [result] for the failed / unavailable
  /// phases; null otherwise.
  String? get message => switch (result) {
    BiometricResult.failed => 'Not recognised. Try again.',
    BiometricResult.lockedOut =>
      'Biometrics are locked on this device. Use your password for now.',
    BiometricResult.error => 'Something went wrong. Try again.',
    BiometricResult.notEnrolled =>
      'No fingerprint is enrolled on this device yet.',
    BiometricResult.notAvailable =>
      'Biometrics are not available on this device.',
    BiometricResult.success || null => null,
  };

  BiometricSetupState copyWith({
    BiometricPhase? phase,
    BiometricResult? result,
    int? attempts,
  }) => BiometricSetupState(
    phase: phase ?? this.phase,
    result: result ?? this.result,
    attempts: attempts ?? this.attempts,
  );

  @override
  List<Object?> get props => [phase, result, attempts];
}

/// Fingerprint setup: checks availability, runs the system prompt through
/// the [BiometricAuthenticator] interface and persists the choice.
class BiometricSetupCubit extends Cubit<BiometricSetupState> {
  BiometricSetupCubit({
    required BiometricAuthenticator biometrics,
    required SettingsCubit settings,
  }) : _biometrics = biometrics,
       _settings = settings,
       super(const BiometricSetupState());

  /// Reason shown in the system prompt.
  static const String reason = 'Confirm your fingerprint to set up FinPay';

  final BiometricAuthenticator _biometrics;
  final SettingsCubit _settings;
  bool _prompting = false;

  Future<void> check() async {
    final available = await _biometrics.isAvailable();
    if (isClosed) return;
    emit(
      available
          ? state.copyWith(phase: BiometricPhase.ready)
          : state.copyWith(
              phase: BiometricPhase.unavailable,
              result: BiometricResult.notAvailable,
            ),
    );
  }

  /// Shows the prompt. Concurrent calls prompt once; after success or when
  /// unavailable nothing happens.
  Future<void> authenticate() async {
    if (_prompting || !state.canAuthenticate) return;
    _prompting = true;
    emit(state.copyWith(phase: BiometricPhase.scanning));
    try {
      final result = await _biometrics.authenticate(reason: reason);
      if (isClosed) return;
      final attempts = state.attempts + 1;
      switch (result) {
        case BiometricResult.success:
          await _settings.setBiometricEnabled(enabled: true);
          if (isClosed) return;
          emit(
            state.copyWith(
              phase: BiometricPhase.success,
              result: result,
              attempts: attempts,
            ),
          );
        case BiometricResult.failed ||
            BiometricResult.lockedOut ||
            BiometricResult.error:
          emit(
            state.copyWith(
              phase: BiometricPhase.failed,
              result: result,
              attempts: attempts,
            ),
          );
        case BiometricResult.notAvailable || BiometricResult.notEnrolled:
          emit(
            state.copyWith(
              phase: BiometricPhase.unavailable,
              result: result,
              attempts: attempts,
            ),
          );
      }
    } finally {
      _prompting = false;
    }
  }

  /// "Not now": records the choice so nothing prompts later.
  Future<void> skip() async {
    await _settings.setBiometricEnabled(enabled: false);
    if (isClosed) return;
    emit(state.copyWith(phase: BiometricPhase.skipped));
  }
}
