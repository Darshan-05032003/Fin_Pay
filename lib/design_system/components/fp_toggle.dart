import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// NeoPOP switch. The thumb travels on a spring; the track flips to the
/// success colour when on. Plays a `light` haptic on change.
class FpToggle extends StatefulWidget {
  const FpToggle({
    required this.value,
    super.key,
    this.onChanged,
    this.semanticLabel,
    this.haptics,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final HapticService? haptics;

  /// Track size.
  static const Size trackSize = Size(56, 32);

  @override
  State<FpToggle> createState() => _FpToggleState();
}

class _FpToggleState extends State<FpToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _thumb = AnimationController(
    vsync: this,
    value: widget.value ? 1 : 0,
    duration: FpMotion.standard,
  );

  @override
  void didUpdateWidget(FpToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final target = widget.value ? 1.0 : 0.0;
      if (FpMotion.of(context).reduce) {
        _thumb.value = target;
      } else {
        _thumb.animateWith(
          FpSprings.simulation(
            FpSprings.slider,
            start: _thumb.value,
            end: target,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _thumb.dispose();
    super.dispose();
  }

  void _toggle() {
    final change = widget.onChanged;
    if (change == null) return;
    playHaptic(widget.haptics, HapticType.light);
    change(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final enabled = widget.onChanged != null;
    final reduce = FpMotion.of(context).reduce;
    const track = FpToggle.trackSize;
    const thumbSize = 24.0;
    const inset = 4.0;
    final travel = track.width - thumbSize - inset * 2;

    return Semantics(
      container: true,
      toggled: widget.value,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: FpSpacing.minTapTarget,
              minHeight: FpSpacing.minTapTarget,
            ),
            child: Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _thumb,
                  builder: (context, _) {
                    final t = _thumb.value.clamp(0.0, 1.0);
                    final trackColor = !enabled
                        ? c.disabledFace
                        : Color.lerp(c.surfaceHigh, c.success, t)!;
                    final thumbColor = !enabled
                        ? c.textDisabled
                        : Color.lerp(c.popWhite, c.onPop, t)!;
                    return AnimatedContainer(
                      duration: reduce ? Duration.zero : FpMotion.fast,
                      width: track.width,
                      height: track.height,
                      decoration: BoxDecoration(
                        color: trackColor,
                        border: Border.all(
                          color: enabled ? c.borderStrong : c.border,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: inset + travel * _thumb.value,
                            top: inset - 1,
                            child: Container(
                              width: thumbSize,
                              height: thumbSize,
                              color: thumbColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
