import 'package:fin_pay/constants/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// CRED NeoPOP Button - 100% Authentic Implementation
/// Features hard 45-degree shadows (8dp depth) and haptic feedback
class NeoPopButton extends StatefulWidget {

  const NeoPopButton({
    required this.child, super.key,
    this.onTapUp,
    this.onTapDown,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.padding,
    this.depth,
    this.isDisabled = false,
  });
  final Widget child;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapDown;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;
  final EdgeInsetsGeometry? padding;
  final double? depth;
  final bool isDisabled;

  @override
  State<NeoPopButton> createState() => _NeoPopButtonState();
}

class _NeoPopButtonState extends State<NeoPopButton>
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
    _scaleAnimation = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isDisabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.mediumImpact();
    widget.onTapDown?.call();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.isDisabled) return;
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTapUp?.call();
  }

  void _handleTapCancel() {
    if (widget.isDisabled) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final depth = widget.depth ?? 8.0;
    final backgroundColor = widget.color ?? AppTheme.credSurfaceCard;
    final borderColor = widget.borderColor ?? AppTheme.credOrangeSunshine;
    final borderWidth = widget.borderWidth ?? 1.0;
    final padding = widget.padding ??
        EdgeInsets.symmetric(
          horizontal: AppTheme.grid(2.5), // 20px
          vertical: AppTheme.grid(1.875), // 15px
        );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.fromBorderSide(
              BorderSide(
                color: widget.isDisabled
                    ? AppTheme.credTextTertiary
                    : borderColor,
                width: borderWidth,
              ),
            ),
            borderRadius: BorderRadius.circular(AppTheme.grid(2)), // 16px
            boxShadow: AppTheme.neopopHardShadow(
              shadowColor: Colors.black.withOpacity(0.5),
              depth: _isPressed ? 0 : depth,
              isPressed: _isPressed,
            ),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: widget.isDisabled
                  ? AppTheme.credTextTertiary
                  : AppTheme.credPopWhite,
              fontWeight: FontWeight.w900, // ExtraBold
              fontFamily: 'Inter',
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// NeoPOP Button with Orange Sunshine accent (Primary CTA)
class NeoPopPrimaryButton extends StatelessWidget {

  const NeoPopPrimaryButton({
    required this.text, super.key,
    this.onTap,
    this.isDisabled = false,
    this.padding,
  });
  final String text;
  final VoidCallback? onTap;
  final bool isDisabled;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return NeoPopButton(
      onTapUp: isDisabled ? null : onTap,
      color: AppTheme.credOrangeSunshine,
      borderColor: AppTheme.credOrangeSunshine,
      isDisabled: isDisabled,
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.credPureBackground,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// NeoPOP Button with Neon Green (Success/Cash)
class NeoPopSuccessButton extends StatelessWidget {

  const NeoPopSuccessButton({
    required this.text, super.key,
    this.onTap,
    this.isDisabled = false,
  });
  final String text;
  final VoidCallback? onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return NeoPopButton(
      onTapUp: isDisabled ? null : onTap,
      color: AppTheme.credNeonGreen,
      borderColor: AppTheme.credNeonGreen,
      isDisabled: isDisabled,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.credPureBackground,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// NeoPOP Card with hard shadows
class NeoPopCard extends StatelessWidget {

  const NeoPopCard({
    required this.child, super.key,
    this.padding,
    this.margin,
    this.color,
    this.depth,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? depth;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.all(AppTheme.grid(2)), // 16px
      padding: padding ?? EdgeInsets.all(AppTheme.grid(3)), // 24px
      decoration: BoxDecoration(
        color: color ?? AppTheme.credSurfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.grid(2.5)), // 20px
        boxShadow: AppTheme.neopopHardShadow(
          depth: depth ?? 8.0,
        ),
      ),
      child: child,
    );
  }
}

