import 'dart:async';

import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/domain/usecases/get_transactions_usecase.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lists, searches, adds and deletes transactions.
///
/// Events are processed one at a time in order (the default sequential
/// transformer), so a burst of `AddTransactionEvent`s is applied serially
/// and the idempotency key decides what is a duplicate.
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc({
    required GetTransactionsUseCase getTransactionsUseCase,
    required AddTransactionUseCase addTransactionUseCase,
    required ITransactionRepository transactionRepository,
  }) : _getTransactionsUseCase = getTransactionsUseCase,
       _addTransactionUseCase = addTransactionUseCase,
       _repository = transactionRepository,
       super(const TransactionInitial()) {
    on<LoadTransactionsEvent>(_onLoad);
    on<SearchTransactionsEvent>(_onSearch);
    on<AddTransactionEvent>(_onAdd);
    on<DeleteTransactionEvent>(_onDelete);
  }

  final GetTransactionsUseCase _getTransactionsUseCase;
  final AddTransactionUseCase _addTransactionUseCase;
  final ITransactionRepository _repository;
  late final StreamController<TransactionEffect> _effects =
      StreamController.broadcast(
        onListen: () => _hasEffectListeners = true,
        onCancel: () => _hasEffectListeners = false,
      );

  /// One-off effects for the UI.
  Stream<TransactionEffect> get effects => _effects.stream;

  /// True while something listens to [effects] (leak checks in tests).
  bool get hasEffectListeners => _hasEffectListeners;
  bool _hasEffectListeners = false;

  int? _lastLimit;

  Future<void> _onLoad(
    LoadTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    _lastLimit = event.limit;
    emit(const TransactionLoading());
    final result = await _getTransactionsUseCase(limit: event.limit);
    _emitList(result, emit);
  }

  Future<void> _onSearch(
    SearchTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      await _onLoad(const LoadTransactionsEvent(), emit);
      return;
    }
    emit(const TransactionLoading());
    final result = await _repository.searchTransactions(query);
    _emitList(result, emit, query: query);
  }

  void _emitList(
    Result<List<Transaction>> result,
    Emitter<TransactionState> emit, {
    String? query,
  }) {
    switch (result) {
      case Success(data: final transactions) when transactions.isEmpty:
        emit(TransactionEmpty(query: query));
      case Success(data: final transactions):
        emit(TransactionContent(transactions, query: query));
      case Failure(:final message):
        emit(TransactionError(message));
        Logger.error('Failed to load transactions: $message');
    }
  }

  Future<void> _onAdd(
    AddTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final result = await _addTransactionUseCase(event.transaction);
    switch (result) {
      case Success(data: TransactionOutcome.recorded):
        _emitEffect(TransactionAdded(event.transaction));
        await _onLoad(LoadTransactionsEvent(limit: _lastLimit), emit);
      case Success(data: TransactionOutcome.duplicate):
        _emitEffect(TransactionDuplicate(event.transaction));
      case Success(data: TransactionOutcome.insufficientBalance):
        _emitEffect(
          TransactionRejected(event.transaction, 'Insufficient balance'),
        );
      case Success(data: TransactionOutcome.noUser):
        _emitEffect(TransactionRejected(event.transaction, 'No account'));
      case Failure(:final message):
        _emitEffect(TransactionFailed(message));
        Logger.error('Failed to add transaction: $message');
    }
  }

  Future<void> _onDelete(
    DeleteTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final result = await _repository.deleteTransaction(event.transactionId);
    switch (result) {
      case Success():
        _emitEffect(TransactionDeleted(event.transactionId));
        final current = state;
        if (current is TransactionContent) {
          final remaining = current.transactions
              .where((t) => t.id != event.transactionId)
              .toList();
          emit(
            remaining.isEmpty
                ? TransactionEmpty(query: current.query)
                : TransactionContent(remaining, query: current.query),
          );
        }
      case Failure(:final message):
        _emitEffect(TransactionFailed(message));
        Logger.error('Failed to delete transaction: $message');
    }
  }

  /// A handler that was awaiting storage when the bloc closed must not
  /// throw into a closed controller.
  void _emitEffect(TransactionEffect effect) {
    if (!_effects.isClosed) _effects.add(effect);
  }

  @override
  Future<void> close() async {
    await _effects.close();
    await super.close();
  }
}
