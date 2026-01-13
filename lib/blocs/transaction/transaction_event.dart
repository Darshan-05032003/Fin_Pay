import 'package:equatable/equatable.dart';
import '../../models/transaction.dart';

/// Base class for all transaction-related events
abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load transactions
class LoadTransactionsEvent extends TransactionEvent {
  final int? limit;

  const LoadTransactionsEvent({this.limit});

  @override
  List<Object?> get props => [limit];
}

/// Event to add a new transaction
class AddTransactionEvent extends TransactionEvent {
  final Transaction transaction;

  const AddTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

/// Event to delete a transaction
class DeleteTransactionEvent extends TransactionEvent {
  final String transactionId;

  const DeleteTransactionEvent(this.transactionId);

  @override
  List<Object?> get props => [transactionId];
}
