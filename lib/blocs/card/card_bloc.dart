import 'dart:async';

import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lists, adds and deletes payment cards.
class CardBloc extends Bloc<CardEvent, CardState> {
  CardBloc({required ICardRepository repository})
    : _repository = repository,
      super(const CardInitial()) {
    on<LoadCardsEvent>(_onLoad);
    on<AddCardEvent>(_onAdd);
    on<DeleteCardEvent>(_onDelete);
  }

  final ICardRepository _repository;
  final StreamController<CardEffect> _effects = StreamController.broadcast();

  /// One-off effects for the UI.
  Stream<CardEffect> get effects => _effects.stream;

  Future<void> _onLoad(LoadCardsEvent event, Emitter<CardState> emit) async {
    emit(const CardLoading());
    final result = await _repository.getCards();
    switch (result) {
      case Success(data: final cards) when cards.isEmpty:
        emit(const CardEmpty());
      case Success(data: final cards):
        emit(CardContent(cards));
      case Failure(:final message):
        emit(CardError(message));
        Logger.error('Failed to load cards: $message');
    }
  }

  Future<void> _onAdd(AddCardEvent event, Emitter<CardState> emit) async {
    final result = await _repository.addCard(event.card);
    switch (result) {
      case Success():
        _effects.add(CardAdded(event.card));
        await _onLoad(const LoadCardsEvent(), emit);
      case Failure(:final message):
        _effects.add(CardFailed(message));
        Logger.error('Failed to add card: $message');
    }
  }

  Future<void> _onDelete(DeleteCardEvent event, Emitter<CardState> emit) async {
    final result = await _repository.deleteCard(event.cardId);
    switch (result) {
      case Success():
        _effects.add(CardDeleted(event.cardId));
        final current = state;
        if (current is CardContent) {
          final remaining = current.cards
              .where((c) => c.id != event.cardId)
              .toList();
          emit(remaining.isEmpty ? const CardEmpty() : CardContent(remaining));
        }
      case Failure(:final message):
        _effects.add(CardFailed(message));
        Logger.error('Failed to delete card: $message');
    }
  }

  @override
  Future<void> close() async {
    await _effects.close();
    await super.close();
  }
}
