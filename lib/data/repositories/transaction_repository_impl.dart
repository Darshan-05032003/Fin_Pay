import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart' as models;

/// Implementation of ITransactionRepository
class TransactionRepositoryImpl implements ITransactionRepository {

  TransactionRepositoryImpl(this._localDataSource);
  final LocalDataSource _localDataSource;

  @override
  Future<Result<List<models.Transaction>>> getTransactions({int? limit}) async {
    return _localDataSource.getTransactions(limit: limit);
  }

  @override
  Future<Result<void>> addTransaction(models.Transaction transaction) async {
    return _localDataSource.saveTransaction(transaction);
  }

  @override
  Future<Result<void>> deleteTransaction(String transactionId) async {
    return _localDataSource.deleteTransaction(transactionId);
  }

  @override
  Future<Result<List<models.Transaction>>> getRecentTransactions({int limit = 5}) async {
    return getTransactions(limit: limit);
  }
}

