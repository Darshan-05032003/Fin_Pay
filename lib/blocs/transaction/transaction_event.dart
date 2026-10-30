import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/transaction.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

final class LoadTransactionsEvent extends TransactionEvent {
  const LoadTransactionsEvent({this.limit});

  final int? limit;

  @override
  List<Object?> get props => [limit];
}

final class SearchTransactionsEvent extends TransactionEvent {
  const SearchTransactionsEvent(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class AddTransactionEvent extends TransactionEvent {
  const AddTransactionEvent(this.transaction);

  final Transaction transaction;

  @override
  List<Object?> get props => [transaction];
}

final class DeleteTransactionEvent extends TransactionEvent {
  const DeleteTransactionEvent(this.transactionId);

  final String transactionId;

  @override
  List<Object?> get props => [transactionId];
}
