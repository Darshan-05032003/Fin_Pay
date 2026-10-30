import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Rises the child into place on a spring (translate [offset] → 0 with a
/// fade), once, after [delay]. Used for primary calls to action. With
/// reduced motion the child fades in quickly without moving.
class SpringRise extends StatefulWidget {
  const SpringRise({
    required this.child,
    super.key,
    this.offset = 48,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// Starting vertical offset in pixels.
  final double offset;
  final Duration delay;

  @override
  State<SpringRise> createState() => _SpringRiseState();
}

class _SpringRiseState extends State<SpringRise>
    with SingleTickerProviderStateMixin {
  // Unbounded so the spring may overshoot slightly above 1.
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );
  late final Animation<double> _fade = _controller.drive(
    Tween<double>(begin: 0, end: 1),
  );
  bool _started = false;
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = FpMotion.of(context).reduce;
    if (_reduce) {
      _controller.animateTo(1, duration: FpMotion.fast, curve: Curves.easeOut);
      return;
    }
    // The delay is part of the simulation (a hold before the spring), so
    // one controller drives everything and no timer can outlive the widget.
    _controller.animateWith(
      _DelayedSimulation(
        widget.delay,
        FpSprings.simulation(FpSprings.sheet, start: 0, end: 1),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FadeTransition (a compositing-layer opacity) rather than an Opacity
    // widget rebuilt per frame; the layer clamps any spring overshoot.
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final dy = _reduce ? 0.0 : widget.offset * (1 - _controller.value);
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
        ),
      ),
    );
  }
}

/// Holds [inner]'s start value for [delay], then runs [inner].
class _DelayedSimulation extends Simulation {
  _DelayedSimulation(this.delay, this.inner);

  final Duration delay;
  final Simulation inner;

  double get _d => delay.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  double x(double time) => time < _d ? inner.x(0) : inner.x(time - _d);

  @override
  double dx(double time) => time < _d ? 0 : inner.dx(time - _d);

  @override
  bool isDone(double time) => time >= _d && inner.isDone(time - _d);
}
