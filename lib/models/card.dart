class Card {

  Card({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expireDate,
    required this.cvv,
    required this.cardType,
    required this.balance,
  });
  final String id;
  final String cardNumber;
  final String cardHolderName;
  final String expireDate;
  final String cvv;
  final CardType cardType;
  final double balance;

  String get maskedNumber {
    final parts = cardNumber.split(' ');
    if (parts.length >= 4) {
      return '${parts[0]} **** **** ${parts[3]}';
    }
    return cardNumber;
  }
}

enum CardType {
  visa,
  mastercard,
  amex,
}

