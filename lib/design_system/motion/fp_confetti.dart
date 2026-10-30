import 'dart:math' as math;

import 'package:fin_pay/design_system/tokens/fp_colors.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// One confetti particle. Positions are in fractions of the painter size.
@immutable
class FpConfettiParticle {
  const FpConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double spin;
  final double size;
  final Color color;
}

/// Pure particle maths for [FpConfetti]. Unit-tested on its own.
class FpConfettiBurst {
  FpConfettiBurst({
    required this.count,
    required this.colors,
    int seed = 7,
    this.gravity = 1.6,
  }) : _random = math.Random(seed) {
    particles = List.generate(count, (_) {
      final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.7 + _random.nextDouble() * 0.9;
      return FpConfettiParticle(
        x: 0.5 + (_random.nextDouble() - 0.5) * 0.2,
        y: 0.55,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        spin: (_random.nextDouble() - 0.5) * 12,
        size: 5 + _random.nextDouble() * 5,
        color: colors[_random.nextInt(colors.length)],
      );
    });
  }

  final int count;
  final List<Color> colors;
  final double gravity;
  final math.Random _random;
  late final List<FpConfettiParticle> particles;

  /// Position of [p] at normalised time [t] (0..1), as fractions of the box.
  Offset positionAt(FpConfettiParticle p, double t) =>
      Offset(p.x + p.vx * t, p.y + p.vy * t + 0.5 * gravity * t * t);

  /// Opacity of every particle at [t]: fully visible, then fades in the last
  /// 30 % of the burst.
  double opacityAt(double t) => t < 0.7 ? 1 : (1 - (t - 0.7) / 0.3).clamp(0, 1);
}

class _FpConfettiPainter extends CustomPainter {
  _FpConfettiPainter({required this.burst, required this.progress})
    : super(repaint: progress);

  final FpConfettiBurst burst;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final opacity = burst.opacityAt(t);
    final paint = Paint();
    for (final p in burst.particles) {
      final pos = burst.positionAt(p, t);
      final dx = pos.dx * size.width;
      final dy = pos.dy * size.height;
      if (dy > size.height + p.size) continue;
      paint.color = p.color.withValues(alpha: opacity);
      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(p.spin * t)
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_FpConfettiPainter oldDelegate) =>
      oldDelegate.burst != burst;
}

/// Starts bursts on an [FpConfetti].
class FpConfettiController extends ChangeNotifier {
  int _bursts = 0;

  /// How many bursts were requested.
  int get bursts => _bursts;

  /// Fires one burst.
  void burst() {
    _bursts++;
    notifyListeners();
  }
}

/// A one-shot confetti burst drawn with a [CustomPainter] (no package).
///
/// Reserved for key moments (payment success). The burst runs once per
/// [FpConfettiController.burst] and the painter stops when it ends. With
/// reduced motion nothing is drawn.
class FpConfetti extends StatefulWidget {
  const FpConfetti({
    required this.controller,
    super.key,
    this.child,
    this.particleCount = 80,
    this.duration = const Duration(milliseconds: 1600),
    this.colors = const [
      FpColors.accent,
      FpColors.success,
      FpColors.popWhite,
      FpColors.info,
    ],
    this.autoPlay = false,
  });

  final FpConfettiController controller;
  final Widget? child;
  final int particleCount;
  final Duration duration;
  final List<Color> colors;

  /// Bursts once right after the first frame.
  final bool autoPlay;

  @override
  State<FpConfetti> createState() => _FpConfettiState();
}

class _FpConfettiState extends State<FpConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late FpConfettiBurst _burst = _newBurst();
  int _seen = 0;

  FpConfettiBurst _newBurst() => FpConfettiBurst(
    count: widget.particleCount,
    colors: widget.colors,
    seed: _seen,
  );

  @override
  void initState() {
    super.initState();
    _seen = widget.controller.bursts;
    widget.controller.addListener(_onBurst);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.burst();
      });
    }
  }

  @override
  void didUpdateWidget(FpConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onBurst);
      widget.controller.addListener(_onBurst);
      _seen = widget.controller.bursts;
    }
  }

  void _onBurst() {
    if (widget.controller.bursts == _seen) return;
    _seen = widget.controller.bursts;
    if (FpMotion.of(context).reduce) return;
    setState(() => _burst = _newBurst());
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBurst);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.child != null) widget.child!,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _FpConfettiPainter(burst: _burst, progress: _anim),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
