import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/models/payment_card.dart';

/// Repository interface for payment cards.
///
/// The PAN and CVV are kept in secure storage; the database holds only the
/// masked number. [getCards] returns cards with PAN and CVV attached when they
/// are available.
abstract interface class ICardRepository {
  Future<Result<List<PaymentCard>>> getCards();
  Future<Result<void>> addCard(PaymentCard card);
  Future<Result<void>> deleteCard(String cardId);
}
