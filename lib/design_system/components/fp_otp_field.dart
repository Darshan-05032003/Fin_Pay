import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/motion/fp_shake.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One-time-code entry: [length] NeoPOP cells driven by a single hidden
/// text field, so typing, paste and OS autofill (`oneTimeCode`) all land in
/// the same place. The active cell follows the typed digits (auto-advance),
/// backspace moves back, and non-digits are stripped by the input formatter.
///
/// The widget is controlled: it shows [value] and reports every change
/// through [onChanged]. A new `error: true` shakes the row, flashes the
/// cells red and plays the `error` haptic; each typed digit plays
/// `selection`.
class FpOtpField extends StatefulWidget {
  const FpOtpField({
    required this.value,
    required this.onChanged,
    super.key,
    this.length = 6,
    this.error = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.onCompleted,
    this.semanticLabel = 'Verification code',
    this.haptics,
    this.cellSize = FpSpacing.minTapTarget,
  }) : assert(length > 0 && length <= 12, 'length must be 1..12');

  /// Digits shown (≤ [length]).
  final String value;
  final ValueChanged<String> onChanged;
  final int length;
  final bool error;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Called once each time the last cell is filled.
  final ValueChanged<String>? onCompleted;
  final String semanticLabel;
  final HapticService? haptics;

  /// Width and height of one cell (≥ 48 dp).
  final double cellSize;

  @override
  State<FpOtpField> createState() => _FpOtpFieldState();
}

class _FpOtpFieldState extends State<FpOtpField>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  late final FpShakeController _shake = FpShakeController();
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: FpMotion.emphasized,
  );
  FocusNode? _ownedFocus;
  bool _focused = false;

  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(FpOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
    if (widget.error && !oldWidget.error) {
      _shake.shake();
      if (!FpMotion.of(context).reduce) _flash.forward(from: 0);
      playHaptic(widget.haptics, HapticType.error);
    }
  }

  void _onFocus() {
    final focused = _focus.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  void _onText(String text) {
    if (!widget.enabled) return;
    // The formatter already stripped non-digits and capped the length.
    if (text == widget.value) return;
    if (text.length > widget.value.length) {
      playHaptic(widget.haptics, HapticType.selection);
    }
    widget.onChanged(text);
    if (text.length == widget.length) widget.onCompleted?.call(text);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownedFocus?.dispose();
    _controller.dispose();
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final value = widget.value;
    final active = value.length < widget.length ? value.length : -1;

    final cells = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FpSpacing.xs),
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                final flash = widget.error
                    ? (1 - _flash.value).clamp(0.0, 1.0)
                    : 0.0;
                final isActive = _focused && widget.enabled && i == active;
                final border = widget.error
                    ? c.alert
                    : isActive
                    ? c.accent
                    : c.border;
                return AnimatedContainer(
                  key: ValueKey('fp-otp-cell-$i'),
                  duration: reduce ? Duration.zero : FpMotion.fast,
                  curve: FpMotion.standardCurve,
                  width: widget.cellSize,
                  height: widget.cellSize + FpSpacing.sm,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      widget.enabled ? c.surfaceRaised : c.surface,
                      c.alert,
                      0.35 * flash,
                    ),
                    border: Border.all(
                      color: border,
                      width: isActive || widget.error ? 2 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.28),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: Text(
                    i < value.length ? value[i] : '',
                    style: fp.text.title.copyWith(
                      color: widget.enabled ? c.textPrimary : c.textDisabled,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );

    // The real input: invisible, but focusable and fed by the keyboard,
    // paste and autofill. It sits behind the cells so taps on the row
    // focus it.
    final input = Opacity(
      opacity: 0,
      child: ExcludeSemantics(
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          enableSuggestions: false,
          autocorrect: false,
          showCursor: false,
          enableInteractiveSelection: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.length),
          ],
          onChanged: _onText,
          style: const TextStyle(fontSize: 1),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      textField: true,
      enabled: widget.enabled,
      focused: _focused,
      label: widget.semanticLabel,
      value: '${value.length} of ${widget.length} digits entered',
      onTap: widget.enabled ? _focus.requestFocus : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _focus.requestFocus : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: input),
              IgnorePointer(
                child: FpShake(controller: _shake, child: cells),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
