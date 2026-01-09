import 'package:flutter/material.dart';

/// CRED-style page transition with scale and fade
class CredPageTransition extends PageRouteBuilder {
  final Widget page;
  final Duration transitionDuration;
  final Curve curve;

  CredPageTransition({
    required this.page,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: transitionDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.95,
                  end: 1.0,
                ).animate(curvedAnimation),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(curvedAnimation),
                  child: child,
                ),
              ),
            );
          },
        );
}

