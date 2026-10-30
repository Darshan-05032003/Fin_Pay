import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/utils/validators.dart';
import 'package:flutter/material.dart';

/// Four segments that fill with the password score, plus its label.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.strength, super.key});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final color = switch (strength) {
      PasswordStrength.none || PasswordStrength.weak => c.alert,
      PasswordStrength.fair => c.accent,
      PasswordStrength.good || PasswordStrength.strong => c.success,
    };
    return Semantics(
      container: true,
      label: 'Password strength: ${strength.label}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: reduce ? Duration.zero : FpMotion.standard,
                  curve: FpMotion.standardCurve,
                  height: 4,
                  color: i < strength.score ? color : c.border,
                ),
              ),
              if (i < 3) const SizedBox(width: FpSpacing.xs),
            ],
            const SizedBox(width: FpSpacing.md),
            Text(
              strength.label,
              style: fp.text.caption.copyWith(
                color: strength == PasswordStrength.none
                    ? c.textTertiary
                    : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
