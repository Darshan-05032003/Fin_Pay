import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// Morphing page dots: the active dot stretches into a bar.
class FpPageIndicator extends StatelessWidget {
  const FpPageIndicator({
    required this.count,
    required this.index,
    super.key,
    this.dotSize = 8,
    this.activeWidth = 24,
  }) : assert(count > 0, 'count must be > 0'),
       assert(index >= 0 && index < count, 'index out of range');

  final int count;
  final int index;
  final double dotSize;
  final double activeWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    final reduce = FpMotion.of(context).reduce;
    return Semantics(
      container: true,
      label: 'Page ${index + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: FpSpacing.xs),
                child: AnimatedContainer(
                  duration: reduce ? Duration.zero : FpMotion.standard,
                  curve: FpMotion.emphasizedDecelerate,
                  width: i == index ? activeWidth : dotSize,
                  height: dotSize,
                  color: i == index ? c.accent : c.borderStrong,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
