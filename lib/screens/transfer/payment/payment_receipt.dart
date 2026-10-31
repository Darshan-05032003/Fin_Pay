import 'package:equatable/equatable.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:intl/intl.dart';

/// What the success screen shows and shares. Built by `PaymentCubit` once
/// the ledger and the bank agree; carried to `/transfer-success` as the
/// typed route extra.
///
/// `toString` prints only the reference, so the receipt can cross
/// `BlocObserver` and route logs without leaking the amount or the VPA.
class PaymentReceipt extends Equatable {
  const PaymentReceipt({
    required this.draft,
    required this.reference,
    required this.paidAt,
    this.alreadyPaid = false,
  });

  final TransferDraft draft;

  /// Bank-side reference (stable per idempotency key).
  final String reference;

  /// When the payment was confirmed (UTC).
  final DateTime paidAt;

  /// True when the ledger already held this key: the retry of a payment
  /// that had gone through. Nothing was debited twice.
  final bool alreadyPaid;

  /// The payee's VPA with its local part masked.
  String get maskedVpa => Contact.maskVpa(draft.recipientAccount);

  /// Human status line.
  String get statusLabel => alreadyPaid ? 'Already paid' : 'Paid';

  /// `31 Oct 2026, 12:00` in the device's local time.
  String get paidAtLabel =>
      DateFormat('d MMM yyyy, HH:mm').format(paidAt.toLocal());

  /// Plain-text receipt for the clipboard. Carries the masked VPA only.
  String shareText() {
    final lines = <String>[
      'FinPay receipt',
      '${draft.amount.format()} to ${draft.recipientName} ($maskedVpa)',
      'Reference $reference',
      paidAtLabel,
      if (draft.note case final note? when note.isNotEmpty) 'Note: $note',
      'Status: $statusLabel',
    ];
    return lines.join('\n');
  }

  @override
  List<Object?> get props => [draft, reference, paidAt, alreadyPaid];

  @override
  String toString() => 'PaymentReceipt($reference)';
}
