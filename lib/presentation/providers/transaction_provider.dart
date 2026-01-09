import 'package:flutter/foundation.dart';
import '../../models/transaction.dart' as models;
import '../../core/result/result.dart';
import '../../core/di/dependency_injection.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../core/logger.dart';

/// Transaction provider for state management
class TransactionProvider with ChangeNotifier {
  List<models.Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Use cases
  final GetTransactionsUseCase _getTransactionsUseCase;
  final AddTransactionUseCase _addTransactionUseCase;

  TransactionProvider()
      : _getTransactionsUseCase = DependencyInjection.get<GetTransactionsUseCase>(),
        _addTransactionUseCase = DependencyInjection.get<AddTransactionUseCase>();

  // Getters
  List<models.Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<models.Transaction> get recentTransactions => _transactions.take(5).toList();

  /// Load transactions
  Future<void> loadTransactions({int? limit}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _getTransactionsUseCase(limit: limit);

    result
        .onSuccess((transactions) {
          _transactions = transactions;
          Logger.info('Loaded ${transactions.length} transactions');
        })
        .onFailure((message, error) {
          _errorMessage = message;
          Logger.error('Failed to load transactions: $message', error);
        });

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new transaction
  Future<Result<void>> addTransaction(models.Transaction transaction) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _addTransactionUseCase(transaction);

    result
        .onSuccess((_) {
          Logger.info('Transaction added successfully');
          // Reload transactions
          loadTransactions();
        })
        .onFailure((message, error) {
          _errorMessage = message;
          Logger.error('Failed to add transaction: $message', error);
        });

    _isLoading = false;
    notifyListeners();

    return result;
  }
}

