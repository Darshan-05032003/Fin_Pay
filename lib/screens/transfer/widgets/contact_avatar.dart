import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:flutter/material.dart';

/// One payee in the horizontal picker: an initials disc, the first name
/// and a "recent" marker. Selected = accent face.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    required this.contact,
    required this.selected,
    required this.onSelected,
    super.key,
    this.recent = false,
    this.haptics,
  });

  final Contact contact;
  final bool selected;
  final bool recent;
  final VoidCallback onSelected;
  final HapticService? haptics;

  /// Disc diameter.
  static const double size = 56;

  /// Column width (keeps names from colliding).
  static const double width = 76;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final depth = fp.metrics.depthChip;
    return FpPressable(
      semanticLabel:
          '${contact.name}, ${contact.vpa}${recent ? ', recently paid' : ''}',
      selected: selected,
      onPressed: onSelected,
      haptic: HapticType.selection,
      haptics: haptics,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size + depth,
              height: size + depth,
              child: Stack(
                children: [
                  Positioned(
                    left: depth,
                    top: depth,
                    child: Container(
                      width: size,
                      height: size,
                      color: selected ? c.accentDeep : c.border,
                    ),
                  ),
                  AnimatedContainer(
                    duration: fp.motion.standard,
                    curve: fp.motion.change,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : c.surfaceRaised,
                      border: Border.all(
                        color: selected ? c.accent : c.borderStrong,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      contact.initials,
                      style: fp.text.label.copyWith(
                        color: selected ? c.onPop : c.textPrimary,
                      ),
                    ),
                  ),
                  if (recent)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(width: 10, height: 10, color: c.success),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FpSpacing.sm),
            Text(
              contact.name.split(' ').first,
              style: fp.text.caption.copyWith(
                color: selected ? c.textPrimary : c.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
