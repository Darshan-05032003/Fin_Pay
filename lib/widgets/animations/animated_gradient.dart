import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedGradient extends StatefulWidget {

  const AnimatedGradient({
    required this.child, required this.colors, super.key,
    this.duration = const Duration(seconds: 3),
  });
  final Widget child;
  final List<Color> colors;
  final Duration duration;

  @override
  State<AnimatedGradient> createState() => _AnimatedGradientState();
}

class _AnimatedGradientState extends State<AnimatedGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
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
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft + Alignment(
                math.sin(_controller.value * 2 * math.pi) * 0.1,
                math.cos(_controller.value * 2 * math.pi) * 0.1,
              ),
              end: Alignment.bottomRight + Alignment(
                math.cos(_controller.value * 2 * math.pi) * 0.1,
                math.sin(_controller.value * 2 * math.pi) * 0.1,
              ),
              colors: widget.colors,
              stops: [
                0.0 + _controller.value * 0.1,
                0.5 + _controller.value * 0.1,
                1.0 - _controller.value * 0.1,
              ],
            ),
          ),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

