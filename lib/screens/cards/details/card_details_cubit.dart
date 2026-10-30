import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where a removal is.
enum CardRemoveStatus { idle, removing, removed, failed }

/// Per-card screen state: the freeze flag (local, this session), the flip
/// and the removal progress.
class CardDetailsState extends Equatable {
  const CardDetailsState({
    this.frozen = false,
    this.flipped = false,
    this.removal = CardRemoveStatus.idle,
    this.message,
    this.copies = 0,
  });

  final bool frozen;
  final bool flipped;
  final CardRemoveStatus removal;

  /// Why the removal failed.
  final String? message;

  /// How many times the last four digits were copied (for the toast).
  final int copies;

  bool get busy => removal == CardRemoveStatus.removing;

  CardDetailsState copyWith({
    bool? frozen,
    bool? flipped,
    CardRemoveStatus? removal,
    Object? message = _keep,
    int? copies,
  }) => CardDetailsState(
    frozen: frozen ?? this.frozen,
    flipped: flipped ?? this.flipped,
    removal: removal ?? this.removal,
    message: message == _keep ? this.message : message as String?,
    copies: copies ?? this.copies,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [frozen, flipped, removal, message, copies];
}

/// Freeze, flip, copy-last-4 bookkeeping and removal of one card through
/// [CardBloc]. The freeze flag is local to the session (the data layer has
/// no column for it); nothing here ever touches the PAN or CVV.
class CardDetailsCubit extends Cubit<CardDetailsState> {
  CardDetailsCubit({
    required CardBloc cards,
    required this.cardId,
    this.timeout = const Duration(seconds: 10),
  }) : _cards = cards,
       super(const CardDetailsState());

  final CardBloc _cards;
  final String cardId;
  final Duration timeout;

  void setFrozen({required bool frozen}) {
    if (state.frozen != frozen) emit(state.copyWith(frozen: frozen));
  }

  void toggleFlip() => emit(state.copyWith(flipped: !state.flipped));

  /// Turns the card to its front (the app went to the background).
  void unflip() {
    if (state.flipped) emit(state.copyWith(flipped: false));
  }

  void copiedLast4() => emit(state.copyWith(copies: state.copies + 1));

  /// Removes the card once; repeated calls while one is in flight do
  /// nothing.
  Future<void> remove() async {
    if (state.busy || state.removal == CardRemoveStatus.removed) return;
    emit(state.copyWith(removal: CardRemoveStatus.removing, message: null));
    final effect = await _awaitOutcome();
    if (isClosed) return;
    switch (effect) {
      case CardDeleted():
        emit(state.copyWith(removal: CardRemoveStatus.removed));
      case CardFailed(:final message):
        emit(
          state.copyWith(
            removal: CardRemoveStatus.failed,
            message: identical(effect, _unanswered)
                ? 'Could not remove the card. Please try again.'
                : message,
          ),
        );
      case CardAdded():
        break;
    }
  }

  static const CardFailed _unanswered = CardFailed('unanswered');

  Future<CardEffect> _awaitOutcome() async {
    if (_cards.isClosed) return _unanswered;
    final outcome = _cards.effects
        .where(
          (e) => (e is CardDeleted && e.cardId == cardId) || e is CardFailed,
        )
        .first
        .timeout(timeout, onTimeout: () => _unanswered)
        .catchError((Object _) => _unanswered);
    _cards.add(DeleteCardEvent(cardId));
    return await outcome;
  }
}
