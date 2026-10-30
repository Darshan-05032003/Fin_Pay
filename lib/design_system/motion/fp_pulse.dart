import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';

/// A finite attention pulse (scale up and back) for live cues such as an
/// unread dot or a resend countdown. Replaces `PulseAnimation`.
///
/// Pulses [pulses] times then stops; pass `pulses: null` only for a truly
/// live indicator. With reduced motion no pulse runs.
class FpPulse extends StatefulWidget {
  const FpPulse({
    required this.child,
    super.key,
    this.pulses = 3,
    this.minScale = 1,
    this.maxScale = 1.08,
    this.duration = const Duration(milliseconds: 700),
    this.active = true,
  }) : assert(pulses == null || pulses > 0, 'pulses must be > 0 or null');

  final Widget child;

  /// Number of pulses, or null for infinite (avoid).
  final int? pulses;
  final double minScale;
  final double maxScale;

  /// Duration of one up-and-down pulse.
  final Duration duration;

  /// When false the child sits still at [minScale].
  final bool active;

  @override
  State<FpPulse> createState() => _FpPulseState();
}

class _FpPulseState extends State<FpPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: widget.minScale,
        end: widget.maxScale,
      ).chain(CurveTween(curve: FpMotion.standardCurve)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: widget.maxScale,
        end: widget.minScale,
      ).chain(CurveTween(curve: FpMotion.standardCurve)),
      weight: 1,
    ),
  ]).animate(_controller);
  int _done = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _maybeStart();
  }

  @override
  void didUpdateWidget(FpPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _done = 0;
      if (widget.active) {
        _maybeStart();
      } else {
        _controller
          ..stop()
          ..value = 0;
      }
    }
  }

  void _maybeStart() {
    if (!widget.active) return;
    if (FpMotion.of(context).reduce) return;
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _done++;
    final limit = widget.pulses;
    if (limit == null || _done < limit) {
      _controller.forward(from: 0);
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
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
