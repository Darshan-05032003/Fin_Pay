import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class SwipeToDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismiss;
  final Color? background;
  final IconData? icon;
  final String uniqueKey;

  const SwipeToDismiss({
    super.key,
    required this.child,
    required this.uniqueKey,
    this.onDismiss,
    this.background,
    this.icon,
  });

  @override
  State<SwipeToDismiss> createState() => _SwipeToDismissState();
}

class _SwipeToDismissState extends State<SwipeToDismiss>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss(DismissDirection direction) async {
    if (_isDismissing) return;
    _isDismissing = true;

    await HapticService.mediumImpact();
    await _controller.forward();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.uniqueKey),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _handleDismiss(direction),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: widget.background ?? Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          widget.icon ?? Icons.delete_outline,
          color: Colors.white,
          size: 32,
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.translate(
              offset: Offset(
                _offsetAnimation.value.dx * MediaQuery.of(context).size.width,
                0,
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

