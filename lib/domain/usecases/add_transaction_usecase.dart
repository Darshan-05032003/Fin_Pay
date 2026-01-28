import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/transaction.dart' as models;

/// Use case for adding a new transaction
class AddTransactionUseCase {

  AddTransactionUseCase(this._transactionRepository, this._userRepository);
  final ITransactionRepository _transactionRepository;
  final IUserRepository _userRepository;

  /// Execute the use case
  Future<Result<void>> call(models.Transaction transaction) async {
    // Add transaction
    final result = await _transactionRepository.addTransaction(transaction);
    
    // Update user balance if transaction is successful
    return result.flatMapAsync((_) async {
      final userResult = await _userRepository.getCurrentUser();
      return userResult.flatMapAsync((user) async {
        if (user == null) {
          return const Failure('User not found');
        }
        final newBalance = user.balance + transaction.amount;
        return _userRepository.updateBalance(newBalance);
      });
    });
  }
}

