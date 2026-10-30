import 'package:flutter/material.dart';

/// Pure collapsing-header maths, unit-tested on its own.
class FpCollapseMath {
  const FpCollapseMath._();

  /// Collapse fraction for [shrinkOffset]: 0 fully expanded, 1 fully
  /// collapsed. A header that cannot shrink is always 1.
  static double fraction(
    double shrinkOffset, {
    required double maxExtent,
    required double minExtent,
  }) {
    final range = maxExtent - minExtent;
    if (range <= 0) return 1;
    return (shrinkOffset / range).clamp(0.0, 1.0);
  }

  /// Linear interpolation from [a] (expanded) to [b] (collapsed) at [t].
  static double lerp(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);

  /// Fades a layer out over the first [until] of the collapse (so content
  /// that has no room in the collapsed bar disappears early).
  static double fadeOut(double t, {double until = 0.6}) =>
      until <= 0 ? 0 : (1 - t / until).clamp(0.0, 1.0);

  /// Fades a layer in over the last `1 − from` of the collapse.
  static double fadeIn(double t, {double from = 0.6}) =>
      from >= 1 ? 1 : ((t - from) / (1 - from)).clamp(0.0, 1.0);
}

/// Builds the header for collapse fraction [t] (0 expanded, 1 collapsed).
typedef FpCollapsingHeaderBuilder =
    Widget Function(BuildContext context, double t);

/// A pinned [SliverPersistentHeaderDelegate] that hands its builder the
/// collapse fraction instead of raw pixels. Rebuilds when [rebuildKey]
/// changes (pass the data the header shows).
class FpCollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  const FpCollapsingHeaderDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.builder,
    this.rebuildKey,
  }) : assert(
         expandedHeight >= collapsedHeight,
         'expandedHeight must be at least collapsedHeight',
       );

  final double expandedHeight;
  final double collapsedHeight;
  final FpCollapsingHeaderBuilder builder;
  final Object? rebuildKey;

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => builder(
    context,
    FpCollapseMath.fraction(
      shrinkOffset,
      maxExtent: maxExtent,
      minExtent: minExtent,
    ),
  );

  @override
  bool shouldRebuild(FpCollapsingHeaderDelegate oldDelegate) =>
      oldDelegate.expandedHeight != expandedHeight ||
      oldDelegate.collapsedHeight != collapsedHeight ||
      oldDelegate.rebuildKey != rebuildKey;
}

/// A pinned collapsing header sliver: the convenience wrapper around
/// [FpCollapsingHeaderDelegate].
class FpCollapsingHeader extends StatelessWidget {
  const FpCollapsingHeader({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.builder,
    super.key,
    this.rebuildKey,
  });

  final double expandedHeight;
  final double collapsedHeight;
  final FpCollapsingHeaderBuilder builder;
  final Object? rebuildKey;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: FpCollapsingHeaderDelegate(
        expandedHeight: expandedHeight,
        collapsedHeight: collapsedHeight,
        builder: builder,
        rebuildKey: rebuildKey,
      ),
    );
  }
}
