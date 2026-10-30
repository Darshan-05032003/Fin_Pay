import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Shared layout of the auth screens: dark background, safe area, a back
/// button, a headline + subtitle, then the form in a scroll view so the
/// keyboard and large text never overflow. Content enters with a capped
/// stagger.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.onBack,
    this.footer,
    this.scrollKey,
  });

  final String title;
  final String? subtitle;

  /// Back action; the button is hidden when null.
  final VoidCallback? onBack;

  /// Form content (staggered in).
  final List<Widget> children;

  /// Pinned under the scroll view (e.g. a secondary action).
  final Widget? footer;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: scrollKey,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.sm,
                  FpSpacing.lg,
                  FpSpacing.xl,
                ),
                children: [
                  if (onBack != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        onPressed: onBack,
                        tooltip: 'Back',
                        constraints: const BoxConstraints(
                          minWidth: FpSpacing.minTapTarget,
                          minHeight: FpSpacing.minTapTarget,
                        ),
                        icon: Icon(Icons.arrow_back, color: c.textPrimary),
                      ),
                    )
                  else
                    const SizedBox(height: FpSpacing.lg),
                  const SizedBox(height: FpSpacing.lg),
                  FpStaggeredEntrance(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: fp.text.headline),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: FpSpacing.sm),
                        Text(subtitle!, style: fp.text.bodySmall),
                      ],
                      const SizedBox(height: FpSpacing.xl),
                      ...children,
                    ],
                  ),
                ],
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.sm,
                  FpSpacing.lg,
                  FpSpacing.lg,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
