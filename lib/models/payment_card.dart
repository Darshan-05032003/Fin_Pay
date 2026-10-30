import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';

/// Card network. Named `CardType` for compatibility with existing screens.
enum CardType {
  visa,
  mastercard,
  amex,
  rupay;

  /// Parses both `visa` and the legacy `CardType.visa`; unknown → [visa].
  static CardType parse(String? value) {
    final name = value?.split('.').last;
    return CardType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => CardType.visa,
    );
  }
}

/// A payment card linked to the account. Immutable value type.
///
/// Named `PaymentCard` so it never collides with Material's `Card` widget.
/// The full [cardNumber] and [cvv] live only in secure storage and in memory;
/// [toJson] (what sqflite stores) carries just the [maskedNumber].
class PaymentCard extends Equatable {
  const PaymentCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expireDate,
    required this.cvv,
    required this.cardType,
    required this.balance,
  });

  /// Reads the public (masked) representation written by [toJson].
  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    return PaymentCard(
      id: json['id'] as String,
      cardNumber:
          json['cardNumber'] as String? ??
          json['maskedNumber'] as String? ??
          '',
      cardHolderName: json['cardHolderName'] as String,
      expireDate: json['expireDate'] as String,
      cvv: json['cvv'] as String? ?? '',
      cardType: CardType.parse(json['cardType'] as String?),
      balance: Money.fromJson(json['balance']),
    );
  }

  final String id;
  final String cardNumber;
  final String cardHolderName;
  final String expireDate;
  final String cvv;
  final CardType cardType;
  final Money balance;

  /// The last four digits of the PAN, or whatever is available.
  String get last4 {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : '';
  }

  /// `**** **** **** 1234`. Never reveals more than the last four digits.
  String get maskedNumber => last4.isEmpty ? '****' : '**** **** **** $last4';

  /// True when the PAN and CVV have been loaded from secure storage.
  bool get hasFullDetails => cvv.isNotEmpty && !cardNumber.startsWith('*');

  PaymentCard copyWith({
    String? id,
    String? cardNumber,
    String? cardHolderName,
    String? expireDate,
    String? cvv,
    CardType? cardType,
    Money? balance,
  }) {
    return PaymentCard(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      expireDate: expireDate ?? this.expireDate,
      cvv: cvv ?? this.cvv,
      cardType: cardType ?? this.cardType,
      balance: balance ?? this.balance,
    );
  }

  /// Public representation: no PAN, no CVV.
  Map<String, dynamic> toJson() => {
    'id': id,
    'maskedNumber': maskedNumber,
    'cardHolderName': cardHolderName,
    'expireDate': expireDate,
    'cardType': cardType.name,
    'balance': balance.toJson(),
  };

  @override
  List<Object?> get props => [
    id,
    cardNumber,
    cardHolderName,
    expireDate,
    cvv,
    cardType,
    balance,
  ];

  @override
  bool get stringify => false;

  @override
  String toString() =>
      'PaymentCard($id, $maskedNumber, ${cardType.name}, ${balance.format()})';
}
