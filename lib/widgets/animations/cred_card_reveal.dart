import 'package:flutter/material.dart';
import 'dart:math' as math;

/// CRED-style card reveal animation with 3D perspective
class CredCardReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double perspective;
  final bool revealFromBottom;

  const CredCardReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.perspective = 0.001,
    this.revealFromBottom = true,
  });

  @override
  State<CredCardReveal> createState() => _CredCardRevealState();
}

class _CredCardRevealState extends State<CredCardReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _rotationAnimation = Tween<double>(
      begin: widget.revealFromBottom ? 0.1 : -0.1,
      end: 0.0,
    ).animate(_animation);

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animation);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, widget.perspective)
            ..rotateX(_rotationAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - _opacityAnimation.value)),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

