import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// A checkmark that draws itself along its path (success moments: OTP
/// verified, biometrics enrolled, payment sent). Starts when [shown] is
/// true, runs once, and appears fully drawn at once with reduced motion.
class FpDrawnCheck extends StatefulWidget {
  const FpDrawnCheck({
    super.key,
    this.shown = true,
    this.size = 96,
    this.color,
    this.strokeWidth = 6,
    this.duration = FpMotion.emphasized,
    this.onCompleted,
    this.semanticLabel = 'Success',
  });

  final bool shown;
  final double size;

  /// Stroke colour; defaults to the success token.
  final Color? color;
  final double strokeWidth;
  final Duration duration;

  /// Called once when the stroke is complete.
  final VoidCallback? onCompleted;
  final String semanticLabel;

  /// The check path inside [size] (pure, for tests and the painter).
  static Path pathFor(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.42, h * 0.72)
      ..lineTo(w * 0.78, h * 0.32);
  }

  @override
  State<FpDrawnCheck> createState() => _FpDrawnCheckState();
}

class _FpDrawnCheckState extends State<FpDrawnCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: FpMotion.emphasizedDecelerate,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onCompleted?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(FpDrawnCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown && !oldWidget.shown) _maybeStart();
  }

  void _maybeStart() {
    if (_started || !widget.shown) return;
    _started = true;
    if (FpMotion.of(context).reduce) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.fp.colors.success;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _curved,
              builder: (context, _) => CustomPaint(
                painter: FpDrawnCheckPainter(
                  progress: widget.shown ? _curved.value : 0,
                  color: color,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strokes the first [progress] fraction of the check path.
class FpDrawnCheckPainter extends CustomPainter {
  const FpDrawnCheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final path = FpDrawnCheck.pathFor(size);
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(FpDrawnCheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
