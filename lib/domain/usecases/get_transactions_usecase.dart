import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';

/// Lists transactions, newest first.
class GetTransactionsUseCase {
  GetTransactionsUseCase(this._transactionRepository);

  final ITransactionRepository _transactionRepository;

  Future<Result<List<Transaction>>> call({int? limit, int? offset}) =>
      _transactionRepository.getTransactions(limit: limit, offset: offset);
}
