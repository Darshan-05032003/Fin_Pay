import 'package:flutter/material.dart';

/// CRED-style animated number counter with smooth transitions
class CredNumberCounter extends StatefulWidget {

  const CredNumberCounter({
    required this.value, super.key,
    this.style,
    this.prefix,
    this.suffix,
    this.duration = const Duration(milliseconds: 1500),
    this.decimalPlaces = 2,
    this.curve = Curves.easeOutCubic,
  });
  final double value;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final Duration duration;
  final int decimalPlaces;
  final Curve curve;

  @override
  State<CredNumberCounter> createState() => _CredNumberCounterState();
}

class _CredNumberCounterState extends State<CredNumberCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(CredNumberCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _animation.value;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final displayValue = _animation.value;
          final formattedValue = displayValue.toStringAsFixed(widget.decimalPlaces);
          return Text(
            '${widget.prefix ?? ''}$formattedValue${widget.suffix ?? ''}',
            style: widget.style,
          );
        },
      ),
    );
  }
}

