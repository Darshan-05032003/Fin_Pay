import 'dart:math' as math;

import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Drives one or more [FpShake] widgets. Call [shake] to run a horizontal
/// shake; listeners rebuild from [offsetAt].
class FpShakeController extends ChangeNotifier {
  FpShakeController({
    this.amplitude = 8,
    this.oscillations = 3,
    this.duration = FpMotion.emphasized,
  });

  /// Peak displacement in pixels.
  final double amplitude;

  /// Number of full left-right cycles.
  final int oscillations;
  final Duration duration;

  int _shakeCount = 0;

  /// How many shakes have been requested.
  int get shakeCount => _shakeCount;

  /// Requests a shake. Each call notifies listeners, even mid-shake.
  void shake() {
    _shakeCount++;
    notifyListeners();
  }

  /// Horizontal offset at normalised time [t] in `[0, 1]`: a decaying sine,
  /// zero at both ends. Pure, unit-tested.
  double offsetAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final decay = 1 - clamped;
    return amplitude * decay * math.sin(clamped * oscillations * 2 * math.pi);
  }
}

/// Horizontal shake for invalid input and failed actions.
class FpShake extends StatefulWidget {
  const FpShake({required this.controller, required this.child, super.key});

  final FpShakeController controller;
  final Widget child;

  @override
  State<FpShake> createState() => _FpShakeState();
}

class _FpShakeState extends State<FpShake> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: widget.controller.duration,
  );
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _seen = widget.controller.shakeCount;
    widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(FpShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
      _seen = widget.controller.shakeCount;
    }
  }

  void _onShake() {
    if (widget.controller.shakeCount == _seen) return;
    _seen = widget.controller.shakeCount;
    if (FpMotion.of(context).reduce) return;
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: widget.child,
      builder: (context, child) {
        final dx = _anim.isAnimating
            ? widget.controller.offsetAt(_anim.value)
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
