import 'package:fin_pay/core/di/injection_container.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:flutter/material.dart';

class CustomPullToRefresh extends StatelessWidget {
  const CustomPullToRefresh({
    required this.child,
    required this.onRefresh,
    super.key,
    this.backgroundColor,
    this.color,
  });
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await sl<HapticService>().medium();
        await onRefresh();
      },
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      color: color ?? Theme.of(context).primaryColor,
      strokeWidth: 3,
      child: child,
    );
  }
}
