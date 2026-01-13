import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// CRED NeoPOP Haptic Service
/// Uses Medium/Heavy haptics for physical button feel
class HapticService {
  /// Light impact for subtle interactions
  static Future<void> lightImpact() async {
    HapticFeedback.lightImpact();
  }

  /// Medium impact - CRED standard for button presses
  static Future<void> mediumImpact() async {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - For important actions
  static Future<void> heavyImpact() async {
    HapticFeedback.heavyImpact();
  }

  /// Success pattern - For successful actions
  static Future<void> success() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 50, 100, 50]);
    }
  }

  /// Error pattern - For error states
  static Future<void> error() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 100, 50, 100]);
    }
  }

  /// Selection haptic - For navigation/tab selection
  static Future<void> selection() async {
    HapticFeedback.selectionClick();
  }
}

