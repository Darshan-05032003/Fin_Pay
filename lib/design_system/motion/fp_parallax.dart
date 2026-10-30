import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Scroll-linked parallax: translates [child] by `-scrollOffset * factor`
/// along [axis]. A `factor` below 1 makes the layer lag behind the content
/// (background); above 1 it leads (foreground).
///
/// Reads the controller directly (no per-frame `setState`), and does nothing
/// with reduced motion.
class FpParallax extends StatelessWidget {
  const FpParallax({
    required this.controller,
    required this.child,
    super.key,
    this.factor = 0.5,
    this.axis = Axis.vertical,
    this.clamp,
  }) : assert(factor >= 0, 'factor must be ≥ 0');

  final ScrollController controller;
  final Widget child;

  /// Fraction of the scroll offset applied to the child.
  final double factor;
  final Axis axis;

  /// Optional maximum absolute translation in pixels.
  final double? clamp;

  /// The translation for a given scroll [offset] (pure, unit-tested).
  static double translation(
    double offset, {
    required double factor,
    double? clamp,
  }) {
    final raw = -offset * factor;
    if (clamp == null) return raw;
    return raw.clamp(-clamp, clamp);
  }

  @override
  Widget build(BuildContext context) {
    if (FpMotion.of(context).reduce) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final shift = translation(offset, factor: factor, clamp: clamp);
        return Transform.translate(
          offset: axis == Axis.vertical ? Offset(0, shift) : Offset(shift, 0),
          child: child,
        );
      },
    );
  }
}
