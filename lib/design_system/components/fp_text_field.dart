import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/motion/fp_shake.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// NeoPOP text field: flat raised face, accent focus glow, error state with a
/// shake and an `error` haptic, optional obscure toggle.
///
/// Field contents are never logged or copied by this widget; they only reach
/// [controller], [onChanged] and [onSubmitted].
class FpTextField extends StatefulWidget {
  const FpTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.obscureToggle = true,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.maxLength,
    this.maxLines = 1,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.semanticLabel,
    this.haptics,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Small label above the field.
  final String? label;
  final String? hint;
  final String? helperText;

  /// When non-null the field shows the error, shakes and plays a haptic
  /// (each time the text changes to a new non-null value).
  final String? errorText;
  final bool obscureText;

  /// Show the eye toggle when [obscureText] is true.
  final bool obscureToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final int? maxLength;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final String? semanticLabel;
  final HapticService? haptics;
  final bool autofocus;

  @override
  State<FpTextField> createState() => _FpTextFieldState();
}

class _FpTextFieldState extends State<FpTextField> {
  late final FpShakeController _shake = FpShakeController();
  FocusNode? _ownedFocus;
  late bool _obscured = widget.obscureText;
  bool _focused = false;

  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(FpTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
    final err = widget.errorText;
    if (err != null && err != oldWidget.errorText) {
      _shake.shake();
      playHaptic(widget.haptics, HapticType.error);
    }
  }

  void _onFocus() {
    final focused = _focus.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownedFocus?.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final error = widget.errorText;
    final hasError = error != null;
    final borderColor = !widget.enabled
        ? c.border
        : hasError
        ? c.alert
        : _focused
        ? c.accent
        : c.border;
    final glowColor = hasError ? c.alert : c.accent;

    final suffix = widget.obscureText && widget.obscureToggle
        ? _ObscureToggle(
            obscured: _obscured,
            onToggle: () => setState(() => _obscured = !_obscured),
          )
        : widget.suffix;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      // Never let the keyboard learn or suggest secrets.
      enableSuggestions: !widget.obscureText,
      autocorrect: !widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: fp.text.body.copyWith(
        color: widget.enabled ? c.textPrimary : c.textDisabled,
      ),
      cursorColor: c.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: fp.text.body.copyWith(color: c.textTertiary),
        border: InputBorder.none,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FpSpacing.lg,
          vertical: FpSpacing.md,
        ),
        prefixIcon: widget.prefix,
        prefixIconColor: c.textSecondary,
        suffixIcon: suffix,
        suffixIconColor: c.textSecondary,
      ),
    );

    final box = AnimatedContainer(
      duration: reduce ? Duration.zero : FpMotion.fast,
      curve: FpMotion.standardCurve,
      constraints: const BoxConstraints(minHeight: FpSpacing.minTapTarget + 8),
      decoration: BoxDecoration(
        color: widget.enabled ? c.surfaceRaised : c.surface,
        border: Border.all(color: borderColor, width: _focused ? 2 : 1),
        boxShadow: _focused && widget.enabled
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Align(alignment: Alignment.centerLeft, child: field),
    );

    final label = widget.label;
    final helper = hasError ? error : widget.helperText;
    return Semantics(
      container: true,
      textField: true,
      label: widget.semanticLabel ?? label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(label.toUpperCase(), style: fp.text.overline),
            const SizedBox(height: FpSpacing.sm),
          ],
          FpShake(controller: _shake, child: box),
          if (helper != null) ...[
            const SizedBox(height: FpSpacing.sm),
            AnimatedSwitcher(
              duration: reduce ? Duration.zero : FpMotion.fast,
              child: Text(
                helper,
                key: ValueKey(helper),
                style: fp.text.caption.copyWith(
                  color: hasError ? c.alert : c.textTertiary,
                ),
                semanticsLabel: hasError ? 'Error: $helper' : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObscureToggle extends StatelessWidget {
  const _ObscureToggle({required this.obscured, required this.onToggle});

  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      tooltip: obscured ? 'Show password' : 'Hide password',
      constraints: const BoxConstraints(
        minWidth: FpSpacing.minTapTarget,
        minHeight: FpSpacing.minTapTarget,
      ),
      icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off),
    );
  }
}
