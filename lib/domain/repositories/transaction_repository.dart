import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart'
    show TransactionOutcome;
import 'package:fin_pay/models/transaction.dart';

export 'package:fin_pay/data/datasources/local_datasource.dart'
    show TransactionOutcome;

/// Repository interface for transactions.
abstract interface class ITransactionRepository {
  /// Newest first, optionally paged.
  Future<Result<List<Transaction>>> getTransactions({int? limit, int? offset});

  /// Case-insensitive search over title and recipient.
  Future<Result<List<Transaction>>> searchTransactions(String query);

  /// The newest [limit] transactions.
  Future<Result<List<Transaction>>> getRecentTransactions({int limit = 5});

  /// Records [transaction] exactly once per `idempotencyKey` and applies it
  /// to the balance atomically.
  Future<Result<TransactionOutcome>> addTransaction(Transaction transaction);

  /// Bulk import that does not touch the balance.
  Future<Result<void>> addTransactions(List<Transaction> transactions);

  /// Deletes a transaction (the balance is not reverted).
  Future<Result<void>> deleteTransaction(String transactionId);
}
