import 'package:equatable/equatable.dart';
import '../../models/transaction.dart';

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
  final List<Transaction> transactions;

  const TransactionLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions];

  List<Transaction> get recentTransactions => transactions.take(5).toList();

  double get totalIncome {
    return transactions
        .where((t) => t.amount > 0)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return transactions
        .where((t) => t.amount < 0)
        .fold(0.0, (sum, t) => sum + t.amount.abs());
  }
}

/// State when an error occurs
class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
