import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/motion/fp_pressable.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// One destination of an [FpBottomNav].
@immutable
class FpBottomNavItem {
  const FpBottomNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;

  /// Icon shown while selected; defaults to [icon].
  final IconData? selectedIcon;

  /// Short label under the icon (also the accessibility label).
  final String label;
}

/// NeoPOP bottom navigation: a flat surface with a hairline top border and
/// a solid accent indicator that slides to the selected tab.
///
/// Every tab is a ≥ 48 dp button with `selected` semantics; selecting a tab
/// plays the `selection` haptic. Tapping the current tab calls
/// [onReselected] (scroll to top) instead of [onSelected]. With reduced
/// motion the indicator jumps.
class FpBottomNav extends StatelessWidget {
  const FpBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    super.key,
    this.onReselected,
    this.haptics,
  }) : assert(items.length >= 2, 'A bottom nav needs at least two tabs');

  final List<FpBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int>? onReselected;
  final HapticService? haptics;

  /// Height of the bar above the bottom safe area.
  static const double height = 64;

  /// Thickness of the selection indicator.
  static const double indicatorHeight = 3;

  /// Horizontal position of the indicator for [index] of [count] tabs in a
  /// bar [width] px wide (pure, unit-tested).
  static double indicatorLeft(int index, int count, double width) =>
      width / count * index;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final tabWidth = width / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      key: const ValueKey('fp-bottom-nav-indicator'),
                      duration: reduce ? Duration.zero : FpMotion.standard,
                      curve: FpMotion.standardCurve,
                      left: indicatorLeft(currentIndex, items.length, width),
                      top: 0,
                      width: tabWidth,
                      height: indicatorHeight,
                      child: ExcludeSemantics(
                        child: Center(
                          child: SizedBox(
                            width: tabWidth * 0.5,
                            height: indicatorHeight,
                            child: ColoredBox(color: c.accent),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _Tab(
                              item: items[i],
                              selected: i == currentIndex,
                              reduce: reduce,
                              haptics: haptics,
                              onPressed: () {
                                if (i == currentIndex) {
                                  onReselected?.call(i);
                                } else {
                                  onSelected(i);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.reduce,
    required this.onPressed,
    this.haptics,
  });

  final FpBottomNavItem item;
  final bool selected;
  final bool reduce;
  final VoidCallback onPressed;
  final HapticService? haptics;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final color = selected ? c.accent : c.textTertiary;
    return FpPressable(
      semanticLabel: item.label,
      selected: selected,
      haptic: HapticType.selection,
      haptics: haptics,
      onPressed: onPressed,
      scale: 0.92,
      child: SizedBox(
        height: FpBottomNav.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: reduce ? Duration.zero : FpMotion.fast,
              switchInCurve: FpMotion.standardDecelerate,
              child: Icon(
                selected ? (item.selectedIcon ?? item.icon) : item.icon,
                key: ValueKey(selected),
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: FpSpacing.xs),
            Text(
              item.label,
              style: fp.text.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
