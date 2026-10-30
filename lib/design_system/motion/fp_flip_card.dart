import 'dart:math' as math;

import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Pure flip maths, unit-tested on its own.
class FpFlipMath {
  const FpFlipMath._();

  /// Perspective entry (row 3, column 2) of the transform.
  static const double perspective = 0.0012;

  /// Rotation about Y at progress [t] in `[0, 1]`.
  static double angle(double t) => t.clamp(0.0, 1.0) * math.pi;

  /// True when the back face is the one facing the viewer.
  static bool showsBack(double t) => t >= 0.5;

  /// The transform for the face that is visible at [t]. The back face is
  /// counter-rotated by π so it reads left-to-right (the legacy flip
  /// rendered it mirrored).
  static Matrix4 transform(double t) {
    final a = angle(t);
    final visible = showsBack(t) ? a - math.pi : a;
    return Matrix4.identity()
      ..setEntry(3, 2, perspective)
      ..rotateY(visible);
  }
}

/// A card with a 3D flip between [front] and [back].
///
/// Flips whenever [flipped] changes (400 ms, standard curve). The visible
/// face swaps at 90°, and the back is drawn un-mirrored. With reduced
/// motion the faces swap with no rotation. Tap (when [onTap] is given) and
/// semantics are exposed on the whole card.
class FpFlipCard extends StatefulWidget {
  const FpFlipCard({
    required this.front,
    required this.back,
    required this.flipped,
    super.key,
    this.onTap,
    this.semanticLabel,
    this.duration = FpMotion.emphasized,
  });

  final Widget front;
  final Widget back;
  final bool flipped;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Duration duration;

  @override
  State<FpFlipCard> createState() => _FpFlipCardState();
}

class _FpFlipCardState extends State<FpFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.flipped ? 1 : 0,
  );

  /// Current flip progress (tests).
  double get progress => _controller.value;

  @override
  void didUpdateWidget(FpFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped == widget.flipped) return;
    final target = widget.flipped ? 1.0 : 0.0;
    if (FpMotion.of(context).reduce) {
      _controller.value = target;
    } else {
      _controller.animateTo(target, curve: FpMotion.standardCurve);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final back = FpFlipMath.showsBack(t);
          return Transform(
            transform: FpFlipMath.transform(t),
            alignment: Alignment.center,
            child: back
                ? KeyedSubtree(
                    key: const ValueKey('fp-flip-back'),
                    child: widget.back,
                  )
                : KeyedSubtree(
                    key: const ValueKey('fp-flip-front'),
                    child: widget.front,
                  ),
          );
        },
      ),
    );
    final tap = widget.onTap;
    return Semantics(
      container: true,
      explicitChildNodes: widget.semanticLabel != null,
      label: widget.semanticLabel,
      button: tap != null,
      onTap: tap,
      child: tap == null
          ? body
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: tap,
              child: body,
            ),
    );
  }
}
