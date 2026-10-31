import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:flutter/material.dart';

/// The receipt rows on the success screen: payee, masked VPA, reference,
/// time, note and status. Never shows the full VPA.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({required this.receipt, super.key});

  final PaymentReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final note = receipt.draft.note;
    return FpSurface(
      key: const ValueKey('success-receipt'),
      variant: FpSurfaceVariant.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(label: 'To', value: receipt.draft.recipientName),
          _Row(label: 'UPI ID', value: receipt.maskedVpa),
          _Row(label: 'Reference', value: receipt.reference),
          _Row(label: 'Time', value: receipt.paidAtLabel),
          if (note != null && note.isNotEmpty) _Row(label: 'Note', value: note),
          _Row(
            label: 'Status',
            value: receipt.statusLabel,
            valueColor: c.success,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.last = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : FpSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: fp.text.overline.copyWith(color: c.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: fp.text.body.copyWith(color: valueColor ?? c.textPrimary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
