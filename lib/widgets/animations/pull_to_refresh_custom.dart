import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class CustomPullToRefresh extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? backgroundColor;
  final Color? color;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.backgroundColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await HapticService.mediumImpact();
        await onRefresh();
      },
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      color: color ?? Theme.of(context).primaryColor,
      strokeWidth: 3.0,
      displacement: 40.0,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      child: child,
    );
  }
}

