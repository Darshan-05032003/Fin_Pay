import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';

/// Typed payload for the transfer review and success routes.
///
/// [idempotencyKey] is generated when the user leaves the amount screen, so
/// re-submitting the same review (double tap, back-and-forward, process
/// restore) records at most one transaction.
class TransferDraft extends Equatable {
  const TransferDraft({
    required this.recipientName,
    required this.recipientAccount,
    required this.amount,
    required this.idempotencyKey,
    this.note,
  });

  final String recipientName;
  final String recipientAccount;
  final Money amount;
  final String idempotencyKey;
  final String? note;

  TransferDraft copyWith({
    String? recipientName,
    String? recipientAccount,
    Money? amount,
    String? idempotencyKey,
    String? note,
  }) => TransferDraft(
    recipientName: recipientName ?? this.recipientName,
    recipientAccount: recipientAccount ?? this.recipientAccount,
    amount: amount ?? this.amount,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    note: note ?? this.note,
  );

  @override
  List<Object?> get props => [
    recipientName,
    recipientAccount,
    amount,
    idempotencyKey,
    note,
  ];
}
