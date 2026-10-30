import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Device tilt, each axis normalised to roughly -1…1 (1 g = 1.0).
///
/// [x] is positive when the right edge is lower than the left; [y] is
/// positive when the top edge is lower than the bottom.
class Tilt extends Equatable {
  const Tilt(this.x, this.y);

  /// Flat on a table.
  static const Tilt flat = Tilt(0, 0);

  final double x;
  final double y;

  @override
  List<Object?> get props => [x, y];
}

/// Accelerometer-driven tilt behind an interface so the card stack can be
/// tested with `FakeMotionSensor` and disabled under reduce-motion.
abstract interface class MotionSensor {
  /// True when an accelerometer delivers events on this device.
  Future<bool> get isAvailable;

  /// Tilt updates, clamped to -1…1 per axis.
  Stream<Tilt> get tilt;
}

/// [MotionSensor] on `sensors_plus`.
class SensorsPlusMotionSensor implements MotionSensor {
  SensorsPlusMotionSensor({
    Stream<AccelerometerEvent>? events,
    this.probeTimeout = const Duration(milliseconds: 500),
  }) : _events = events;

  final Stream<AccelerometerEvent>? _events;

  /// How long [isAvailable] waits for a first sample.
  final Duration probeTimeout;

  /// Standard gravity used to normalise accelerometer readings.
  static const double gravity = 9.80665;

  Stream<AccelerometerEvent> get _source =>
      _events ??
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);

  @override
  Future<bool> get isAvailable async {
    try {
      return !await _source.isEmpty.timeout(probeTimeout);
    } on TimeoutException {
      return false;
    } on Exception {
      return false;
    }
  }

  @override
  Stream<Tilt> get tilt => _source.map(
    (e) => Tilt(
      (-e.x / gravity).clamp(-1.0, 1.0),
      (e.y / gravity).clamp(-1.0, 1.0),
    ),
  );
}
