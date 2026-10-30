import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// Press feedback for non-button tappables (cards, rows, avatars).
///
/// Scales the child down on press (and optionally translates it by [depth],
/// so it "plunks" into its edge), springs back on release, plays a haptic
/// and exposes a button semantics node with a ≥ 48 dp tap target.
///
/// Replaces `CredButtonPress` and `RippleEffect`. With reduced motion the
/// press shows no scale; only the haptic and the callback remain.
class FpPressable extends StatefulWidget {
  const FpPressable({
    required this.child,
    super.key,
    this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.scale = 0.96,
    this.depth = 0,
    this.haptic = HapticType.light,
    this.haptics,
    this.enabled = true,
    this.minTapTarget = FpSpacing.minTapTarget,
    this.selected,
  }) : assert(scale > 0 && scale <= 1, 'scale must be in (0, 1]');

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Accessibility label. When null the child's own semantics are used.
  final String? semanticLabel;

  /// Scale while pressed.
  final double scale;

  /// Pixels to translate down/right while pressed (NeoPOP plunk).
  final double depth;

  /// Haptic played on press down. Null for none.
  final HapticType? haptic;

  /// Injected haptic service; falls back to GetIt.
  final HapticService? haptics;

  final bool enabled;

  /// Minimum width and height of the hit area.
  final double minTapTarget;

  /// Selected state for the semantics node (chips, tabs).
  final bool? selected;

  @override
  State<FpPressable> createState() => _FpPressableState();
}

class _FpPressableState extends State<FpPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FpMotion.fast,
  );

  bool get _interactive =>
      widget.enabled &&
      (widget.onPressed != null || widget.onLongPress != null);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    final reduce = FpMotion.of(context).reduce;
    if (!reduce) {
      _controller.animateTo(1, curve: FpMotion.standardDecelerate);
    }
    playHaptic(widget.haptics, widget.haptic);
  }

  void _release() {
    if (_controller.value == 0) return;
    _controller.animateWith(
      FpSprings.simulation(FpSprings.press, start: _controller.value, end: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = _interactive;
    Widget body = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1 - (1 - widget.scale) * t;
        final offset = Offset(widget.depth * t, widget.depth * t);
        return Transform.translate(
          offset: offset,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
    body = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minTapTarget,
        minHeight: widget.minTapTarget,
      ),
      child: RepaintBoundary(child: body),
    );
    return Semantics(
      container: true,
      // With an explicit label the content stays separate (and readable);
      // without one the content becomes the label.
      explicitChildNodes: widget.semanticLabel != null,
      button: true,
      enabled: interactive,
      label: widget.semanticLabel,
      selected: widget.selected,
      onTap: interactive ? widget.onPressed : null,
      onLongPress: interactive ? widget.onLongPress : null,
      child: GestureDetector(
        // The Semantics above carries the actions; the detector must not
        // add a second, unlabelled tappable node.
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTapDown: interactive ? _down : null,
        onTapUp: interactive ? (_) => _release() : null,
        onTapCancel: interactive ? _release : null,
        onTap: interactive ? widget.onPressed : null,
        onLongPress: interactive ? widget.onLongPress : null,
        child: body,
      ),
    );
  }
}
