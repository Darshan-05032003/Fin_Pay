import 'dart:async';
import 'dart:math' as math;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/components/fp_button.dart';
import 'package:fin_pay/design_system/components/fp_processing_ring.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/motion/fp_submit_guard.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_depth.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// Pure geometry and decisions of the swipe-to-pay slider.
abstract final class FpSwipeMath {
  /// Fraction of the travel the thumb must pass for the swipe to confirm.
  static const double threshold = 0.85;

  /// Progress points at which a haptic tick plays while dragging forwards.
  static const List<double> ticks = [0.25, 0.5, 0.75];

  /// Horizontal velocity (px/s) that confirms from [flingMinProgress].
  static const double flingVelocity = 1200;

  /// A fling never confirms from before this progress.
  static const double flingMinProgress = 0.5;

  /// The thumb's travel inside a track of [trackWidth] (never negative).
  static double travel({
    required double trackWidth,
    required double thumbSize,
    required double inset,
  }) => math.max(0, trackWidth - thumbSize - 2 * inset);

  /// Progress (0..1) of a thumb dragged [dx] pixels along [travel].
  static double progressFor({required double dx, required double travel}) =>
      travel <= 0 ? 0 : (dx / travel).clamp(0.0, 1.0);

  /// Whether a release at [progress] with [velocity] (px/s) confirms.
  static bool shouldComplete({required double progress, double velocity = 0}) {
    if (progress >= threshold) return true;
    return progress >= flingMinProgress && velocity >= flingVelocity;
  }

  /// Where the thumb settles after a release: 1 (confirm) or 0 (snap back).
  static double snapTarget({required double progress, double velocity = 0}) =>
      shouldComplete(progress: progress, velocity: velocity) ? 1 : 0;

  /// The ticks crossed moving forwards from [from] to [to] (none backwards).
  static List<double> ticksCrossed({required double from, required double to}) {
    if (to <= from) return const [];
    return [
      for (final t in ticks)
        if (from < t && to >= t) t,
    ];
  }

  /// Number of ticks at or below [progress].
  static int ticksPassed(double progress) =>
      ticks.where((t) => progress >= t).length;

  /// Opacity of the "swipe to pay" label: gone by 40 % of the drag.
  static double labelOpacity(double progress) =>
      (1 - progress * 2.5).clamp(0.0, 1.0);
}

/// NeoPOP swipe-to-pay slider.
///
/// The thumb follows the finger; haptic ticks play at 25 / 50 / 75 %;
/// releasing past [FpSwipeMath.threshold] (or flinging from half way)
/// springs the thumb to the end, plays a heavy haptic and calls
/// [onConfirmed] exactly once. Released early it springs back
/// ([FpSprings.slider]). While [processing] is true the slider is locked at
/// the end and shows an [FpProcessingRing]; when the parent clears
/// [processing] the thumb springs back and a new swipe is possible.
///
/// Screen readers get one button ("double tap to pay") that triggers the
/// same confirmation. With reduced motion the slider is replaced by a plain
/// [FpButton] with the same label, loading state and callback.
class FpSwipeToPay extends StatefulWidget {
  const FpSwipeToPay({
    required this.label,
    required this.onConfirmed,
    super.key,
    this.processing = false,
    this.enabled = true,
    this.processingLabel = 'Processing',
    this.semanticLabel,
    this.haptics,
    this.height = 64,
    this.thumbSize = 56,
  });

  /// Shown on the track ("Swipe to pay ₹1,200.00").
  final String label;

  /// Called once per confirmed swipe. While its future is pending (and for
  /// the submit guard's lockout) further confirmations are dropped.
  final FutureOr<void> Function() onConfirmed;

  /// Locks the thumb at the end and shows the ring.
  final bool processing;
  final bool enabled;

  /// Shown while [processing].
  final String processingLabel;
  final String? semanticLabel;
  final HapticService? haptics;
  final double height;
  final double thumbSize;

  /// Space between the track border and the thumb.
  static const double inset = 4;

  @override
  State<FpSwipeToPay> createState() => _FpSwipeToPayState();
}

class _FpSwipeToPayState extends State<FpSwipeToPay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: FpMotion.standard,
  );
  final FpSubmitGuard _guard = FpSubmitGuard();
  double _travel = 1;
  bool _dragging = false;

  /// True from a confirmation until the thumb has been released back.
  bool _fired = false;

  bool get _locked => widget.processing || _fired;
  bool get _interactive => widget.enabled && !_locked;

  @override
  void initState() {
    super.initState();
    if (widget.processing) _progress.value = 1;
  }

  @override
  void didUpdateWidget(FpSwipeToPay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.processing && !oldWidget.processing) {
      _dragging = false;
      _animateTo(1);
    } else if (!widget.processing && oldWidget.processing) {
      _fired = false;
      _animateTo(0);
    }
  }

  @override
  void dispose() {
    _guard.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _animateTo(double target, {double velocity = 0}) {
    if (_progress.value == target) return;
    _progress.animateWith(
      FpSprings.simulation(
        FpSprings.slider,
        start: _progress.value,
        end: target,
        velocity: velocity,
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    if (!_interactive || _dragging) return;
    _dragging = true;
    _progress.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging || !_interactive) return;
    final before = _progress.value;
    final after = (before + details.delta.dx / _travel).clamp(0.0, 1.0);
    _progress.value = after;
    for (final _ in FpSwipeMath.ticksCrossed(from: before, to: after)) {
      playHaptic(widget.haptics, HapticType.selection);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    if (!_interactive) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final target = FpSwipeMath.snapTarget(
      progress: _progress.value,
      velocity: velocity,
    );
    if (target == 1) {
      _confirm(velocity: velocity / _travel);
    } else {
      _animateTo(0, velocity: velocity / _travel);
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    if (_fired) return;
    _animateTo(0);
  }

  /// Confirms once: thumb to the end, heavy haptic, callback through the
  /// guard. If the parent does not lock the slider by the time the action
  /// completes, the thumb returns and the slider is usable again.
  void _confirm({double velocity = 0}) {
    if (!_interactive) return;
    _fired = true;
    _animateTo(1, velocity: velocity);
    playHaptic(widget.haptics, HapticType.heavy);
    final ran = _guard.run(() async {
      try {
        await widget.onConfirmed();
      } finally {
        // The parent's setState (processing = true) lands on the next
        // frame; decide after it whether to release the thumb.
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || widget.processing) return;
            _fired = false;
            _animateTo(0);
          });
          WidgetsBinding.instance.scheduleFrame();
        }
      }
    });
    if (!ran) _fired = false;
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    if (FpMotion.of(context).reduce) {
      return FpButton(
        label: widget.label,
        onPressed: widget.enabled ? widget.onConfirmed : null,
        isLoading: widget.processing,
        enabled: widget.enabled,
        size: FpButtonSize.large,
        semanticLabel: widget.semanticLabel,
        haptics: widget.haptics,
      );
    }

    final enabledLook = widget.enabled;
    final depth = fp.metrics.depthButton;
    final trackHeight = widget.height - depth;
    final thumbSize = widget.thumbSize;
    final edge = enabledLook ? FpEdge.accent : FpEdge.disabled;
    final labelStyle = fp.text.label.copyWith(
      color: enabledLook ? c.textPrimary : c.textDisabled,
    );

    final thumb = SizedBox(
      key: const ValueKey('fp-swipe-thumb'),
      width: thumbSize,
      height: thumbSize,
      child: Stack(
        children: [
          Positioned(
            left: depth,
            top: depth,
            right: 0,
            bottom: 0,
            child: ColoredBox(color: edge.bottom),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: depth,
            bottom: depth,
            child: ColoredBox(
              color: enabledLook ? c.accent : c.disabledFace,
              child: Center(
                child: widget.processing
                    ? FpProcessingRing(
                        size: thumbSize * 0.5,
                        strokeWidth: 3,
                        color: c.onPop,
                        trackColor: c.accentDeep,
                      )
                    : Icon(
                        Icons.arrow_forward,
                        color: enabledLook ? c.onPop : c.textDisabled,
                      ),
              ),
            ),
          ),
        ],
      ),
    );

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        _travel = math.max(
          1,
          FpSwipeMath.travel(
            trackWidth: width,
            thumbSize: thumbSize,
            inset: FpSwipeToPay.inset,
          ),
        );
        return SizedBox(
          width: width,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track edge (NeoPOP depth) and face.
              Positioned(
                left: depth,
                top: depth,
                right: 0,
                bottom: 0,
                child: ColoredBox(color: FpEdge.surfaceRaised.bottom),
              ),
              Positioned(
                left: 0,
                top: 0,
                right: depth,
                bottom: depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    border: Border.all(color: c.borderStrong),
                  ),
                ),
              ),
              // Fill behind the thumb.
              Positioned(
                left: 0,
                top: 0,
                bottom: depth,
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => Container(
                    width:
                        FpSwipeToPay.inset +
                        thumbSize * 0.5 +
                        _progress.value * _travel,
                    color: c.accentDeep.withValues(
                      alpha: 0.35 + 0.65 * _progress.value,
                    ),
                  ),
                ),
              ),
              // Label.
              Positioned(
                left: thumbSize,
                right: depth,
                top: 0,
                bottom: depth,
                child: FadeTransition(
                  opacity: _progress.drive(
                    Animatable<double>.fromCallback(
                      (t) =>
                          widget.processing ? 1 : FpSwipeMath.labelOpacity(t),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FpSpacing.sm,
                      ),
                      child: Text(
                        widget.processing
                            ? widget.processingLabel.toUpperCase()
                            : widget.label.toUpperCase(),
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              // Thumb.
              AnimatedBuilder(
                animation: _progress,
                child: thumb,
                builder: (context, child) => Positioned(
                  left: FpSwipeToPay.inset + _progress.value * _travel,
                  top: (trackHeight - thumbSize) / 2,
                  child: child!,
                ),
              ),
            ],
          ),
        );
      },
    );

    return Semantics(
      container: true,
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel ?? widget.label,
      hint: _interactive ? 'Double tap to pay' : null,
      value: widget.processing ? 'Processing' : null,
      onTap: _interactive ? _confirm : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: RepaintBoundary(child: body),
        ),
      ),
    );
  }
}
