import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/transaction.dart';

/// Base class for all transaction-related states
abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

/// Initial state when transaction bloc is created
class TransactionInitial extends TransactionState {
  const TransactionInitial();
}

/// State when transactions are being loaded
class TransactionLoading extends TransactionState {
  const TransactionLoading();
}

/// State when transactions are successfully loaded
class TransactionLoaded extends TransactionState {

  const TransactionLoaded(this.transactions);
  final List<Transaction> transactions;

  @override
  List<Object?> get props => [transactions];

  List<Transaction> get recentTransactions => transactions.take(5).toList();

  double get totalIncome {
    return transactions
        .where((t) => t.amount > 0)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return transactions
        .where((t) => t.amount < 0)
        .fold(0, (sum, t) => sum + t.amount.abs());
  }
}

/// State when an error occurs
class TransactionError extends TransactionState {

  const TransactionError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
