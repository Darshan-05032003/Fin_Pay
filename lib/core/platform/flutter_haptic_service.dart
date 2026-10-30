import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Signature of the vibration-pattern primitive, injectable for tests.
typedef VibratePattern = Future<void> Function(List<int> pattern);

/// [HapticService] on `HapticFeedback` (impacts, selection) and `vibration`
/// (success/error patterns). Every call is a no-op while `isEnabled` returns
/// false, which the settings cubit drives.
class FlutterHapticService implements HapticService {
  FlutterHapticService({
    required bool Function() isEnabled,
    Future<bool> Function()? hasVibrator,
    VibratePattern? vibrate,
  }) : _isEnabled = isEnabled,
       _hasVibrator = hasVibrator ?? Vibration.hasVibrator,
       _vibrate = vibrate ?? ((pattern) => Vibration.vibrate(pattern: pattern));

  final bool Function() _isEnabled;
  final Future<bool> Function() _hasVibrator;
  final VibratePattern _vibrate;

  /// Short double tap.
  static const List<int> successPattern = [0, 40, 60, 40];

  /// Longer buzz, pause, buzz.
  static const List<int> errorPattern = [0, 90, 50, 90];

  Future<void> _run(Future<void> Function() action) async {
    if (!_isEnabled()) return;
    try {
      await action();
    } on PlatformException {
      // Haptics are best effort; a missing vibrator is not an error.
    } on MissingPluginException {
      // Running on a platform without the plugin (tests, desktop).
    }
  }

  @override
  Future<void> light() => _run(HapticFeedback.lightImpact);

  @override
  Future<void> medium() => _run(HapticFeedback.mediumImpact);

  @override
  Future<void> heavy() => _run(HapticFeedback.heavyImpact);

  @override
  Future<void> selection() => _run(HapticFeedback.selectionClick);

  @override
  Future<void> success() =>
      _pattern(successPattern, HapticFeedback.mediumImpact);

  @override
  Future<void> error() => _pattern(errorPattern, HapticFeedback.heavyImpact);

  Future<void> _pattern(List<int> pattern, Future<void> Function() fallback) =>
      _run(() async {
        if (await _hasVibrator()) {
          await _vibrate(pattern);
        } else {
          await fallback();
        }
      });

  @override
  Future<void> play(HapticType type) => switch (type) {
    HapticType.light => light(),
    HapticType.medium => medium(),
    HapticType.heavy => heavy(),
    HapticType.selection => selection(),
    HapticType.success => success(),
    HapticType.error => error(),
  };
}
