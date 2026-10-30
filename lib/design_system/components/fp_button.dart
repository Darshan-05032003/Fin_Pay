import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/motion/fp_submit_guard.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_depth.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';
import 'package:neopop/neopop.dart';

/// Button emphasis.
enum FpButtonVariant { primary, secondary, ghost, danger }

/// Button height. Every size meets the 48 dp target.
enum FpButtonSize {
  small(48, 14),
  medium(56, 14),
  large(64, 16);

  const FpButtonSize(this.height, this.fontSize);

  final double height;
  final double fontSize;
}

/// The NeoPOP 3D button.
///
/// Wraps `package:neopop`'s painter for the bottom/right depth edge; the
/// wrapper owns gestures so it can add the spring-back, a `medium` haptic on
/// press down, `Semantics`, reduce-motion and a double-submit guard
/// ([FpSubmitGuard]): [onPressed] runs at most once until the future it
/// returns completes (or 300 ms pass for synchronous callbacks).
class FpButton extends StatefulWidget {
  const FpButton({
    required this.label,
    super.key,
    this.onPressed,
    this.variant = FpButtonVariant.primary,
    this.size = FpButtonSize.medium,
    this.leadingIcon,
    this.isLoading = false,
    this.enabled = true,
    this.expand = true,
    this.semanticLabel,
    this.haptics,
  });

  final String label;

  /// May return a [Future]; the button stays locked until it completes.
  final FutureOr<void> Function()? onPressed;
  final FpButtonVariant variant;
  final FpButtonSize size;
  final IconData? leadingIcon;

  /// Morphs the label into a spinner and blocks presses.
  final bool isLoading;
  final bool enabled;

  /// Fill the available width (default). False for an intrinsic-width button.
  /// Like any full-width control, an expanding button needs a bounded width
  /// (put it in an `Expanded` inside a `Row`).
  final bool expand;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;
  final HapticService? haptics;

  @override
  State<FpButton> createState() => _FpButtonState();
}

class _FpButtonState extends State<FpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 60),
  );
  final FpSubmitGuard _guard = FpSubmitGuard();

  bool get _canPress =>
      widget.enabled && !widget.isLoading && widget.onPressed != null;

  @override
  void dispose() {
    _guard.dispose();
    _press.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (!FpMotion.of(context).reduce) {
      _press.animateTo(1, curve: FpMotion.standardDecelerate);
    }
    playHaptic(widget.haptics, HapticType.medium);
  }

  void _release() {
    if (_press.value == 0) return;
    _press.animateWith(
      FpSprings.simulation(FpSprings.press, start: _press.value, end: 0),
    );
  }

  void _fire() {
    final action = widget.onPressed;
    if (action == null) return;
    _guard.run(action);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final canPress = _canPress;
    final disabledLook = !widget.enabled;
    final ghost = widget.variant == FpButtonVariant.ghost;

    final (Color faceColor, Color fg, FpEdge edge) = disabledLook
        ? (c.disabledFace, c.textDisabled, FpEdge.disabled)
        : switch (widget.variant) {
            FpButtonVariant.primary => (c.accent, c.onPop, FpEdge.accent),
            FpButtonVariant.secondary => (
              c.surfaceRaised,
              c.textPrimary,
              FpEdge.surfaceRaised,
            ),
            FpButtonVariant.ghost => (
              Colors.transparent,
              c.textPrimary,
              FpEdge.surface,
            ),
            FpButtonVariant.danger => (c.alertFill, c.onAlert, FpEdge.alert),
          };
    final depth = ghost ? 0.0 : fp.metrics.depthButton;
    final faceHeight = widget.size.height - depth;
    final textStyle = fp.text.label.copyWith(
      color: fg,
      fontSize: widget.size.fontSize,
    );

    final content = _ButtonContent(
      label: widget.label,
      icon: widget.leadingIcon,
      isLoading: widget.isLoading,
      style: textStyle,
      color: fg,
    );

    Widget face = SizedBox(
      key: const ValueKey('fp-button-face'),
      height: faceHeight,
      width: widget.expand ? double.infinity : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FpSpacing.xl),
        child: Center(widthFactor: 1, child: content),
      ),
    );
    if (ghost) {
      face = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: disabledLook ? c.border : c.borderStrong),
        ),
        child: face,
      );
    } else {
      face = NeoPopButton(
        color: faceColor,
        disabledColor: faceColor,
        depth: depth,
        rightShadowColor: edge.right,
        bottomShadowColor: edge.bottom,
        border: widget.variant == FpButtonVariant.secondary
            ? Border.all(color: c.borderStrong)
            : null,
        child: face,
      );
    }

    Widget body = AnimatedBuilder(
      animation: _press,
      child: face,
      builder: (context, child) => Transform.translate(
        offset: Offset(depth * _press.value, depth * _press.value),
        child: child,
      ),
    );
    // The painter draws the edge outside the face box; reserve it.
    body = Padding(
      padding: EdgeInsets.only(right: depth, bottom: depth),
      child: body,
    );
    body = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: FpSpacing.minTapTarget,
        minHeight: widget.size.height,
      ),
      child: RepaintBoundary(child: body),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: canPress,
      label: widget.semanticLabel ?? widget.label,
      value: widget.isLoading ? 'Loading' : null,
      onTap: canPress ? _fire : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: canPress ? _down : null,
          onTapUp: canPress ? (_) => _release() : null,
          onTapCancel: canPress ? _release : null,
          onTap: canPress ? _fire : null,
          child: body,
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.style,
    required this.color,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduce = FpMotion.of(context).reduce;
    final child = isLoading
        ? SizedBox(
            key: const ValueKey('fp-button-spinner'),
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
          )
        : Row(
            key: const ValueKey('fp-button-label'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: color),
                const SizedBox(width: FpSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : FpMotion.standard,
      switchInCurve: FpMotion.emphasizedDecelerate,
      switchOutCurve: FpMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: reduce
            ? child
            : ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
                child: child,
              ),
      ),
      child: child,
    );
  }
}
