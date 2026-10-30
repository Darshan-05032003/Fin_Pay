import 'dart:math' as math;

import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// A ring that empties clockwise as [progress] goes from 1 to 0 (resend
/// countdowns, processing timeouts), with an optional centred [label].
///
/// Pure presentation: the caller owns the clock and passes the remaining
/// fraction; changes animate over `FpMotion.standard` (instant with reduced
/// motion).
class FpCountdownRing extends StatelessWidget {
  const FpCountdownRing({
    required this.progress,
    super.key,
    this.label,
    this.size = 56,
    this.strokeWidth = 4,
    this.color,
    this.trackColor,
    this.semanticLabel,
  }) : assert(size > 0, 'size must be > 0');

  /// Remaining fraction, 0..1 (clamped).
  final double progress;
  final String? label;
  final double size;
  final double strokeWidth;

  /// Arc colour; defaults to the accent.
  final Color? color;

  /// Track colour; defaults to the border token.
  final Color? trackColor;

  /// Accessibility description (e.g. "Resend available in 12 seconds").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final target = progress.clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: target),
            duration: reduce ? Duration.zero : FpMotion.standard,
            curve: FpMotion.standardCurve,
            builder: (context, value, child) => CustomPaint(
              painter: FpCountdownRingPainter(
                progress: value,
                color: color ?? c.accent,
                track: trackColor ?? c.border,
                strokeWidth: strokeWidth,
              ),
              child: child,
            ),
            child: Center(
              child: label == null
                  ? null
                  : Text(
                      label!,
                      style: fp.text.numeric.copyWith(
                        fontSize: size * 0.3,
                        color: c.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the track circle and the remaining arc from 12 o'clock.
class FpCountdownRingPainter extends CustomPainter {
  const FpCountdownRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = track);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(FpCountdownRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}
