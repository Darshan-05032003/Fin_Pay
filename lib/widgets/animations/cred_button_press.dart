import 'package:flutter/material.dart';

/// CRED-style button press animation with scale and ripple
class CredButtonPress extends StatefulWidget {

  const CredButtonPress({
    required this.child, super.key,
    this.onTap,
    this.duration = const Duration(milliseconds: 150),
    this.scaleAmount = 0.96,
    this.rippleColor,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;
  final double scaleAmount;
  final Color? rippleColor;

  @override
  State<CredButtonPress> createState() => _CredButtonPressState();
}

class _CredButtonPressState extends State<CredButtonPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: widget.scaleAmount,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: widget.child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

