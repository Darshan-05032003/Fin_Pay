import 'package:fin_pay/design_system/components/fp_button.dart';
import 'package:fin_pay/design_system/motion/fp_staggered_entrance.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// Shared layout for empty and error views: glyph, title, message, action.
class _FpStateView extends StatelessWidget {
  const _FpStateView({
    required this.icon,
    required this.title,
    required this.iconColor,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.all(FpSpacing.xl),
        child: FpStaggeredEntrance(
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  border: Border.all(color: c.border),
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
            ),
            const SizedBox(height: FpSpacing.lg),
            Text(title, style: fp.text.title, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: FpSpacing.sm),
              Text(
                message!,
                style: fp.text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FpSpacing.xl),
              Center(
                child: FpButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: FpButtonVariant.secondary,
                  size: FpButtonSize.small,
                  expand: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Nothing here yet" view with an optional call to action.
class FpEmptyState extends StatelessWidget {
  const FpEmptyState({
    required this.title,
    super.key,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _FpStateView(
    icon: icon,
    iconColor: context.fp.colors.textSecondary,
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

/// "Something went wrong" view with a retry action.
class FpErrorState extends StatelessWidget {
  const FpErrorState({
    required this.title,
    super.key,
    this.message,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Retry',
    this.onRetry,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _FpStateView(
    icon: icon,
    iconColor: context.fp.colors.alert,
    title: title,
    message: message,
    actionLabel: onRetry == null ? null : retryLabel,
    onAction: onRetry,
  );
}
