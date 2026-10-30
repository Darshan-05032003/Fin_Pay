import 'package:equatable/equatable.dart';

/// User preferences that affect the whole app.
class AppSettings extends Equatable {
  const AppSettings({
    this.hapticsEnabled = true,
    this.reduceMotion = false,
    this.hideBalance = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
    reduceMotion: json['reduceMotion'] as bool? ?? false,
    hideBalance: json['hideBalance'] as bool? ?? false,
  );

  /// Defaults: haptics on, motion on, balance visible.
  static const AppSettings defaults = AppSettings();

  final bool hapticsEnabled;
  final bool reduceMotion;
  final bool hideBalance;

  AppSettings copyWith({
    bool? hapticsEnabled,
    bool? reduceMotion,
    bool? hideBalance,
  }) => AppSettings(
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    hideBalance: hideBalance ?? this.hideBalance,
  );

  Map<String, dynamic> toJson() => {
    'hapticsEnabled': hapticsEnabled,
    'reduceMotion': reduceMotion,
    'hideBalance': hideBalance,
  };

  @override
  List<Object?> get props => [hapticsEnabled, reduceMotion, hideBalance];
}
