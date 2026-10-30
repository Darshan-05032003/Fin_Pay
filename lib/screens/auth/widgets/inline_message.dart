import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Tone of an [InlineMessage].
enum InlineMessageKind { error, info, success }

/// A flat message panel under a form (typed auth failures, lockouts,
/// "code sent"). Announced as a live region; animates in and out.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    required this.message,
    super.key,
    this.kind = InlineMessageKind.error,
  });

  /// Null hides the panel (animated).
  final String? message;
  final InlineMessageKind kind;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final text = message;
    final (Color color, IconData icon) = switch (kind) {
      InlineMessageKind.error => (c.alert, Icons.error_outline),
      InlineMessageKind.info => (c.info, Icons.info_outline),
      InlineMessageKind.success => (c.success, Icons.check_circle_outline),
    };
    final body = text == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(bottom: FpSpacing.lg),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(left: BorderSide(color: color, width: 3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(FpSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: FpSpacing.sm),
                      Expanded(
                        child: Text(
                          text,
                          key: ValueKey(text),
                          style: fp.text.bodySmall.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
    // AnimatedSize with a zero duration mutates during layout; with reduced
    // motion the panel simply appears.
    if (reduce) return body;
    return AnimatedSize(
      duration: FpMotion.standard,
      curve: FpMotion.standardCurve,
      alignment: Alignment.topCenter,
      child: body,
    );
  }
}
