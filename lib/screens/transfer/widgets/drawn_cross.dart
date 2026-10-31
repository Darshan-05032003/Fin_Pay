import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The failure counterpart of `FpDrawnCheck`: two strokes drawn one after
/// the other over `emphasized`. Appears fully drawn under reduce motion.
class DrawnCross extends StatefulWidget {
  const DrawnCross({
    super.key,
    this.size = 96,
    this.strokeWidth = 6,
    this.color,
    this.semanticLabel = 'Failed',
  });

  final double size;
  final double strokeWidth;

  /// Defaults to the alert token.
  final Color? color;
  final String semanticLabel;

  @override
  State<DrawnCross> createState() => _DrawnCrossState();
}

class _DrawnCrossState extends State<DrawnCross>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FpMotion.emphasized,
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: FpMotion.emphasizedDecelerate,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (FpMotion.of(context).reduce) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.fp.colors.alert;
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
                painter: DrawnCrossPainter(
                  progress: _curved.value,
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

/// Strokes the first diagonal over progress 0–0.5 and the second over
/// 0.5–1.
class DrawnCrossPainter extends CustomPainter {
  const DrawnCrossPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final inset = size.width * 0.28;
    final a = Offset(inset, inset);
    final b = Offset(size.width - inset, size.height - inset);
    final c = Offset(size.width - inset, inset);
    final d = Offset(inset, size.height - inset);
    final first = (progress * 2).clamp(0.0, 1.0);
    final second = (progress * 2 - 1).clamp(0.0, 1.0);
    if (first > 0) canvas.drawLine(a, Offset.lerp(a, b, first)!, paint);
    if (second > 0) canvas.drawLine(c, Offset.lerp(c, d, second)!, paint);
  }

  @override
  bool shouldRepaint(DrawnCrossPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
