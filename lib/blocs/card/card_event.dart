import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/payment_card.dart';

sealed class CardEvent extends Equatable {
  const CardEvent();

  @override
  List<Object?> get props => [];
}

final class LoadCardsEvent extends CardEvent {
  const LoadCardsEvent();
}

final class AddCardEvent extends CardEvent {
  const AddCardEvent(this.card);

  final PaymentCard card;

  @override
  List<Object?> get props => [card];
}

final class DeleteCardEvent extends CardEvent {
  const DeleteCardEvent(this.cardId);

  final String cardId;

  @override
  List<Object?> get props => [cardId];
}
