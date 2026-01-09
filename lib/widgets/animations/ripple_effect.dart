import 'package:flutter/material.dart';

class RippleEffect extends StatefulWidget {
  final Widget child;
  final Color rippleColor;
  final VoidCallback? onTap;
  final double borderRadius;

  const RippleEffect({
    super.key,
    required this.child,
    this.rippleColor = const Color(0x40000000),
    this.onTap,
    this.borderRadius = 8.0,
  });

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
    _controller.forward().then((_) {
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTap: widget.onTap,
      child: CustomPaint(
        painter: _RipplePainter(
          animation: _animation,
          tapPosition: _tapPosition,
          color: widget.rippleColor,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Offset? tapPosition;
  final Color color;

  _RipplePainter({
    required this.animation,
    required this.tapPosition,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (tapPosition == null) return;

    final paint = Paint()
      ..color = color.withOpacity((1.0 - animation.value) * 0.3)
      ..style = PaintingStyle.fill;

    final radius = animation.value * size.longestSide * 1.5;

    canvas.drawCircle(tapPosition!, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
        oldDelegate.tapPosition != tapPosition;
  }
}

