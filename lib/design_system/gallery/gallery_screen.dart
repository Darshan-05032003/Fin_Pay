import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/components/fp_amount_text.dart';
import 'package:fin_pay/design_system/components/fp_bottom_sheet.dart';
import 'package:fin_pay/design_system/components/fp_button.dart';
import 'package:fin_pay/design_system/components/fp_chip.dart';
import 'package:fin_pay/design_system/components/fp_page_indicator.dart';
import 'package:fin_pay/design_system/components/fp_segmented_control.dart';
import 'package:fin_pay/design_system/components/fp_skeleton.dart';
import 'package:fin_pay/design_system/components/fp_state_views.dart';
import 'package:fin_pay/design_system/components/fp_surface.dart';
import 'package:fin_pay/design_system/components/fp_text_field.dart';
import 'package:fin_pay/design_system/components/fp_toast.dart';
import 'package:fin_pay/design_system/components/fp_toggle.dart';
import 'package:fin_pay/design_system/motion/fp_confetti.dart';
import 'package:fin_pay/design_system/motion/fp_pressable.dart';
import 'package:fin_pay/design_system/motion/fp_pulse.dart';
import 'package:fin_pay/design_system/motion/fp_shake.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_contrast.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The debug-only widget gallery. Register in the router with
/// `GoRoute(path: FpGallery.route, builder: (_, _) => FpGalleryScreen())`
/// inside an `if (kDebugMode)` block; the screen also guards itself.
class FpGallery {
  const FpGallery._();

  /// Route path.
  static const String route = '/gallery';
}

/// Shows every design-system component in every state, grouped by section.
/// Used by the golden and accessibility tests.
class FpGalleryScreen extends StatefulWidget {
  const FpGalleryScreen({
    super.key,
    this.isRelease = kReleaseMode,
    this.haptics,
  });

  /// Override for tests; defaults to [kReleaseMode]. In release the screen
  /// renders nothing.
  final bool isRelease;

  final HapticService? haptics;

  @override
  State<FpGalleryScreen> createState() => _FpGalleryScreenState();
}

class _FpGalleryScreenState extends State<FpGalleryScreen> {
  bool _toggleOn = true;
  int _segment = 0;
  int _page = 1;
  bool _chipSelected = true;
  int _paise = 12345678;
  bool _hidden = false;
  late final FpShakeController _shake = FpShakeController();
  late final FpConfettiController _confetti = FpConfettiController();
  late final TextEditingController _text = TextEditingController(text: 'Aarav');

  @override
  void dispose() {
    _shake.dispose();
    _confetti.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRelease) return const SizedBox.shrink();
    final fp = context.fp;
    final h = widget.haptics;
    return Scaffold(
      appBar: AppBar(title: const Text('FinPay design system')),
      body: FpConfetti(
        controller: _confetti,
        child: ListView(
          key: const ValueKey('fp-gallery-list'),
          padding: const EdgeInsets.all(FpSpacing.lg),
          children: [
            const _Section('Colours'),
            _ColourSwatches(),
            const _Section('Typography'),
            for (final entry in fp.text.all.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: FpSpacing.sm),
                child: Text('${entry.key} ₹1,23,456', style: entry.value),
              ),
            const _Section('Buttons'),
            for (final variant in FpButtonVariant.values) ...[
              _Item(
                FpButton(
                  label: variant.name,
                  variant: variant,
                  onPressed: () {},
                  haptics: h,
                ),
              ),
              _Item(
                FpButton(
                  label: '${variant.name} icon',
                  variant: variant,
                  leadingIcon: Icons.bolt,
                  onPressed: () {},
                  haptics: h,
                ),
              ),
              _Item(
                FpButton(
                  label: '${variant.name} loading',
                  variant: variant,
                  isLoading: true,
                  onPressed: () {},
                  haptics: h,
                ),
              ),
              _Item(
                FpButton(
                  label: '${variant.name} disabled',
                  variant: variant,
                  enabled: false,
                  onPressed: () {},
                  haptics: h,
                ),
              ),
            ],
            _Row([
              for (final size in FpButtonSize.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: FpSpacing.sm),
                    child: FpButton(
                      label: size.name,
                      size: size,
                      onPressed: () {},
                      haptics: h,
                    ),
                  ),
                ),
            ]),
            const _Section('Surfaces'),
            for (final variant in FpSurfaceVariant.values)
              Padding(
                padding: const EdgeInsets.only(bottom: FpSpacing.lg),
                child: FpSurface(
                  variant: variant,
                  onTap: variant == FpSurfaceVariant.raised ? () {} : null,
                  semanticLabel: '${variant.name} surface',
                  haptics: h,
                  child: Text(
                    variant == FpSurfaceVariant.raised
                        ? '${variant.name} surface (tappable)'
                        : '${variant.name} surface',
                    style: fp.text.body,
                  ),
                ),
              ),
            const _Section('Text fields'),
            FpTextField(
              label: 'Name',
              hint: 'Your name',
              controller: _text,
              helperText: 'As on your bank account',
              haptics: h,
            ),
            const SizedBox(height: FpSpacing.lg),
            const FpTextField(
              label: 'Password',
              hint: 'Password',
              obscureText: true,
              prefix: Icon(Icons.lock_outline),
            ),
            const SizedBox(height: FpSpacing.lg),
            const FpTextField(
              label: 'UPI ID',
              hint: 'name@bank',
              errorText: 'That UPI ID does not exist',
              suffix: Icon(Icons.alternate_email),
            ),
            const SizedBox(height: FpSpacing.lg),
            const FpTextField(
              label: 'Disabled',
              hint: 'Disabled',
              enabled: false,
            ),
            const _Section('Chips'),
            Wrap(
              spacing: FpSpacing.sm,
              runSpacing: FpSpacing.sm,
              children: [
                FpChip(
                  label: 'Selected',
                  selected: _chipSelected,
                  onSelected: (v) => setState(() => _chipSelected = v),
                  haptics: h,
                ),
                FpChip(label: 'Idle', onSelected: (_) {}, haptics: h),
                FpChip(
                  label: 'Icon',
                  leadingIcon: Icons.flash_on,
                  onSelected: (_) {},
                  haptics: h,
                ),
                const FpChip(label: 'Disabled', enabled: false),
              ],
            ),
            const _Section('Toggle'),
            _Row([
              FpToggle(
                value: _toggleOn,
                onChanged: (v) => setState(() => _toggleOn = v),
                semanticLabel: 'Haptics',
                haptics: h,
              ),
              const SizedBox(width: FpSpacing.lg),
              const FpToggle(value: false, semanticLabel: 'Disabled off'),
              const SizedBox(width: FpSpacing.lg),
              const FpToggle(value: true, semanticLabel: 'Disabled on'),
            ]),
            const _Section('Segmented control'),
            FpSegmentedControl(
              segments: const ['Week', 'Month', 'Year'],
              selectedIndex: _segment,
              onChanged: (i) => setState(() => _segment = i),
              haptics: h,
            ),
            const SizedBox(height: FpSpacing.md),
            FpSegmentedControl(
              segments: const ['Disabled', 'Control'],
              selectedIndex: 1,
            ),
            const _Section('Page indicator'),
            _Row([
              FpPressable(
                semanticLabel: 'Next page',
                onPressed: () => setState(() => _page = (_page + 1) % 4),
                haptics: h,
                child: FpPageIndicator(count: 4, index: _page),
              ),
            ]),
            const _Section('Amount text'),
            FpAmountText(
              paise: _paise,
              hide: _hidden ? FpAmountHide.mask : FpAmountHide.none,
            ),
            const SizedBox(height: FpSpacing.sm),
            const FpAmountText(paise: 99999999999),
            const SizedBox(height: FpSpacing.sm),
            const FpAmountText(paise: -4500, hide: FpAmountHide.blur),
            const SizedBox(height: FpSpacing.sm),
            _Row([
              Expanded(
                child: FpButton(
                  label: 'Roll',
                  variant: FpButtonVariant.secondary,
                  size: FpButtonSize.small,
                  onPressed: () => setState(() => _paise += 98765),
                  haptics: h,
                ),
              ),
              const SizedBox(width: FpSpacing.sm),
              Expanded(
                child: FpButton(
                  label: _hidden ? 'Show' : 'Hide',
                  variant: FpButtonVariant.secondary,
                  size: FpButtonSize.small,
                  onPressed: () => setState(() => _hidden = !_hidden),
                  haptics: h,
                ),
              ),
            ]),
            const _Section('Skeleton'),
            const FpSkeletonGroup(
              child: Column(children: [FpSkeletonRow(), FpSkeletonRow()]),
            ),
            const _Section('Empty and error states'),
            FpEmptyState(
              title: 'No transactions yet',
              message: 'Send money to see it here.',
              actionLabel: 'Send money',
              onAction: () {},
            ),
            FpErrorState(
              title: 'Could not load',
              message: 'Check your connection and try again.',
              onRetry: () {},
            ),
            const _Section('Motion'),
            FpShake(
              controller: _shake,
              child: FpButton(
                label: 'Shake me',
                variant: FpButtonVariant.danger,
                onPressed: _shake.shake,
                haptics: h,
              ),
            ),
            const SizedBox(height: FpSpacing.md),
            FpButton(
              label: 'Confetti',
              variant: FpButtonVariant.secondary,
              onPressed: _confetti.burst,
              haptics: h,
            ),
            const SizedBox(height: FpSpacing.md),
            _Row([
              FpPulse(
                child: Container(
                  width: 12,
                  height: 12,
                  color: fp.colors.accent,
                ),
              ),
              const SizedBox(width: FpSpacing.md),
              Text('Pulse (3 times)', style: fp.text.bodySmall),
            ]),
            const _Section('Overlays'),
            FpButton(
              label: 'Show toast',
              variant: FpButtonVariant.secondary,
              onPressed: () => FpToast.show(
                context,
                message: 'Payment of ₹1,200 sent',
                kind: FpToastKind.success,
              ),
              haptics: h,
            ),
            const SizedBox(height: FpSpacing.md),
            FpButton(
              label: 'Show sheet',
              variant: FpButtonVariant.secondary,
              onPressed: () => FpBottomSheet.show<void>(
                context,
                title: 'Confirm payment',
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FpAmountText(paise: 120000),
                    const SizedBox(height: FpSpacing.lg),
                    FpButton(
                      label: 'Pay',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              haptics: h,
            ),
            const SizedBox(height: FpSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    return Padding(
      padding: const EdgeInsets.only(top: FpSpacing.xl, bottom: FpSpacing.md),
      child: Semantics(
        header: true,
        child: Text(title.toUpperCase(), style: fp.text.overline),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FpSpacing.md),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FpSpacing.md),
      child: Row(children: children),
    );
  }
}

class _ColourSwatches extends StatelessWidget {
  static String _swatchLabel(String name, Color color, Color background) {
    final ratio = FpContrast.ratio(color, background).toStringAsFixed(1);
    return '$name swatch, contrast on background $ratio';
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Wrap(
      spacing: FpSpacing.sm,
      runSpacing: FpSpacing.sm,
      children: [
        for (final entry in c.all.entries)
          Semantics(
            label: _swatchLabel(entry.key, entry.value, c.background),
            child: ExcludeSemantics(
              child: SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: entry.value,
                        border: Border.all(color: c.border),
                      ),
                    ),
                    const SizedBox(height: FpSpacing.xs),
                    Text(
                      entry.key,
                      style: fp.text.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
