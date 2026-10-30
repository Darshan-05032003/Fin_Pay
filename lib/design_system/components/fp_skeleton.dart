import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// Shares one shimmer ticker between every [FpSkeleton] below it, so a
/// screen with 50 placeholders runs one animation, not fifty.
class FpSkeletonGroup extends StatefulWidget {
  const FpSkeletonGroup({required this.child, super.key});

  final Widget child;

  /// Period of one shimmer sweep.
  static const Duration period = Duration(milliseconds: 1400);

  @override
  State<FpSkeletonGroup> createState() => _FpSkeletonGroupState();
}

class _FpSkeletonGroupState extends State<FpSkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FpSkeletonGroup.period,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FpShimmerScope(animation: _controller, child: widget.child);
  }
}

class _FpShimmerScope extends InheritedWidget {
  const _FpShimmerScope({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FpShimmerScope>()?.animation;

  @override
  bool updateShouldNotify(_FpShimmerScope oldWidget) =>
      oldWidget.animation != animation;
}

/// A shimmering placeholder block. Replaces `SkeletonLoader` and
/// `ShimmerLoader`.
///
/// The shimmer is a plain [LinearGradient] whose alignment slides across the
/// box: no `ShaderMask`, no `saveLayer`, so it is cheap in long lists. Wrap a
/// screen's skeletons in [FpSkeletonGroup] to share a single ticker. With
/// reduced motion the block is static.
class FpSkeleton extends StatefulWidget {
  const FpSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 0,
  });

  /// A circular avatar placeholder.
  const FpSkeleton.circle({required double size, super.key})
    : width = size,
      height = size,
      radius = size / 2;

  final double width;
  final double height;
  final double radius;

  @override
  State<FpSkeleton> createState() => _FpSkeletonState();
}

class _FpSkeletonState extends State<FpSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shared = _FpShimmerScope.maybeOf(context);
    if (shared != null) {
      _own?.dispose();
      _own = null;
      _animation = shared;
      return;
    }
    if (_own != null) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    _own = AnimationController(vsync: this, duration: FpSkeletonGroup.period);
    if (!reduce) _own!.repeat();
    _animation = _own;
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    final animation = _animation!;
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              // Slide the highlight from left (-1.5) to right (+1.5).
              final x = -1.5 + 3 * animation.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius),
                  gradient: LinearGradient(
                    begin: Alignment(x - 1, 0),
                    end: Alignment(x + 1, 0),
                    colors: [c.surfaceRaised, c.surfaceHigh, c.surfaceRaised],
                    stops: const [0.25, 0.5, 0.75],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A list-row placeholder: avatar, two lines and a trailing amount.
class FpSkeletonRow extends StatelessWidget {
  const FpSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: FpSpacing.md),
      child: Row(
        children: [
          FpSkeleton.circle(size: 44),
          SizedBox(width: FpSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FpSkeleton(height: 14),
                SizedBox(height: FpSpacing.sm),
                FpSkeleton(width: 120, height: 12),
              ],
            ),
          ),
          SizedBox(width: FpSpacing.lg),
          FpSkeleton(width: 72, height: 18),
        ],
      ),
    );
  }
}
