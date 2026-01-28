import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart' as models;

/// Use case for getting transactions
class GetTransactionsUseCase {

  GetTransactionsUseCase(this._transactionRepository);
  final ITransactionRepository _transactionRepository;

  /// Execute the use case
  Future<Result<List<models.Transaction>>> call({int? limit}) async {
    return _transactionRepository.getTransactions(limit: limit);
  }
}

