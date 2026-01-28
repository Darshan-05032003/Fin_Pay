import 'dart:math' as math;

import 'package:flutter/material.dart';

class Card3DFlip extends StatefulWidget {

  const Card3DFlip({
    required this.frontChild, super.key,
    this.backChild,
    this.flipOnTap = true,
    this.perspective = 0.001,
  });
  final Widget frontChild;
  final Widget? backChild;
  final bool flipOnTap;
  final double perspective;

  @override
  State<Card3DFlip> createState() => _Card3DFlipState();
}

class _Card3DFlipState extends State<Card3DFlip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (widget.flipOnTap) {
      setState(() {
        _isFlipped = !_isFlipped;
        if (_isFlipped) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          final isFrontVisible = angle < math.pi / 2 || angle > 3 * math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, widget.perspective)
              ..rotateY(angle),
            child: isFrontVisible ? widget.frontChild : (widget.backChild ?? widget.frontChild),
          );
        },
      ),
    );
  }
}

