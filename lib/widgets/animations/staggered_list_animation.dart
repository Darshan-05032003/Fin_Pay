import 'package:flutter/material.dart';

class StaggeredListAnimation extends StatelessWidget {

  const StaggeredListAnimation({
    required this.child, required this.index, super.key,
    this.duration = const Duration(milliseconds: 300),
  });
  final Widget child;
  final int index;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + (const Duration(milliseconds: 100) * index),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

