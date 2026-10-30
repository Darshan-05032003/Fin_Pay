import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';

/// Records a transaction exactly once and applies it to the balance.
class AddTransactionUseCase {
  AddTransactionUseCase(this._transactionRepository);

  final ITransactionRepository _transactionRepository;

  Future<Result<TransactionOutcome>> call(Transaction transaction) async {
    if (transaction.amount.isZero) {
      return const Failure('Amount must not be zero');
    }
    if (transaction.title.trim().isEmpty) {
      return const Failure('Title must not be empty');
    }
    return await _transactionRepository.addTransaction(transaction);
  }
}
