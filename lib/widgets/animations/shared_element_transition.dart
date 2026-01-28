import 'package:flutter/material.dart';

class SharedElementTransition extends StatelessWidget {

  const SharedElementTransition({
    required this.child, required this.tag, super.key,
    this.duration = const Duration(milliseconds: 400),
  });
  final Widget child;
  final String tag;
  final Duration duration;

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
        final toHero = toHeroContext.widget as Hero;
        return RotationTransition(
          turns: animation,
          child: toHero.child,
        );
      },
      child: child,
    );
  }
}

