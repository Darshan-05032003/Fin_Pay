import 'package:fin_pay/services/haptic_service.dart';
import 'package:flutter/material.dart';

class DraggableCard extends StatefulWidget {

  const DraggableCard({
    required this.child, super.key,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.threshold = 100.0,
  });
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final double threshold;

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  Offset _position = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _position += details.delta;
    });
    HapticService.lightImpact();
  }

  void _onPanEnd(DragEndDetails details) {
    final shouldSwipeLeft = _position.dx < -widget.threshold;
    final shouldSwipeRight = _position.dx > widget.threshold;

    if (shouldSwipeLeft) {
      _animateOut(const Offset(-2, 0));
      widget.onSwipeLeft?.call();
    } else if (shouldSwipeRight) {
      _animateOut(const Offset(2, 0));
      widget.onSwipeRight?.call();
    } else {
      _animateBack();
    }

    setState(() {
      _isDragging = false;
    });
  }

  void _animateOut(Offset target) {
    final screenWidth = MediaQuery.of(context).size.width;
    _offsetAnimation = Tween<Offset>(
      begin: _position / screenWidth,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _rotationAnimation = Tween<double>(
      begin: _position.dx / screenWidth * 0.1,
      end: target.dx * 0.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  void _animateBack() {
    final screenWidth = MediaQuery.of(context).size.width;
    _offsetAnimation = Tween<Offset>(
      begin: _position / screenWidth,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _position.dx / screenWidth * 0.1,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward().then((_) {
      _controller.reset();
      setState(() {
        _position = Offset.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = _isDragging ? _position / screenWidth : _offsetAnimation.value;
    final rotation = _isDragging
        ? _position.dx / screenWidth * 0.1
        : _rotationAnimation.value;
    final scale = _isDragging ? 1.0 - (_position.distance.abs() / screenWidth * 0.1).clamp(0.0, 0.1) : _scaleAnimation.value;
    final opacity = 1.0 - (_position.dx.abs() / screenWidth * 0.5).clamp(0.0, 0.5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateZ(rotation)
            ..scale(scale),
          child: Opacity(
            opacity: opacity,
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Transform.translate(
                offset: Offset(offset.dx * screenWidth, offset.dy * screenWidth),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

