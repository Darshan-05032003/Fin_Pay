import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The big amount keypad: digits 0–9, a decimal point and backspace
/// (long-press clears). Every key is a 48 dp+ NeoPOP pressable with a
/// selection haptic; the rolling display lives in the screen.
class TransferKeypad extends StatelessWidget {
  const TransferKeypad({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    super.key,
    this.onClear,
    this.enabled = true,
    this.haptics,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;

  /// Long-press on backspace.
  final VoidCallback? onClear;
  final bool enabled;
  final HapticService? haptics;

  /// Height of one key row.
  static const double keyHeight = 56;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final digitStyle = fp.text.headline.copyWith(
      color: enabled ? c.textPrimary : c.textDisabled,
    );

    Widget key({
      required Widget child,
      required String label,
      required VoidCallback onPressed,
      required Key keyId,
      VoidCallback? onLongPress,
    }) => Expanded(
      child: FpPressable(
        key: keyId,
        semanticLabel: label,
        enabled: enabled,
        onPressed: onPressed,
        onLongPress: onLongPress,
        scale: 0.92,
        haptic: HapticType.selection,
        haptics: haptics,
        child: SizedBox(
          height: keyHeight,
          child: Center(child: child),
        ),
      ),
    );

    Widget digit(int d) => key(
      keyId: ValueKey('key-$d'),
      label: 'Digit $d',
      onPressed: () => onDigit(d),
      child: Text('$d', style: digitStyle),
    );

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            Row(children: [for (final d in row) digit(d)]),
          Row(
            children: [
              key(
                keyId: const ValueKey('key-dot'),
                label: 'Decimal point',
                onPressed: onDecimal,
                child: Text('.', style: digitStyle),
              ),
              digit(0),
              key(
                keyId: const ValueKey('key-backspace'),
                label: 'Backspace, long press to clear',
                onPressed: onBackspace,
                onLongPress: onClear,
                child: Icon(
                  Icons.backspace_outlined,
                  color: enabled ? c.textPrimary : c.textDisabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
