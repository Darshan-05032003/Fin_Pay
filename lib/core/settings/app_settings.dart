import 'package:equatable/equatable.dart';

/// User preferences that affect the whole app.
class AppSettings extends Equatable {
  const AppSettings({
    this.hapticsEnabled = true,
    this.reduceMotion = false,
    this.hideBalance = false,
    this.onboardingSeen = false,
    this.biometricEnabled = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
    reduceMotion: json['reduceMotion'] as bool? ?? false,
    hideBalance: json['hideBalance'] as bool? ?? false,
    onboardingSeen: json['onboardingSeen'] as bool? ?? false,
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
  );

  /// Defaults: haptics on, motion on, balance visible, onboarding not yet
  /// seen, biometrics off.
  static const AppSettings defaults = AppSettings();

  final bool hapticsEnabled;
  final bool reduceMotion;
  final bool hideBalance;

  /// True once the user has finished (or skipped) the onboarding pages;
  /// the router then sends `/onboarding` straight to the login screen.
  final bool onboardingSeen;

  /// The user opted into biometric unlock during fingerprint setup.
  final bool biometricEnabled;

  AppSettings copyWith({
    bool? hapticsEnabled,
    bool? reduceMotion,
    bool? hideBalance,
    bool? onboardingSeen,
    bool? biometricEnabled,
  }) => AppSettings(
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    hideBalance: hideBalance ?? this.hideBalance,
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
  );

  Map<String, dynamic> toJson() => {
    'hapticsEnabled': hapticsEnabled,
    'reduceMotion': reduceMotion,
    'hideBalance': hideBalance,
    'onboardingSeen': onboardingSeen,
    'biometricEnabled': biometricEnabled,
  };

  @override
  List<Object?> get props => [
    hapticsEnabled,
    reduceMotion,
    hideBalance,
    onboardingSeen,
    biometricEnabled,
  ];
}
