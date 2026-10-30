import 'dart:async';
import 'dart:math' as math;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_depth.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Pure pull-to-refresh maths, unit-tested on its own.
class FpRefreshMath {
  const FpRefreshMath._();

  /// Drag distance (in scroll pixels) that arms the refresh.
  static const double armDistance = 80;

  /// Drag distance after which pulling further changes nothing.
  static const double maxDrag = 200;

  /// Size of the drawn glyph.
  static const double glyphSize = 44;

  /// One turn of the arc while a refresh runs (a continuous rotation, so
  /// not one of the one-shot motion tokens).
  static const Duration spinPeriod = Duration(milliseconds: 900);

  /// Arc progress for [drag]: 0 at rest, 1 once armed, never more.
  static double progress(double drag) => (drag / armDistance).clamp(0.0, 1.0);

  /// How far the glyph has travelled down for [drag]: a resisted curve that
  /// approaches [armDistance] asymptotically, so a hard pull never drags
  /// the glyph off into the content.
  static double displacement(double drag) {
    if (drag <= 0) return 0;
    final d = math.min(drag, maxDrag);
    return armDistance * (1 - math.exp(-d / armDistance));
  }

  /// True once [drag] has reached [armDistance].
  static bool isArmed(double drag) => drag >= armDistance;
}

/// Custom pull-to-refresh with a drawn NeoPOP arc.
///
/// Wraps a vertical scrollable. While the user pulls past the top, a square
/// plunk tile slides down and an accent arc sweeps with the drag distance;
/// crossing the arm distance plays a `medium` haptic. Releasing while armed
/// runs [onRefresh] with the arc spinning; the tile then retreats. Works
/// with clamping (Android) and bouncing (iOS) physics. With reduced motion
/// the arc does not spin and the tile moves without easing.
class FpRefreshIndicator extends StatefulWidget {
  const FpRefreshIndicator({
    required this.child,
    required this.onRefresh,
    super.key,
    this.haptics,
    this.semanticLabel = 'Pull down to refresh',
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final HapticService? haptics;
  final String semanticLabel;

  @override
  State<FpRefreshIndicator> createState() => _FpRefreshIndicatorState();
}

class _FpRefreshIndicatorState extends State<FpRefreshIndicator>
    with TickerProviderStateMixin {
  final ValueNotifier<double> _drag = ValueNotifier(0);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: FpRefreshMath.spinPeriod,
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: FpMotion.emphasized,
  );
  bool _dragging = false;
  bool _refreshing = false;
  bool _armedHaptic = false;
  Tween<double>? _settleTween;

  /// True while [FpRefreshIndicator.onRefresh] is running.
  bool get isRefreshing => _refreshing;

  @override
  void initState() {
    super.initState();
    _settle.addListener(_onSettle);
  }

  void _onSettle() {
    final tween = _settleTween;
    if (tween == null) return;
    _drag.value = tween.transform(
      FpMotion.standardCurve.transform(_settle.value),
    );
  }

  @override
  void dispose() {
    _settle.dispose();
    _spin.dispose();
    _drag.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || _refreshing) return false;
    switch (n) {
      case ScrollStartNotification(:final dragDetails)
          when dragDetails != null && n.metrics.extentBefore <= 0:
        _dragging = true;
        _armedHaptic = false;
        _settle.stop();
      case OverscrollNotification(:final overscroll)
          when _dragging && overscroll < 0:
        _update(_drag.value - overscroll);
      case OverscrollNotification() when _dragging:
        _update(0);
      case ScrollUpdateNotification() when _dragging:
        // Bouncing physics report the pull as negative pixels.
        if (n.metrics.pixels < 0) {
          _update(-n.metrics.pixels);
        } else if (n.dragDetails != null && n.metrics.pixels > 0) {
          _update(0);
        }
      case ScrollEndNotification() when _dragging:
        _dragging = false;
        _release();
      default:
        break;
    }
    return false;
  }

  void _update(double drag) {
    final clamped = drag.clamp(0.0, FpRefreshMath.maxDrag);
    if (!_armedHaptic && FpRefreshMath.isArmed(clamped)) {
      _armedHaptic = true;
      playHaptic(widget.haptics, HapticType.medium);
    }
    _drag.value = clamped;
  }

  void _animateDrag(double to) {
    final reduce = FpMotion.of(context).reduce;
    if (reduce) {
      _drag.value = to;
      return;
    }
    _settleTween = Tween(begin: _drag.value, end: to);
    _settle
      ..value = 0
      ..forward();
  }

  void _release() {
    if (FpRefreshMath.isArmed(_drag.value)) {
      unawaited(_refresh());
    } else {
      _animateDrag(0);
    }
  }

  Future<void> _refresh() async {
    _refreshing = true;
    _animateDrag(FpRefreshMath.armDistance);
    if (!FpMotion.of(context).reduce) _spin.repeat();
    try {
      await widget.onRefresh();
    } on Object catch (error, stack) {
      // A failed refresh must never take the screen down with it.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fin_pay design system',
          context: ErrorDescription('while running onRefresh'),
        ),
      );
    } finally {
      if (mounted) {
        _spin.stop();
        _refreshing = false;
        _animateDrag(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    return Semantics(
      label: widget.semanticLabel,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onNotification,
            child: widget.child,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_drag, _spin]),
                    builder: (context, _) {
                      final drag = _drag.value;
                      final shift =
                          FpRefreshMath.displacement(drag) -
                          FpRefreshMath.glyphSize;
                      return Transform.translate(
                        offset: Offset(0, shift),
                        child: Center(
                          child: FpRefreshGlyph(
                            progress: FpRefreshMath.progress(drag),
                            spin: _spin.value,
                            face: c.surfaceRaised,
                            edge: FpEdge.surfaceRaised,
                            arc: c.accent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawn refresh glyph: a NeoPOP tile with an arc that sweeps with
/// [progress] and rotates with [spin] (0…1 = one turn).
class FpRefreshGlyph extends StatelessWidget {
  const FpRefreshGlyph({
    required this.progress,
    required this.spin,
    required this.face,
    required this.edge,
    required this.arc,
    super.key,
    this.size = FpRefreshMath.glyphSize,
  });

  final double progress;
  final double spin;
  final Color face;
  final FpEdge edge;
  final Color arc;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RefreshPainter(
        progress: progress,
        spin: spin,
        face: face,
        edge: edge,
        arc: arc,
      ),
    );
  }
}

class _RefreshPainter extends CustomPainter {
  const _RefreshPainter({
    required this.progress,
    required this.spin,
    required this.face,
    required this.edge,
    required this.arc,
  });

  final double progress;
  final double spin;
  final Color face;
  final FpEdge edge;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    const depth = FpDepth.button;
    final alpha = progress.clamp(0.0, 1.0);
    final body = Rect.fromLTWH(0, 0, size.width - depth, size.height - depth);
    // Solid edge faces: right and bottom.
    canvas
      ..drawRect(
        Rect.fromLTWH(body.right, depth, depth, body.height),
        Paint()..color = edge.right.withValues(alpha: alpha),
      )
      ..drawRect(
        Rect.fromLTWH(depth, body.bottom, body.width, depth),
        Paint()..color = edge.bottom.withValues(alpha: alpha),
      )
      ..drawRect(body, Paint()..color = face.withValues(alpha: alpha));
    final radius = body.shortestSide * 0.28;
    final start = -math.pi / 2 + spin * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: body.center, radius: radius),
      start,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = arc.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_RefreshPainter old) =>
      old.progress != progress ||
      old.spin != spin ||
      old.face != face ||
      old.arc != arc;
}
