import 'dart:math' as math;

import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Pure stagger maths, unit-tested on its own.
class FpStagger {
  const FpStagger._();

  /// Default delay between consecutive children.
  static const Duration defaultStep = Duration(milliseconds: 60);

  /// Default cap on the delay of the last child, so long lists never take
  /// seconds to appear.
  static const Duration defaultCap = Duration(milliseconds: 480);

  /// The start delay for each of [count] children: `index * step`, but the
  /// whole stagger is compressed so the last child starts no later than
  /// [cap].
  static List<Duration> delays(
    int count, {
    Duration step = defaultStep,
    Duration cap = defaultCap,
  }) {
    if (count <= 0) return const [];
    final naturalLast = step.inMicroseconds * (count - 1);
    final scale = naturalLast > cap.inMicroseconds
        ? cap.inMicroseconds / naturalLast
        : 1.0;
    return List.generate(
      count,
      (i) => Duration(microseconds: (step.inMicroseconds * i * scale).round()),
    );
  }
}

/// A single child that slides (by a pixel offset) and fades in after
/// [delay]. Replaces `CredSlideIn`, `FadeInAnimation`, `DelayedAnimation`,
/// `CredCardReveal` and `SpringAnimation`.
///
/// The offset is in **pixels** (the old widgets passed pixel values into a
/// `SlideTransition`, which expects fractions of the child size). With reduced
/// motion the child fades in quickly with no movement.
class FpEntrance extends StatefulWidget {
  const FpEntrance({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = FpMotion.emphasized,
    this.offset = const Offset(0, 24),
    this.scaleFrom = 1,
    this.curve = FpMotion.emphasizedDecelerate,
    this.fade = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting pixel offset.
  final Offset offset;

  /// Starting scale (1 = none).
  final double scaleFrom;
  final Curve curve;
  final bool fade;

  @override
  State<FpEntrance> createState() => _FpEntranceState();
}

class _FpEntranceState extends State<FpEntrance>
    with SingleTickerProviderStateMixin {
  // One controller runs delay + duration; the delay is the flat start of an
  // Interval, so there is no timer to leak or to fire after dispose.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: _intervalFor(widget.delay, widget.duration, widget.curve),
  );
  bool _started = false;

  static Curve _intervalFor(Duration delay, Duration duration, Curve curve) {
    final total = delay.inMicroseconds + duration.inMicroseconds;
    if (total == 0) return curve;
    final start = delay.inMicroseconds / total;
    return Interval(start, 1, curve: curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (FpMotion.of(context).reduce) {
      _controller.duration = FpMotion.fast;
      _curved.curve = Curves.easeOut;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = FpMotion.of(context).reduce;
    Widget body = AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        final t = _curved.value;
        if (reduce) return child!;
        final dx = widget.offset.dx * (1 - t);
        final dy = widget.offset.dy * (1 - t);
        final scale = widget.scaleFrom + (1 - widget.scaleFrom) * t;
        var w = child!;
        if (widget.scaleFrom != 1) {
          w = Transform.scale(scale: scale, child: w);
        }
        return Transform.translate(offset: Offset(dx, dy), child: w);
      },
    );
    if (widget.fade) {
      body = FadeTransition(opacity: _curved, child: body);
    }
    return RepaintBoundary(child: body);
  }
}

/// Children slide + fade in one after another with a capped total delay.
///
/// Replaces `StaggeredListAnimation` and `CredStaggeredGrid`. Build the
/// layout with [builder] (defaults to a [Column]).
class FpStaggeredEntrance extends StatelessWidget {
  const FpStaggeredEntrance({
    required this.children,
    super.key,
    this.step = FpStagger.defaultStep,
    this.cap = FpStagger.defaultCap,
    this.offset = const Offset(0, 24),
    this.duration = FpMotion.emphasized,
    this.builder,
  });

  final List<Widget> children;
  final Duration step;
  final Duration cap;
  final Offset offset;
  final Duration duration;

  /// Lays out the wrapped children. Defaults to a [Column].
  final Widget Function(BuildContext context, List<Widget> children)? builder;

  @override
  Widget build(BuildContext context) {
    final delays = FpStagger.delays(children.length, step: step, cap: cap);
    final wrapped = [
      for (var i = 0; i < children.length; i++)
        FpEntrance(
          key: ValueKey('fp-stagger-$i'),
          delay: delays[i],
          duration: duration,
          offset: offset,
          child: children[i],
        ),
    ];
    final build = builder;
    if (build != null) return build(context, wrapped);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: wrapped,
    );
  }
}

/// The total time until the last child of a stagger has finished.
Duration fpStaggerTotal(
  int count, {
  Duration step = FpStagger.defaultStep,
  Duration cap = FpStagger.defaultCap,
  Duration duration = FpMotion.emphasized,
}) {
  final delays = FpStagger.delays(count, step: step, cap: cap);
  if (delays.isEmpty) return Duration.zero;
  return Duration(
    microseconds:
        math.max(delays.last.inMicroseconds, 0) + duration.inMicroseconds,
  );
}
