import '../../core/result/result.dart';
import '../../models/transaction.dart' as models;
import '../repositories/transaction_repository.dart';

/// Use case for getting transactions
class GetTransactionsUseCase {
  final ITransactionRepository _transactionRepository;

  GetTransactionsUseCase(this._transactionRepository);

  /// Execute the use case
  Future<Result<List<models.Transaction>>> call({int? limit}) async {
    return await _transactionRepository.getTransactions(limit: limit);
  }
}

