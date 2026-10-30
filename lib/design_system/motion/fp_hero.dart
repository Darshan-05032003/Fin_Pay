import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// Hero helpers: one consistent flight for every shared element.
///
/// The shuttle cross-fades the destination over the source on an emphasized
/// curve, wrapped in a transparent [Material] so text keeps its style in
/// flight. Replaces `SharedElementTransition`.
class FpHero extends StatelessWidget {
  const FpHero({required this.tag, required this.child, super.key});

  final Object tag;
  final Widget child;

  /// The shared flight shuttle. Pass to any plain [Hero] that cannot use
  /// [FpHero].
  static Widget flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = fromHeroContext.widget as Hero;
    final to = toHeroContext.widget as Hero;
    final curved = CurvedAnimation(
      parent: animation,
      curve: FpMotion.emphasizedDecelerate,
    );
    final fade = flightDirection == HeroFlightDirection.push
        ? curved
        : ReverseAnimation(curved);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(opacity: ReverseAnimation(fade), child: from.child),
          FadeTransition(opacity: fade, child: to.child),
        ],
      ),
    );
  }

  /// A [RectTween] with an emphasized arc for hero rects.
  static RectTween createRectTween(Rect? begin, Rect? end) =>
      MaterialRectArcTween(begin: begin, end: end);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: flightShuttleBuilder,
      createRectTween: createRectTween,
      child: child,
    );
  }
}
