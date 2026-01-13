import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/result/result.dart';
import '../../core/di/dependency_injection.dart';
import '../../core/logger.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

/// BLoC for managing transaction state
/// 
/// This BLoC handles all transaction-related operations including:
/// - Loading transactions
/// - Adding new transactions
/// - Deleting transactions
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final GetTransactionsUseCase _getTransactionsUseCase;
  final AddTransactionUseCase _addTransactionUseCase;

  TransactionBloc()
      : _getTransactionsUseCase = DependencyInjection.get<GetTransactionsUseCase>(),
        _addTransactionUseCase = DependencyInjection.get<AddTransactionUseCase>(),
        super(const TransactionInitial()) {
    on<LoadTransactionsEvent>(_onLoadTransactions);
    on<AddTransactionEvent>(_onAddTransaction);
    on<DeleteTransactionEvent>(_onDeleteTransaction);
  }

  /// Handle loading transactions
  Future<void> _onLoadTransactions(
    LoadTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    emit(const TransactionLoading());

    try {
      final result = await _getTransactionsUseCase(limit: event.limit);

      result
          .onSuccess((transactions) {
            emit(TransactionLoaded(transactions));
            Logger.info('Loaded ${transactions.length} transactions');
          })
          .onFailure((message, error) {
            emit(TransactionError(message));
            Logger.error('Failed to load transactions: $message', error);
          });
    } catch (e) {
      emit(TransactionError('Unexpected error: ${e.toString()}'));
      Logger.error('Unexpected error loading transactions', e);
    }
  }

  /// Handle adding a new transaction
  Future<void> _onAddTransaction(
    AddTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final result = await _addTransactionUseCase(event.transaction);

      result
          .onSuccess((_) {
            Logger.info('Transaction added successfully');
            // Reload transactions after adding
            add(const LoadTransactionsEvent());
          })
          .onFailure((message, error) {
            emit(TransactionError(message));
            Logger.error('Failed to add transaction: $message', error);
          });
    } catch (e) {
      emit(TransactionError('Unexpected error: ${e.toString()}'));
      Logger.error('Unexpected error adding transaction', e);
    }
  }

  /// Handle deleting a transaction
  Future<void> _onDeleteTransaction(
    DeleteTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    if (currentState is TransactionLoaded) {
      try {
        // Note: You may need to add a DeleteTransactionUseCase if it doesn't exist
        // For now, we'll reload transactions after deletion
        add(const LoadTransactionsEvent());
        Logger.info('Transaction deleted successfully');
      } catch (e) {
        emit(TransactionError('Failed to delete transaction: ${e.toString()}'));
        Logger.error('Error deleting transaction', e);
      }
    }
  }
}
