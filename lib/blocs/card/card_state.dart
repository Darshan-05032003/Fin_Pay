import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/card.dart';

/// Base class for all card-related states
abstract class CardState extends Equatable {
  const CardState();

  @override
  List<Object?> get props => [];
}

/// Initial state when card bloc is created
class CardInitial extends CardState {
  const CardInitial();
}

/// State when cards are being loaded
class CardLoading extends CardState {
  const CardLoading();
}

/// State when cards are successfully loaded
class CardLoaded extends CardState {

  const CardLoaded(this.cards);
  final List<Card> cards;

  @override
  List<Object?> get props => [cards];
}

/// State when an error occurs
class CardError extends CardState {

  const CardError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
