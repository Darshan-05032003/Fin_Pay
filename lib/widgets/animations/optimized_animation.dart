import 'package:flutter/material.dart';

/// Optimized animation widget that uses RepaintBoundary for better performance
class OptimizedAnimation extends StatelessWidget {

  const OptimizedAnimation({
    required this.child, super.key,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.useRepaintBoundary = true,
  });
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool useRepaintBoundary;

  @override
  Widget build(BuildContext context) {
    Widget animatedChild = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: child,
    );

    if (useRepaintBoundary) {
      animatedChild = RepaintBoundary(child: animatedChild);
    }

    return animatedChild;
  }
}

/// Optimized list animation with lazy loading
class OptimizedListAnimation extends StatelessWidget {

  const OptimizedListAnimation({
    required this.child, required this.index, super.key,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  });
  final Widget child;
  final int index;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: duration.inMilliseconds + (index * 50)),
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: RepaintBoundary(child: child),
    );
  }
}

/// Performance-optimized fade animation
class OptimizedFadeIn extends StatelessWidget {

  const OptimizedFadeIn({
    required this.child, super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 300),
  });
  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Opacity(opacity: 0, child: child);
        }
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: child,
            );
          },
          child: RepaintBoundary(child: child),
        );
      },
    );
  }
}

