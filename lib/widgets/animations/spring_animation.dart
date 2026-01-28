import 'package:flutter/material.dart';

class SpringAnimation extends StatefulWidget {

  const SpringAnimation({
    required this.child, super.key,
    this.damping = 15.0,
    this.stiffness = 200.0,
    this.mass = 1.0,
    this.startOffset = Offset.zero,
    this.endOffset = Offset.zero,
  });
  final Widget child;
  final double damping;
  final double stiffness;
  final double mass;
  final Offset startOffset;
  final Offset endOffset;

  @override
  State<SpringAnimation> createState() => _SpringAnimationState();
}

class _SpringAnimationState extends State<SpringAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Smoother spring physics using optimized curves

    _offsetAnimation = Tween<Offset>(
      begin: widget.startOffset,
      end: widget.endOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.translate(
              offset: _offsetAnimation.value,
              child: widget.child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

