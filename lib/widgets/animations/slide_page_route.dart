import 'package:flutter/material.dart';

class SlidePageRoute<T> extends PageRouteBuilder<T> {

  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.rightToLeft,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offset = direction == SlideDirection.rightToLeft
                ? const Offset(1, 0)
                : direction == SlideDirection.leftToRight
                    ? const Offset(-1, 0)
                    : direction == SlideDirection.bottomToTop
                        ? const Offset(0, 1)
                        : const Offset(0, -1);

            final slideAnimation = Tween<Offset>(
              begin: offset,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0,
              end: 1,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ));

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
  final Widget page;
  final SlideDirection direction;
}

enum SlideDirection {
  rightToLeft,
  leftToRight,
  bottomToTop,
  topToBottom,
}

