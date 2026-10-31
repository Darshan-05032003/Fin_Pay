import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/screens/statistics/stats_math.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum StatsStatus { loading, content, empty, error }

/// State of the statistics screen. [revision] changes on every successful
/// load, so the charts re-run their entrance when the period switches.
class StatsState extends Equatable {
  const StatsState({
    this.status = StatsStatus.loading,
    this.period = StatsPeriod.week,
    this.summary,
    this.revision = 0,
    this.message,
  });

  final StatsStatus status;
  final StatsPeriod period;
  final StatsSummary? summary;
  final int revision;
  final String? message;

  StatsState copyWith({
    StatsStatus? status,
    StatsPeriod? period,
    StatsSummary? summary,
    int? revision,
    String? message,
    bool clearMessage = false,
  }) => StatsState(
    status: status ?? this.status,
    period: period ?? this.period,
    summary: summary ?? this.summary,
    revision: revision ?? this.revision,
    message: clearMessage ? null : (message ?? this.message),
  );

  @override
  List<Object?> get props => [status, period, summary, revision, message];

  @override
  String toString() => 'StatsState($status, $period, rev $revision)';
}

/// Loads the rows of the selected period through
/// `ITransactionRepository.getTransactionsBetween` and aggregates them with
/// [StatsMath]. "Now" comes from the injected [Clock].
class StatsCubit extends Cubit<StatsState> {
  StatsCubit({
    required ITransactionRepository repository,
    required Clock clock,
    this.toLocal,
  }) : _repository = repository,
       _clock = clock,
       super(const StatsState());

  final ITransactionRepository _repository;
  final Clock _clock;

  /// Overrides the zone mapping used for grouping (tests).
  final DateTime Function(DateTime utc)? toLocal;

  int _generation = 0;

  Future<void> load() => _load(showLoading: true);

  Future<void> retry() => load();

  /// Reloads quietly behind the current charts (pull-to-refresh).
  Future<void> refresh() => _load(showLoading: false);

  Future<void> setPeriod(StatsPeriod period) {
    if (period == state.period) return Future.value();
    emit(state.copyWith(period: period));
    return _load(showLoading: true);
  }

  Future<void> _load({required bool showLoading}) async {
    final generation = ++_generation;
    final period = state.period;
    final now = toLocal?.call(_clock.now().toUtc()) ?? _clock.now().toLocal();
    final range = StatsMath.rangeFor(period, now);
    if (showLoading) {
      emit(state.copyWith(status: StatsStatus.loading, clearMessage: true));
    }
    final result = await _repository.getTransactionsBetween(
      _toUtc(range.from),
      _toUtc(range.to),
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(data: final rows):
        try {
          final summary = StatsMath.summarise(
            rows,
            period: period,
            now: now,
            toLocal: toLocal,
          );
          emit(
            state.copyWith(
              status: summary.isEmpty ? StatsStatus.empty : StatsStatus.content,
              summary: summary,
              revision: state.revision + 1,
              clearMessage: true,
            ),
          );
        } on MoneyOverflowException {
          emit(
            state.copyWith(
              status: StatsStatus.error,
              message: 'Amounts out of range',
            ),
          );
        }
      case Failure(:final message):
        emit(state.copyWith(status: StatsStatus.error, message: message));
    }
  }

  /// A local midnight as the UTC instant storage compares against. With an
  /// injected zone mapping the local wall clock is treated as UTC (tests).
  DateTime _toUtc(DateTime local) => toLocal == null
      ? local.toUtc()
      : DateTime.utc(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
        );
}
