import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final utc = DateTime.utc(2026, 10, 31, 9, 30);

  group('Transaction', () {
    final tx = Transaction(
      id: 't1',
      title: 'Coffee',
      amount: const Money.paise(-25000),
      date: utc,
      type: TransactionType.payment,
      icon: 'C',
      recipient: 'Blue Tokai',
    );

    test('is a value type', () {
      expect(
        tx,
        Transaction(
          id: 't1',
          title: 'Coffee',
          amount: const Money.paise(-25000),
          date: utc,
          type: TransactionType.payment,
          icon: 'C',
          recipient: 'Blue Tokai',
        ),
      );
      expect(tx.hashCode, tx.copyWith().hashCode);
    });

    test('idempotencyKey defaults to the id', () {
      expect(tx.idempotencyKey, 't1');
      expect(tx.copyWith(idempotencyKey: 'k9').idempotencyKey, 'k9');
    });

    test('stores the date in UTC and exposes a local view', () {
      final local = DateTime(2026, 10, 31, 15);
      final t = tx.copyWith(date: local);
      expect(t.date.isUtc, isTrue);
      expect(t.date, local.toUtc());
      expect(t.localDate, local);
      expect(t.localDate.isUtc, isFalse);
    });

    test('copyWith replaces only the given fields', () {
      final copy = tx.copyWith(amount: const Money.paise(100));
      expect(copy.amount, const Money.paise(100));
      expect(copy.title, 'Coffee');
      // copyWith keeps nullable fields when not provided.
      expect(copy.recipient, 'Blue Tokai');
      expect(tx.copyWith(clearRecipient: true).recipient, isNull);
    });

    test('JSON round-trip uses int paise and UTC ISO-8601', () {
      final json = tx.toJson();
      expect(json['amount'], -25000);
      expect(json['date'], '2026-10-31T09:30:00.000Z');
      expect(json['type'], 'payment');
      expect(json['idempotencyKey'], 't1');
      expect(Transaction.fromJson(json), tx);
    });

    test('fromJson rejects a double amount', () {
      final json = tx.toJson()..['amount'] = -250.0;
      expect(() => Transaction.fromJson(json), throwsFormatException);
    });

    test('fromJson falls back to payment for an unknown type', () {
      final json = tx.toJson()..['type'] = 'crypto';
      expect(Transaction.fromJson(json).type, TransactionType.payment);
    });

    test('isCredit follows the sign of the amount', () {
      expect(tx.isCredit, isFalse);
      expect(tx.copyWith(amount: const Money.paise(1)).isCredit, isTrue);
    });
  });

  group('PaymentCard', () {
    const card = PaymentCard(
      id: 'c1',
      cardNumber: '4111 1111 1111 1234',
      cardHolderName: 'A Person',
      expireDate: '12/28',
      cvv: '987',
      cardType: CardType.visa,
      balance: Money.paise(1000000),
    );

    test('is a value type with copyWith', () {
      expect(card, card.copyWith());
      expect(card.copyWith(balance: Money.zero).balance, Money.zero);
      expect(card.copyWith(cvv: '').cvv, '');
    });

    test('masks everything but the last four digits', () {
      expect(card.maskedNumber, '**** **** **** 1234');
      expect(card.last4, '1234');
      expect(
        card.copyWith(cardNumber: '4111111111111234').maskedNumber,
        '**** **** **** 1234',
      );
      expect(card.copyWith(cardNumber: '12').maskedNumber, '****');
    });

    test('toString never includes the PAN or CVV', () {
      final text = card.toString();
      expect(text, isNot(contains('4111 1111 1111 1234')));
      expect(text, isNot(contains('987')));
      expect(text, contains('1234'));
    });

    test('public JSON omits the PAN and CVV', () {
      final json = card.toJson();
      expect(json.containsKey('cardNumber'), isFalse);
      expect(json.containsKey('cvv'), isFalse);
      expect(json['maskedNumber'], '**** **** **** 1234');
      expect(json['balance'], 1000000);
      expect(json['cardType'], 'visa');
      final restored = PaymentCard.fromJson(json);
      expect(restored.cardNumber, '**** **** **** 1234');
      expect(restored.cvv, '');
      expect(restored.balance, const Money.paise(1000000));
    });

    test('CardType parses legacy enum strings', () {
      expect(CardType.parse('CardType.mastercard'), CardType.mastercard);
      expect(CardType.parse('amex'), CardType.amex);
      expect(CardType.parse('rupay'), CardType.rupay);
      expect(CardType.parse('nonsense'), CardType.visa);
    });
  });

  group('User', () {
    final user = User(
      id: 'u1',
      fullName: 'John Doe',
      email: 'user@finpay.com',
      balance: const Money.paise(5624690),
      createdAt: utc,
    );

    test('has no password field and is a value type', () {
      expect(user.toJson().containsKey('password'), isFalse);
      expect(user, user.copyWith());
      expect(user.copyWith(phone: '+91').phone, '+91');
    });

    test('JSON round-trip with int paise', () {
      final json = user.toJson();
      expect(json['balance'], 5624690);
      expect(json['createdAt'], '2026-10-31T09:30:00.000Z');
      expect(User.fromJson(json), user);
    });

    test('fromJson ignores a legacy password key', () {
      final json = user.toJson()..['password'] = 'hunter2';
      expect(User.fromJson(json), user);
    });
  });

  group('NotificationItem', () {
    final item = NotificationItem(
      id: 'n1',
      title: 'Cashback',
      message: 'You earned ₹10',
      time: utc,
      type: NotificationType.cashback,
    );

    test('value type, copyWith and JSON', () {
      expect(item, item.copyWith());
      expect(item.copyWith(isRead: true).isRead, isTrue);
      expect(item.isRead, isFalse);
      final json = item.toJson();
      expect(json['time'], '2026-10-31T09:30:00.000Z');
      expect(json['type'], 'cashback');
      expect(NotificationItem.fromJson(json), item);
    });

    test('fromJson parses legacy enum strings', () {
      final json = item.toJson()..['type'] = 'NotificationType.billDue';
      expect(NotificationItem.fromJson(json).type, NotificationType.billDue);
    });
  });
}
