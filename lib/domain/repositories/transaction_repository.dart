import '../../models/transaction.dart' as models;
import '../../core/result/result.dart';

/// Repository interface for transaction operations
abstract class ITransactionRepository {
  /// Get all transactions
  Future<Result<List<models.Transaction>>> getTransactions({int? limit});
  
  /// Add a new transaction
  Future<Result<void>> addTransaction(models.Transaction transaction);
  
  /// Delete a transaction
  Future<Result<void>> deleteTransaction(String transactionId);
  
  /// Get recent transactions
  Future<Result<List<models.Transaction>>> getRecentTransactions({int limit = 5});
}

