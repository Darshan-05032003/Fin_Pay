import 'package:flutter/material.dart';

class SpringAnimation extends StatefulWidget {
  final Widget child;
  final double damping;
  final double stiffness;
  final double mass;
  final Offset startOffset;
  final Offset endOffset;

  const SpringAnimation({
    super.key,
    required this.child,
    this.damping = 15.0,
    this.stiffness = 200.0,
    this.mass = 1.0,
    this.startOffset = Offset.zero,
    this.endOffset = Offset.zero,
  });

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
      duration: const Duration(milliseconds: 800),
    );

    // Spring physics applied through curve animations

    _offsetAnimation = Tween<Offset>(
      begin: widget.startOffset,
      end: widget.endOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
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
    return AnimatedBuilder(
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
    );
  }
}

