import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The filter chips above the list. Each maps to one ledger type (or none).
enum TransactionsFilter {
  all('All', null),
  sent('Sent', TransactionType.sendMoney),
  received('Received', TransactionType.receiveMoney),
  payments('Payments', TransactionType.payment),
  card('Card', TransactionType.topUp);

  const TransactionsFilter(this.label, this.type);

  final String label;

  /// The ledger type this chip shows, or null for everything.
  final TransactionType? type;
}

enum TransactionsStatus { loading, content, empty, error }

/// State of the transactions screen. `toString` carries counts only (no
/// amounts or counterparties reach logs).
class TransactionsState extends Equatable {
  const TransactionsState({
    this.status = TransactionsStatus.loading,
    this.items = const [],
    this.filter = TransactionsFilter.all,
    this.query = '',
    this.hasMore = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.errorMessage,
  });

  final TransactionsStatus status;

  /// Newest first, as loaded so far.
  final List<Transaction> items;
  final TransactionsFilter filter;

  /// The active (trimmed) search query; empty when browsing.
  final String query;

  /// True while a further page may exist (never for a search).
  final bool hasMore;
  final bool loadingMore;
  final bool refreshing;
  final String? errorMessage;

  bool get isSearching => query.isNotEmpty;

  TransactionsState copyWith({
    TransactionsStatus? status,
    List<Transaction>? items,
    TransactionsFilter? filter,
    String? query,
    bool? hasMore,
    bool? loadingMore,
    bool? refreshing,
    String? errorMessage,
    bool clearError = false,
  }) => TransactionsState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    query: query ?? this.query,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  @override
  List<Object?> get props => [
    status,
    items,
    filter,
    query,
    hasMore,
    loadingMore,
    refreshing,
    errorMessage,
  ];

  @override
  String toString() =>
      'TransactionsState($status, ${items.length} rows, filter=$filter, '
      'query=${query.length} chars, hasMore=$hasMore)';
}

/// Pages the ledger through `ITransactionRepository.getTransactions(limit,
/// offset)` (D-061): [pageSize] rows at a time, the next offset being the
/// number of rows fetched so far minus the rows deleted since, so a delete
/// never skips or repeats a row. Search goes to `searchTransactions`
/// (parameterised, capped by the data source) and is not paged.
///
/// Every request carries a generation number; an answer for an older
/// generation (filter or query changed meanwhile) is dropped.
class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    required ITransactionRepository repository,
    this.pageSize = defaultPageSize,
    this.debounce = defaultDebounce,
    this.onLedgerChanged,
  }) : assert(pageSize > 0, 'pageSize must be positive'),
       _repository = repository,
       super(const TransactionsState());

  /// Rows per page (D-061).
  static const int defaultPageSize = 50;

  /// Keystroke debounce before a search hits storage.
  static const Duration defaultDebounce = Duration(milliseconds: 300);

  /// Longest query sent to storage (UTF-16 units); the data source bounds
  /// it again.
  static const int maxQueryLength = 200;

  final ITransactionRepository _repository;
  final int pageSize;
  final Duration debounce;

  /// Called after a delete or an undo changed the ledger (so the home
  /// screen's bloc can reload).
  final void Function()? onLedgerChanged;

  int _generation = 0;
  int _fetched = 0;
  bool _pageInFlight = false;
  Timer? _debounce;
  String _pendingQuery = '';
  final Map<String, Transaction> _undoBuffer = {};

  /// Rows waiting for an undo (ids), for tests.
  Iterable<String> get pendingUndo => _undoBuffer.keys;

  /// First page for the current filter (skeleton while loading).
  Future<void> load() => _loadFirst(showLoading: true);

  /// Reloads the first page behind the current content (pull-to-refresh).
  Future<void> refresh() => _loadFirst(showLoading: false);

  /// Clears the error and loads again.
  Future<void> retry() => load();

  Future<void> setFilter(TransactionsFilter filter) {
    if (filter == state.filter) return Future.value();
    emit(state.copyWith(filter: filter));
    return _loadFirst(showLoading: true);
  }

  /// Debounced search; an empty query returns to the paged list.
  void search(String query) {
    final trimmed = query.trim();
    final bounded = trimmed.length > maxQueryLength
        ? trimmed.substring(0, maxQueryLength)
        : trimmed;
    _pendingQuery = bounded;
    _debounce?.cancel();
    if (bounded == state.query) return;
    _debounce = Timer(debounce, () {
      _debounce = null;
      if (isClosed) return;
      if (_pendingQuery == state.query) return;
      emit(state.copyWith(query: _pendingQuery));
      unawaited(_loadFirst(showLoading: true));
    });
  }

  /// Loads the next page when one may exist and none is in flight.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || _pageInFlight) return;
    if (state.isSearching || state.status != TransactionsStatus.content) {
      return;
    }
    final generation = _generation;
    _pageInFlight = true;
    emit(state.copyWith(loadingMore: true));
    final result = await _repository.getTransactions(
      limit: pageSize,
      offset: _fetched,
      type: state.filter.type,
    );
    _pageInFlight = false;
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(data: final rows):
        _fetched += rows.length;
        emit(
          state.copyWith(
            items: [...state.items, ...rows],
            hasMore: rows.length >= pageSize,
            loadingMore: false,
          ),
        );
      case Failure(:final message):
        // Keep what is on screen; the next scroll retries.
        emit(state.copyWith(loadingMore: false, errorMessage: message));
    }
  }

  /// Removes the row at once, deletes it from storage and keeps it for
  /// [undo]. The balance is not reverted (ledger rule).
  Future<void> delete(String id) async {
    final row = state.items.where((t) => t.id == id).firstOrNull;
    if (row == null || _undoBuffer.containsKey(id)) return;
    _undoBuffer[id] = row;
    final remaining = state.items.where((t) => t.id != id).toList();
    emit(
      state.copyWith(
        items: remaining,
        status: remaining.isEmpty && !state.hasMore
            ? TransactionsStatus.empty
            : state.status,
      ),
    );
    final result = await _repository.deleteTransaction(id);
    if (isClosed) return;
    switch (result) {
      case Success():
        _fetched = _fetched > 0 ? _fetched - 1 : 0;
        onLedgerChanged?.call();
      case Failure(:final message):
        _undoBuffer.remove(id);
        _reinsert(row);
        emit(state.copyWith(errorMessage: message));
    }
  }

  /// Puts a deleted row back (idempotent: a second undo is a no-op).
  Future<void> undo(String id) async {
    final row = _undoBuffer.remove(id);
    if (row == null) return;
    final result = await _repository.addTransactions([row]);
    if (isClosed) return;
    switch (result) {
      case Success():
        _fetched += 1;
        _reinsert(row);
        onLedgerChanged?.call();
      case Failure(:final message):
        emit(state.copyWith(errorMessage: message));
    }
  }

  /// Drops a pending undo (its toast expired); the row stays deleted.
  void forget(String id) => _undoBuffer.remove(id);

  void _reinsert(Transaction row) {
    if (state.items.any((t) => t.id == row.id)) return;
    final matchesFilter =
        state.filter.type == null || state.filter.type == row.type;
    if (!matchesFilter) return;
    final items = [...state.items, row]..sort(newestFirst);
    emit(
      state.copyWith(
        items: items,
        status: TransactionsStatus.content,
        clearError: true,
      ),
    );
  }

  /// Ledger order: newest first, ties broken by id (same as storage).
  static int newestFirst(Transaction a, Transaction b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  Future<void> _loadFirst({required bool showLoading}) async {
    final generation = ++_generation;
    _pageInFlight = false;
    emit(
      state.copyWith(
        status: showLoading ? TransactionsStatus.loading : state.status,
        refreshing: !showLoading,
        loadingMore: false,
        clearError: true,
      ),
    );
    final searching = state.isSearching;
    final result = searching
        ? await _repository.searchTransactions(
            state.query,
            type: state.filter.type,
          )
        : await _repository.getTransactions(
            limit: pageSize,
            offset: 0,
            type: state.filter.type,
          );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(data: final rows):
        _fetched = searching ? 0 : rows.length;
        emit(
          state.copyWith(
            status: rows.isEmpty
                ? TransactionsStatus.empty
                : TransactionsStatus.content,
            items: rows,
            hasMore: !searching && rows.length >= pageSize,
            refreshing: false,
            loadingMore: false,
            clearError: true,
          ),
        );
      case Failure(:final message):
        emit(
          state.copyWith(
            status: TransactionsStatus.error,
            items: const [],
            hasMore: false,
            refreshing: false,
            loadingMore: false,
            errorMessage: message,
          ),
        );
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
