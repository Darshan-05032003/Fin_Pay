import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/transaction.dart';

/// State of the transaction list.
sealed class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

final class TransactionInitial extends TransactionState {
  const TransactionInitial();
}

final class TransactionLoading extends TransactionState {
  const TransactionLoading();
}

/// Loaded, but there is nothing to show (optionally for a search).
final class TransactionEmpty extends TransactionState {
  const TransactionEmpty({this.query});

  final String? query;

  @override
  List<Object?> get props => [query];
}

final class TransactionError extends TransactionState {
  const TransactionError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class TransactionContent extends TransactionState {
  const TransactionContent(this.transactions, {this.query});

  final List<Transaction> transactions;

  /// The search query these results are for, or null for the full list.
  final String? query;

  List<Transaction> get recentTransactions => transactions.take(5).toList();

  Money get totalIncome => transactions
      .where((t) => t.amount.isPositive)
      .fold(Money.zero, (sum, t) => sum + t.amount);

  Money get totalExpenses => transactions
      .where((t) => t.amount.isNegative)
      .fold(Money.zero, (sum, t) => sum + t.amount.abs());

  @override
  List<Object?> get props => [transactions, query];
}

/// One-off effects for the UI (toasts, haptics, navigation).
sealed class TransactionEffect extends Equatable {
  const TransactionEffect();

  @override
  List<Object?> get props => [];
}

/// The transaction was written and the balance updated.
final class TransactionAdded extends TransactionEffect {
  const TransactionAdded(this.transaction);

  final Transaction transaction;

  @override
  List<Object?> get props => [transaction];
}

/// The same confirmation was submitted again; nothing changed.
final class TransactionDuplicate extends TransactionEffect {
  const TransactionDuplicate(this.transaction);

  final Transaction transaction;

  @override
  List<Object?> get props => [transaction];
}

/// Refused by a business rule (insufficient balance, no user).
final class TransactionRejected extends TransactionEffect {
  const TransactionRejected(this.transaction, this.reason);

  final Transaction transaction;
  final String reason;

  @override
  List<Object?> get props => [transaction, reason];
}

/// Storage failed; the list is unchanged.
final class TransactionFailed extends TransactionEffect {
  const TransactionFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class TransactionDeleted extends TransactionEffect {
  const TransactionDeleted(this.transactionId);

  final String transactionId;

  @override
  List<Object?> get props => [transactionId];
}
