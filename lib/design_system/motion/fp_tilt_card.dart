import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Pure tilt maths, unit-tested on its own. Tilt is an [Offset] whose axes
/// are in `-1…1` (x: right edge lower, y: top edge lower).
class FpTiltMath {
  const FpTiltMath._();

  /// Largest rotation per axis, in radians (about 10°).
  static const double maxAngle = 0.18;

  /// Perspective entry (row 3, column 2) of the transform.
  static const double perspective = 0.0015;

  /// Clamps each axis to `-1…1`.
  static Offset clamp(Offset tilt) =>
      Offset(tilt.dx.clamp(-1.0, 1.0), tilt.dy.clamp(-1.0, 1.0));

  /// Low-pass filter: moves [current] towards [target] by [factor]
  /// (`0 < factor ≤ 1`), so a noisy sensor cannot make the card jitter.
  static Offset damp(Offset current, Offset target, double factor) {
    final f = factor.clamp(0.0, 1.0);
    return current + (clamp(target) - current) * f;
  }

  /// The 3D transform for [tilt]: the lower edge comes towards the viewer.
  /// Flat (zero tilt) is the identity, with no perspective entry.
  static Matrix4 transform(Offset tilt, {double maxAngle = maxAngle}) {
    final t = clamp(tilt);
    if (t == Offset.zero) return Matrix4.identity();
    return Matrix4.identity()
      ..setEntry(3, 2, perspective)
      ..rotateX(-t.dy * maxAngle)
      ..rotateY(t.dx * maxAngle);
  }

  /// Where the light sheen sits for [tilt]: it slides opposite to the tilt,
  /// as a reflection would.
  static Alignment sheenAlignment(Offset tilt) {
    final t = clamp(tilt);
    return Alignment(-t.dx * 1.5, -t.dy * 1.5);
  }

  /// Tilt from a pointer at [local] inside a box of [size] (drag fallback
  /// when no motion sensor is available): the finger pushes the card down
  /// where it touches.
  static Offset fromPointer(Offset local, Size size) {
    if (size.isEmpty) return Offset.zero;
    return clamp(
      Offset(local.dx / size.width * 2 - 1, local.dy / size.height * 2 - 1),
    );
  }
}

/// Drives an [FpTiltCard]. Feed sensor samples through [push] (damped) and
/// pointer positions through [set] (immediate); [FpTiltCard] springs the
/// value back to flat when a drag ends.
class FpTiltController extends ValueNotifier<Offset> {
  FpTiltController({this.damping = 0.25}) : super(Offset.zero);

  /// Fraction of the distance to a new sensor sample applied per sample.
  final double damping;

  /// A damped step towards [target] (sensor samples).
  void push(Offset target) => value = FpTiltMath.damp(value, target, damping);

  /// Sets the tilt immediately (pointer positions).
  void set(Offset target) => value = FpTiltMath.clamp(target);
}

/// 3D tilt with a moving light sheen, for cards.
///
/// Rotates [child] by the controller's tilt with perspective and slides a
/// soft highlight across it in the opposite direction. When [dragFallback]
/// is on, raw pointer events (which never fight the gesture arena, so a
/// swipeable page can still swipe) tilt the card under the finger and it
/// springs back on release. With reduced motion the child is flat and the
/// sheen is static.
class FpTiltCard extends StatefulWidget {
  const FpTiltCard({
    required this.child,
    super.key,
    this.controller,
    this.dragFallback = true,
    this.sheen = true,
    this.maxAngle = FpTiltMath.maxAngle,
  });

  final Widget child;

  /// Shared controller (sensor-driven); the card owns one when null.
  final FpTiltController? controller;
  final bool dragFallback;
  final bool sheen;
  final double maxAngle;

  @override
  State<FpTiltCard> createState() => _FpTiltCardState();
}

class _FpTiltCardState extends State<FpTiltCard>
    with SingleTickerProviderStateMixin {
  FpTiltController? _owned;
  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
  );
  Offset _releaseFrom = Offset.zero;
  bool _pointerDown = false;

  FpTiltController get _controller =>
      widget.controller ?? (_owned ??= FpTiltController());

  @override
  void initState() {
    super.initState();
    _spring.addListener(_onSpring);
  }

  void _onSpring() {
    if (_pointerDown) return;
    _controller.set(_releaseFrom * _spring.value);
  }

  @override
  void dispose() {
    _spring.dispose();
    _owned?.dispose();
    super.dispose();
  }

  void _pointer(Offset position) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    _controller.set(FpTiltMath.fromPointer(position, box.size));
  }

  void _down(PointerDownEvent e) {
    _pointerDown = true;
    _spring.stop();
    _pointer(e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (_pointerDown) _pointer(e.localPosition);
  }

  void _up() {
    if (!_pointerDown) return;
    _pointerDown = false;
    _releaseFrom = _controller.value;
    if (FpMotion.of(context).reduce) {
      _controller.set(Offset.zero);
      return;
    }
    _spring.animateWith(
      FpSprings.simulation(FpSprings.press, start: 1, end: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    final reduce = FpMotion.of(context).reduce;
    if (reduce) return widget.child;
    Widget body = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final tilt = _controller.value;
          return Transform(
            transform: FpTiltMath.transform(tilt, maxAngle: widget.maxAngle),
            alignment: Alignment.center,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                child!,
                if (widget.sheen)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: FpTiltMath.sheenAlignment(tilt),
                              radius: 1.2,
                              colors: [
                                c.popWhite.withValues(alpha: 0.14),
                                c.popWhite.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    if (widget.dragFallback) {
      body = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: body,
      );
    }
    return body;
  }
}
