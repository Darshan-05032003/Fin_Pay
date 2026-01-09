import '../../core/result/result.dart';
import '../../models/transaction.dart' as models;
import '../repositories/transaction_repository.dart';
import '../repositories/user_repository.dart';

/// Use case for adding a new transaction
class AddTransactionUseCase {
  final ITransactionRepository _transactionRepository;
  final IUserRepository _userRepository;

  AddTransactionUseCase(this._transactionRepository, this._userRepository);

  /// Execute the use case
  Future<Result<void>> call(models.Transaction transaction) async {
    // Add transaction
    final result = await _transactionRepository.addTransaction(transaction);
    
    // Update user balance if transaction is successful
    return await result.flatMapAsync((_) async {
      final userResult = await _userRepository.getCurrentUser();
      return await userResult.flatMapAsync((user) async {
        if (user == null) {
          return const Failure('User not found');
        }
        final newBalance = user.balance + transaction.amount;
        return await _userRepository.updateBalance(newBalance);
      });
    });
  }
}

