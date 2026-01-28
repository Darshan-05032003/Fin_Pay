import 'package:fin_pay/constants/theme.dart';
import 'package:flutter/material.dart';

/// Neumorphic container widget that creates 3D shadow effects
/// Supports both extruded (popping out) and inset (pressed in) styles
class NeumorphicContainer extends StatelessWidget {

  const NeumorphicContainer({
    required this.child, super.key,
    this.isExtruded = true,
    this.borderRadius = 20.0,
    this.color,
    this.padding,
    this.margin,
    this.blurRadius = 15.0,
    this.spreadRadius = 1.0,
  });
  final Widget child;
  final bool isExtruded; // true = popping out, false = pressed in
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blurRadius;
  final double spreadRadius;

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppTheme.credSurfaceCard;
    final lightShadow = isExtruded
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.3);
    final darkShadow = isExtruded
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.02);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Light shadow (top-left)
          BoxShadow(
            color: lightShadow,
            offset: isExtruded ? const Offset(-4, -4) : const Offset(4, 4),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
          // Dark shadow (bottom-right)
          BoxShadow(
            color: darkShadow,
            offset: isExtruded ? const Offset(4, 4) : const Offset(-4, -4),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Neumorphic button with press animation
class NeumorphicButton extends StatefulWidget {

  const NeumorphicButton({
    required this.child, super.key,
    this.onPressed,
    this.borderRadius = 16.0,
    this.color,
    this.padding,
    this.margin,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: NeumorphicContainer(
          isExtruded: !_isPressed,
          borderRadius: widget.borderRadius,
          color: widget.color,
          padding: widget.padding,
          margin: widget.margin,
          child: widget.child,
        ),
      ),
    );
  }
}

