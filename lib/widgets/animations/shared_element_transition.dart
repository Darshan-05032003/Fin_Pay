import 'package:flutter/material.dart';

class SharedElementTransition extends StatelessWidget {
  final Widget child;
  final String tag;
  final Duration duration;

  const SharedElementTransition({
    super.key,
    required this.child,
    required this.tag,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        final Hero toHero = toHeroContext.widget as Hero;
        return RotationTransition(
          turns: animation,
          child: toHero.child,
        );
      },
      child: child,
    );
  }
}

