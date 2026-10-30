import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Motion vocabulary: durations, curves and springs.
///
/// Static members are the tokens. [FpMotion.of] returns an instance that
/// knows whether the user asked for reduced motion
/// (`MediaQuery.disableAnimations`), so every animated component can fall
/// back to a fade or to no motion at all.
class FpMotion {
  const FpMotion({required this.reduce});

  /// Reads `MediaQuery.disableAnimations` for [context].
  factory FpMotion.of(BuildContext context) =>
      FpMotion(reduce: MediaQuery.disableAnimationsOf(context));

  /// True when the platform asked for reduced motion.
  final bool reduce;

  // Durations.

  /// Press feedback, hover, small state changes (< 100 ms to first frame).
  static const Duration fast = Duration(milliseconds: 150);

  /// Small UI: chips, toggles, indicator slides, odometer digit roll.
  static const Duration standard = Duration(milliseconds: 250);

  /// Larger in-screen moves: sheet entrance, entrance stagger, toasts.
  static const Duration emphasized = Duration(milliseconds: 400);

  /// Screen transitions.
  static const Duration screen = Duration(milliseconds: 450);

  /// Every duration token, by name.
  static const Map<String, Duration> durations = {
    'fast': fast,
    'standard': standard,
    'emphasized': emphasized,
    'screen': screen,
  };

  // Curves (Material 3 emphasized family; never linear).

  /// Elements entering the screen.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// Elements leaving the screen.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// Standard in-place change.
  static const Curve standardCurve = Cubic(0.2, 0, 0, 1);

  /// Standard deceleration for small entrances.
  static const Curve standardDecelerate = Cubic(0, 0, 0, 1);

  /// Every curve token, by name.
  static const Map<String, Curve> curves = {
    'emphasizedDecelerate': emphasizedDecelerate,
    'emphasizedAccelerate': emphasizedAccelerate,
    'standard': standardCurve,
    'standardDecelerate': standardDecelerate,
  };

  /// Returns [duration], or [Duration.zero] when motion is reduced.
  Duration scaled(Duration duration) => reduce ? Duration.zero : duration;

  /// Returns [curve], or a plain ease-out fade curve when motion is reduced.
  Curve curveOr(Curve curve) => reduce ? Curves.easeOut : curve;
}

/// Spring presets for anything the user presses or drags.
///
/// Every preset is critically damped or slightly under-damped, so nothing
/// oscillates for long.
class FpSprings {
  const FpSprings._();

  /// Button press release: snappy with a little overshoot.
  static final SpringDescription press = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 500,
    ratio: 0.75,
  );

  /// Bottom sheet entrance and snap-back: heavier, no visible bounce.
  static final SpringDescription sheet = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 280,
    ratio: 0.9,
  );

  /// Slider / toggle thumb: fast and almost critically damped.
  static final SpringDescription slider = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 650,
    ratio: 0.85,
  );

  /// Every spring preset, by name.
  static Map<String, SpringDescription> get all => {
    'press': press,
    'sheet': sheet,
    'slider': slider,
  };

  /// A simulation from [start] to [end] with the given initial [velocity].
  static SpringSimulation simulation(
    SpringDescription spring, {
    required double start,
    required double end,
    double velocity = 0,
  }) => SpringSimulation(spring, start, end, velocity);

  /// The damping ratio of a spring: 1 is critical, < 1 under-damped.
  static double dampingRatio(SpringDescription s) =>
      s.damping / (2 * math.sqrt(s.mass * s.stiffness));
}
