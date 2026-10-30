import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One quick action tile.
@immutable
class QuickAction {
  const QuickAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// A row of NeoPOP tiles that stagger in and plunk on press.
class QuickActions extends StatelessWidget {
  const QuickActions({required this.actions, super.key, this.haptics});

  final List<QuickAction> actions;
  final HapticService? haptics;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return FpStaggeredEntrance(
      builder: (context, children) => Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: FpSpacing.sm),
            Expanded(child: children[i]),
          ],
        ],
      ),
      children: [
        for (final action in actions)
          FpSurface(
            key: action.key,
            variant: FpSurfaceVariant.raised,
            padding: const EdgeInsets.symmetric(
              vertical: FpSpacing.md,
              horizontal: FpSpacing.xs,
            ),
            semanticLabel: action.label,
            onTap: action.onPressed,
            haptics: haptics,
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, color: c.accent),
                  const SizedBox(height: FpSpacing.sm),
                  Text(
                    action.label,
                    style: fp.text.caption.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
