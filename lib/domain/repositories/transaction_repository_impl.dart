import '../../models/transaction.dart' as models;
import '../../core/result/result.dart';
import '../../data/datasources/local_datasource.dart';
import 'transaction_repository.dart';

/// Implementation of ITransactionRepository
class TransactionRepositoryImpl implements ITransactionRepository {
  final LocalDataSource _localDataSource;

  TransactionRepositoryImpl(this._localDataSource);

  @override
  Future<Result<List<models.Transaction>>> getTransactions({int? limit}) async {
    return await _localDataSource.getTransactions(limit: limit);
  }

  @override
  Future<Result<void>> addTransaction(models.Transaction transaction) async {
    return await _localDataSource.saveTransaction(transaction);
  }

  @override
  Future<Result<void>> deleteTransaction(String transactionId) async {
    return await _localDataSource.deleteTransaction(transactionId);
  }

  @override
  Future<Result<List<models.Transaction>>> getRecentTransactions({int limit = 5}) async {
    return await getTransactions(limit: limit);
  }
}

