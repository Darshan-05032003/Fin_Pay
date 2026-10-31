import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';

/// [ITransactionRepository] over the local data source.
class TransactionRepositoryImpl implements ITransactionRepository {
  TransactionRepositoryImpl(this._localDataSource);

  final LocalDataSource _localDataSource;

  @override
  Future<Result<List<Transaction>>> getTransactions({
    int? limit,
    int? offset,
    TransactionType? type,
  }) => type == null
      ? _localDataSource.getTransactions(limit: limit, offset: offset)
      : _localDataSource.getTransactions(
          limit: limit,
          offset: offset,
          type: type,
        );

  @override
  Future<Result<List<Transaction>>> searchTransactions(
    String query, {
    TransactionType? type,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getTransactions(type: type);
    return type == null
        ? _localDataSource.searchTransactions(trimmed)
        : _localDataSource.searchTransactions(trimmed, type: type);
  }

  @override
  Future<Result<List<Transaction>>> getTransactionsBetween(
    DateTime from,
    DateTime to,
  ) => _localDataSource.getTransactionsBetween(from, to);

  @override
  Future<Result<List<Transaction>>> getRecentTransactions({int limit = 5}) =>
      getTransactions(limit: limit);

  @override
  Future<Result<TransactionOutcome>> addTransaction(Transaction transaction) =>
      _localDataSource.saveTransaction(transaction);

  @override
  Future<Result<void>> addTransactions(List<Transaction> transactions) =>
      _localDataSource.saveTransactions(transactions);

  @override
  Future<Result<void>> deleteTransaction(String transactionId) =>
      _localDataSource.deleteTransaction(transactionId);
}
