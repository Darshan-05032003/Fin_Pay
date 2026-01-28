import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/transaction.dart';

/// Base class for all transaction-related events
abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load transactions
class LoadTransactionsEvent extends TransactionEvent {

  const LoadTransactionsEvent({this.limit});
  final int? limit;

  @override
  List<Object?> get props => [limit];
}

/// Event to add a new transaction
class AddTransactionEvent extends TransactionEvent {

  const AddTransactionEvent(this.transaction);
  final Transaction transaction;

  @override
  List<Object?> get props => [transaction];
}

/// Event to delete a transaction
class DeleteTransactionEvent extends TransactionEvent {

  const DeleteTransactionEvent(this.transactionId);
  final String transactionId;

  @override
  List<Object?> get props => [transactionId];
}
