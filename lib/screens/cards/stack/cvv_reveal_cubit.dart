import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether a CVV is on screen.
enum CvvRevealStatus { hidden, loading, revealed, failed }

/// State of a timed CVV reveal. The digits are **never** part of the state:
/// read them through [CvvRevealCubit.cvv] while [status] is
/// [CvvRevealStatus.revealed].
class CvvRevealState extends Equatable {
  const CvvRevealState({
    this.status = CvvRevealStatus.hidden,
    this.cardId,
    this.remaining = Duration.zero,
    this.message,
  });

  final CvvRevealStatus status;

  /// The card whose CVV is loading / shown.
  final String? cardId;

  /// Time left before the CVV is masked again.
  final Duration remaining;

  /// Why the reveal failed.
  final String? message;

  bool isRevealed(String id) =>
      status == CvvRevealStatus.revealed && cardId == id;

  bool isLoading(String id) =>
      status == CvvRevealStatus.loading && cardId == id;

  @override
  List<Object?> get props => [status, cardId, remaining, message];
}

/// Fetches a card's CVV from secure storage for a short window, counts it
/// down on the injected [Clock], masks it again when the window ends, when
/// [hide] is called (backgrounding) or when the cubit closes, and drops the
/// digits from memory each time.
class CvvRevealCubit extends Cubit<CvvRevealState> {
  CvvRevealCubit({
    required ICardRepository repository,
    Clock? clock,
    this.ttl = const Duration(seconds: 5),
    this.tick = const Duration(seconds: 1),
  }) : _repository = repository,
       _clock = clock ?? const Clock(),
       super(const CvvRevealState());

  final ICardRepository _repository;
  final Clock _clock;

  /// How long the CVV stays visible.
  final Duration ttl;

  /// Countdown resolution.
  final Duration tick;

  String? _cvv;
  Timer? _timer;
  DateTime? _deadline;
  int _generation = 0;

  /// The digits while revealed, otherwise null. Never logged.
  String? get cvv => state.status == CvvRevealStatus.revealed ? _cvv : null;

  /// Reveals [cardId]'s CVV for [ttl]. A second call for the same card
  /// while it is shown restarts the window; a call for another card swaps.
  Future<void> reveal(String cardId) async {
    if (state.isRevealed(cardId)) {
      _arm();
      return;
    }
    if (state.isLoading(cardId)) return;
    final generation = ++_generation;
    _clear();
    emit(CvvRevealState(status: CvvRevealStatus.loading, cardId: cardId));
    final result = await _repository.readCvv(cardId);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(data: final digits) when digits != null && digits.isNotEmpty:
        _cvv = digits;
        emit(
          CvvRevealState(
            status: CvvRevealStatus.revealed,
            cardId: cardId,
            remaining: ttl,
          ),
        );
        _arm();
      case Success():
        emit(
          CvvRevealState(
            status: CvvRevealStatus.failed,
            cardId: cardId,
            message: 'No CVV stored for this card',
          ),
        );
      case Failure(:final message):
        emit(
          CvvRevealState(
            status: CvvRevealStatus.failed,
            cardId: cardId,
            message: message,
          ),
        );
    }
  }

  /// Masks the CVV now and forgets the digits.
  void hide() {
    _generation++;
    _clear();
    if (state.status != CvvRevealStatus.hidden) {
      emit(const CvvRevealState());
    }
  }

  void _arm() {
    _timer?.cancel();
    _deadline = _clock.now().add(ttl);
    _timer = Timer.periodic(tick, (_) => _tick());
    if (state.remaining != ttl) {
      emit(
        CvvRevealState(
          status: CvvRevealStatus.revealed,
          cardId: state.cardId,
          remaining: ttl,
        ),
      );
    }
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    var remaining = deadline.difference(_clock.now());
    // A clock jump backwards cannot keep the CVV on screen longer than ttl.
    if (remaining > ttl) remaining = ttl;
    if (remaining <= Duration.zero) {
      hide();
      return;
    }
    if (remaining != state.remaining) {
      emit(
        CvvRevealState(
          status: CvvRevealStatus.revealed,
          cardId: state.cardId,
          remaining: remaining,
        ),
      );
    }
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _cvv = null;
  }

  @override
  Future<void> close() {
    _clear();
    return super.close();
  }
}
