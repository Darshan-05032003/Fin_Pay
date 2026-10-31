import 'dart:math' as math;

import 'package:fin_pay/design_system/components/fp_countdown_ring.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Indeterminate progress ring: a three-quarter arc that rotates once per
/// [period]. Reuses [FpCountdownRingPainter]. With reduced motion the arc is
/// drawn once and does not spin.
class FpProcessingRing extends StatefulWidget {
  const FpProcessingRing({
    super.key,
    this.size = 56,
    this.strokeWidth = 4,
    this.color,
    this.trackColor,
    this.period = const Duration(milliseconds: 1200),
    this.semanticLabel = 'Processing',
  });

  final double size;
  final double strokeWidth;

  /// Arc colour (defaults to the accent token).
  final Color? color;

  /// Track colour (defaults to the border token).
  final Color? trackColor;

  /// One full rotation.
  final Duration period;
  final String semanticLabel;

  /// Fraction of the circle the arc covers.
  static const double arcFraction = 0.75;

  @override
  State<FpProcessingRing> createState() => _FpProcessingRingState();
}

class _FpProcessingRingState extends State<FpProcessingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = FpMotion.of(context).reduce;
    if (reduce == _reduce && (_spin.isAnimating || reduce)) return;
    _reduce = reduce;
    if (reduce) {
      _spin.stop();
    } else {
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(FpProcessingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _spin.duration = widget.period;
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    final painter = CustomPaint(
      painter: FpCountdownRingPainter(
        progress: FpProcessingRing.arcFraction,
        color: widget.color ?? c.accent,
        track: widget.trackColor ?? c.border,
        strokeWidth: widget.strokeWidth,
      ),
    );
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: RepaintBoundary(
            child: _reduce
                ? painter
                : AnimatedBuilder(
                    animation: _spin,
                    child: painter,
                    builder: (context, child) => Transform.rotate(
                      angle: _spin.value * 2 * math.pi,
                      child: child,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
