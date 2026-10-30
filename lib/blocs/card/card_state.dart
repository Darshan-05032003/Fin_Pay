import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/payment_card.dart';

/// State of the card list.
sealed class CardState extends Equatable {
  const CardState();

  @override
  List<Object?> get props => [];
}

final class CardInitial extends CardState {
  const CardInitial();
}

final class CardLoading extends CardState {
  const CardLoading();
}

final class CardEmpty extends CardState {
  const CardEmpty();
}

final class CardError extends CardState {
  const CardError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class CardContent extends CardState {
  const CardContent(this.cards);

  final List<PaymentCard> cards;

  @override
  List<Object?> get props => [cards];
}

/// One-off effects for the UI.
sealed class CardEffect extends Equatable {
  const CardEffect();

  @override
  List<Object?> get props => [];
}

final class CardAdded extends CardEffect {
  const CardAdded(this.card);

  final PaymentCard card;

  @override
  List<Object?> get props => [card];
}

final class CardDeleted extends CardEffect {
  const CardDeleted(this.cardId);

  final String cardId;

  @override
  List<Object?> get props => [cardId];
}

final class CardFailed extends CardEffect {
  const CardFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
