import 'package:flutter/material.dart';
import 'dart:math' as math;

class IconMorph extends StatefulWidget {
  final IconData startIcon;
  final IconData endIcon;
  final Duration duration;
  final Color? color;
  final double size;
  final bool animateOnTap;

  const IconMorph({
    super.key,
    required this.startIcon,
    required this.endIcon,
    this.duration = const Duration(milliseconds: 500),
    this.color,
    this.size = 24.0,
    this.animateOnTap = true,
  });

  @override
  State<IconMorph> createState() => _IconMorphState();
}

class _IconMorphState extends State<IconMorph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
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

  void morph() {
    if (_controller.status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.animateOnTap ? morph : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final progress = _animation.value;
          final scale = 1.0 + (0.2 * math.sin(progress * math.pi));

          return Transform.scale(
            scale: scale,
            child: Icon(
              progress < 0.5 ? widget.startIcon : widget.endIcon,
              color: widget.color ?? Theme.of(context).iconTheme.color,
              size: widget.size,
            ),
          );
        },
      ),
    );
  }
}
