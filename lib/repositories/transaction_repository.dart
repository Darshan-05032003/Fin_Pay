import '../models/transaction.dart' as models;
import '../services/database_service.dart';
import '../core/logger.dart';

/// Repository pattern for transaction data management
class TransactionRepository {
  final DatabaseService _db = DatabaseService();

  Future<List<models.Transaction>> getTransactions({int? limit}) async {
    try {
      return await _db.getTransactions(limit: limit);
    } catch (e) {
      Logger.error('Failed to get transactions', e);
      return [];
    }
  }

  Future<void> addTransaction(models.Transaction transaction) async {
    try {
      await _db.insertTransaction(transaction);
      Logger.info('Transaction added successfully');
    } catch (e) {
      Logger.error('Failed to add transaction', e);
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _db.deleteTransaction(transactionId);
      Logger.info('Transaction deleted successfully');
    } catch (e) {
      Logger.error('Failed to delete transaction', e);
      rethrow;
    }
  }
}

