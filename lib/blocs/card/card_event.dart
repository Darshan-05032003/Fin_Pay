import 'package:equatable/equatable.dart';
import '../../models/card.dart';

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
  final Card card;

  const AddCardEvent(this.card);

  @override
  List<Object?> get props => [card];
}

/// Event to delete a card
class DeleteCardEvent extends CardEvent {
  final String cardId;

  const DeleteCardEvent(this.cardId);

  @override
  List<Object?> get props => [cardId];
}
