import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// Segmented control with a sliding pop-white indicator (period switchers,
/// tabs inside a screen). Plays a `selection` haptic on change.
class FpSegmentedControl extends StatelessWidget {
  const FpSegmentedControl({
    required this.segments,
    required this.selectedIndex,
    super.key,
    this.onChanged,
    this.haptics,
  }) : assert(segments.length >= 2, 'need at least two segments'),
       assert(
         selectedIndex >= 0 && selectedIndex < segments.length,
         'selectedIndex out of range',
       );

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final HapticService? haptics;

  /// Control height (meets the 48 dp target).
  static const double height = FpSpacing.minTapTarget;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final enabled = onChanged != null;
    final n = segments.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border.all(color: c.borderStrong),
      ),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / n;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: reduce ? Duration.zero : FpMotion.standard,
                  curve: FpMotion.standardCurve,
                  left: segmentWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ColoredBox(color: c.popWhite),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == selectedIndex,
                          enabled: enabled,
                          label: segments[i],
                          onTap: enabled ? () => _select(i) : null,
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: enabled ? () => _select(i) : null,
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: reduce
                                      ? Duration.zero
                                      : FpMotion.standard,
                                  style: fp.text.label.copyWith(
                                    fontSize: 13,
                                    letterSpacing: 0.4,
                                    color: !enabled
                                        ? c.textDisabled
                                        : i == selectedIndex
                                        ? c.onPop
                                        : c.textSecondary,
                                  ),
                                  child: Text(
                                    segments[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _select(int i) {
    if (i == selectedIndex) return;
    playHaptic(haptics, HapticType.selection);
    onChanged?.call(i);
  }
}
