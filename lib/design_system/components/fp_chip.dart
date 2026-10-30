import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/motion/fp_pressable.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// A selectable NeoPOP chip (filters, quick amounts).
///
/// Selected chips flip to a pop-white face with dark text. Plays a
/// `selection` haptic on tap.
class FpChip extends StatelessWidget {
  const FpChip({
    required this.label,
    super.key,
    this.selected = false,
    this.onSelected,
    this.leadingIcon,
    this.enabled = true,
    this.semanticLabel,
    this.haptics,
  });

  final String label;
  final bool selected;

  /// Called with the new selected value.
  final ValueChanged<bool>? onSelected;
  final IconData? leadingIcon;
  final bool enabled;
  final String? semanticLabel;
  final HapticService? haptics;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final interactive = enabled && onSelected != null;
    final face = !enabled
        ? c.disabledFace
        : selected
        ? c.popWhite
        : c.surfaceRaised;
    final fg = !enabled
        ? c.textDisabled
        : selected
        ? c.onPop
        : c.textPrimary;

    final chip = AnimatedContainer(
      duration: reduce ? Duration.zero : FpMotion.standard,
      curve: FpMotion.standardCurve,
      padding: const EdgeInsets.symmetric(
        horizontal: FpSpacing.lg,
        vertical: FpSpacing.sm,
      ),
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(
        color: face,
        border: Border.all(color: selected ? c.popWhite : c.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 16, color: fg),
            const SizedBox(width: FpSpacing.xs),
          ],
          Text(
            label,
            style: fp.text.label.copyWith(
              color: fg,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );

    return FpPressable(
      enabled: interactive,
      semanticLabel: semanticLabel ?? label,
      selected: selected,
      onPressed: interactive
          ? () {
              playHaptic(haptics, HapticType.selection);
              onSelected!(!selected);
            }
          : null,
      haptic: null,
      scale: 0.94,
      child: ExcludeSemantics(child: Center(widthFactor: 1, child: chip)),
    );
  }
}
