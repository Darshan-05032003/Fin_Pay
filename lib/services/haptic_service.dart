import 'package:vibration/vibration.dart';

class HapticService {
  static Future<void> lightImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 10);
    }
  }

  static Future<void> mediumImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 20);
    }
  }

  static Future<void> heavyImpact() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 30);
    }
  }

  static Future<void> success() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 50, 100, 50]);
    }
  }

  static Future<void> error() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 100, 50, 100]);
    }
  }

  static Future<void> selection() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 5);
    }
  }
}

