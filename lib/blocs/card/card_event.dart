import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/card.dart';

/// Base class for all card-related events
abstract class CardEvent extends Equatable {
  const CardEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load cards
class LoadCardsEvent extends CardEvent {
  const LoadCardsEvent();
}

/// Event to add a new card
class AddCardEvent extends CardEvent {

  const AddCardEvent(this.card);
  final Card card;

  @override
  List<Object?> get props => [card];
}

/// Event to delete a card
class DeleteCardEvent extends CardEvent {

  const DeleteCardEvent(this.cardId);
  final String cardId;

  @override
  List<Object?> get props => [cardId];
}
