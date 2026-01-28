import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/services/database_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// BLoC for managing card state
/// 
/// This BLoC handles all card-related operations including:
/// - Loading cards
/// - Adding new cards
/// - Deleting cards
class CardBloc extends Bloc<CardEvent, CardState> {

  CardBloc({required DatabaseService db}) : _db = db, super(const CardInitial()) {
    on<LoadCardsEvent>(_onLoadCards);
    on<AddCardEvent>(_onAddCard);
    on<DeleteCardEvent>(_onDeleteCard);
  }
  final DatabaseService _db;

  /// Handle loading cards
  Future<void> _onLoadCards(
    LoadCardsEvent event,
    Emitter<CardState> emit,
  ) async {
    emit(const CardLoading());

    try {
      final cards = await _db.getCards();
      emit(CardLoaded(cards));
      Logger.info('Loaded ${cards.length} cards');
    } catch (e) {
      emit(CardError('Failed to load cards: $e'));
      Logger.error('Error loading cards', e);
    }
  }

  /// Handle adding a new card
  Future<void> _onAddCard(
    AddCardEvent event,
    Emitter<CardState> emit,
  ) async {
    try {
      await _db.insertCard(event.card);
      final currentState = state;
      if (currentState is CardLoaded) {
        final updatedCards = [...currentState.cards, event.card];
        emit(CardLoaded(updatedCards));
      } else {
        add(const LoadCardsEvent());
      }
      Logger.info('Card added successfully');
    } catch (e) {
      emit(CardError('Failed to add card: $e'));
      Logger.error('Error adding card', e);
    }
  }

  /// Handle deleting a card
  Future<void> _onDeleteCard(
    DeleteCardEvent event,
    Emitter<CardState> emit,
  ) async {
    try {
      await _db.deleteCard(event.cardId);
      final currentState = state;
      if (currentState is CardLoaded) {
        final updatedCards = currentState.cards
            .where((c) => c.id != event.cardId)
            .toList();
        emit(CardLoaded(updatedCards));
      }
      Logger.info('Card deleted successfully');
    } catch (e) {
      emit(CardError('Failed to delete card: $e'));
      Logger.error('Error deleting card', e);
    }
  }
}
