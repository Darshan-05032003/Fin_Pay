import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/screens/transfer/transfer/contact_search.dart';
import 'package:flutter_test/flutter_test.dart';

const _contacts = [
  Contact(id: 'a', name: 'Priya Raghavan', vpa: 'priya.r@okaxis'),
  Contact(id: 'b', name: 'Rohan Iyer', vpa: 'rohan.iyer@ybl'),
  Contact(id: 'c', name: 'Meera Kulkarni', vpa: 'meera.k@oksbi'),
  Contact(id: 'd', name: 'Arjun Nair', vpa: 'arjun.nair@paytm'),
];

Transaction _sent(String? to, int daysAgo, {TransactionType? type}) =>
    Transaction(
      id: 't-$to-$daysAgo',
      title: 'Sent to $to',
      amount: const Money.paise(-100),
      date: DateTime.utc(2026, 10, 31).subtract(Duration(days: daysAgo)),
      type: type ?? TransactionType.sendMoney,
      icon: 'send',
      recipient: to,
    );

void main() {
  group('ContactSearch.normalise', () {
    test('lower-cases, trims and collapses whitespace', () {
      expect(ContactSearch.normalise('  Priya   RAGHAVAN '), 'priya raghavan');
    });

    test('drops zero-width, bidi and control characters', () {
      expect(ContactSearch.normalise('pri\u200Bya\u202E\u0000'), 'priya');
    });
  });

  group('ContactSearch.matches', () {
    test('matches name or VPA, case-insensitively', () {
      expect(ContactSearch.matches(_contacts[0], 'PRI'), isTrue);
      expect(ContactSearch.matches(_contacts[0], 'okaxis'), isTrue);
      expect(ContactSearch.matches(_contacts[0], 'raghav'), isTrue);
      expect(ContactSearch.matches(_contacts[0], 'rohan'), isFalse);
    });

    test('an empty or whitespace query matches everything', () {
      expect(ContactSearch.matches(_contacts[1], ''), isTrue);
      expect(ContactSearch.matches(_contacts[1], '   '), isTrue);
    });

    test('hostile queries only ever match text', () {
      expect(ContactSearch.matches(_contacts[0], '😀'), isFalse);
      expect(ContactSearch.matches(_contacts[0], "' OR 1=1 --"), isFalse);
      expect(ContactSearch.matches(_contacts[0], '\u202Epriya'), isTrue);
      expect(ContactSearch.matches(_contacts[0], 'a' * 100000), isFalse);
    });
  });

  group('ContactSearch.recentRecipients', () {
    test('newest first, distinct, sendMoney only, at most five', () {
      final txns = [
        _sent('Priya Raghavan', 5),
        _sent('Rohan Iyer', 1),
        _sent('Priya Raghavan', 2),
        _sent('Shop', 0, type: TransactionType.payment),
        _sent(null, 0),
        _sent('A', 10),
        _sent('B', 11),
        _sent('C', 12),
        _sent('D', 13),
        _sent('E', 14),
      ];
      expect(ContactSearch.recentRecipients(txns), [
        'Rohan Iyer',
        'Priya Raghavan',
        'A',
        'B',
        'C',
      ]);
    });

    test('is empty for no transactions', () {
      expect(ContactSearch.recentRecipients(const []), isEmpty);
    });
  });

  group('ContactSearch.rank', () {
    test('recently paid contacts come first, in recency order', () {
      final ranked = ContactSearch.rank(
        _contacts,
        query: '',
        recentRecipients: const ['meera kulkarni', 'Arjun Nair', 'Nobody'],
      );
      expect(ranked.map((c) => c.id), ['c', 'd', 'a', 'b']);
    });

    test('filters by query and keeps the original order otherwise', () {
      final ranked = ContactSearch.rank(
        _contacts,
        query: 'r',
        recentRecipients: const [],
      );
      expect(ranked.map((c) => c.id), ['a', 'b', 'c', 'd']);
      final narrow = ContactSearch.rank(
        _contacts,
        query: 'ok',
        recentRecipients: const [],
      );
      expect(narrow.map((c) => c.id), ['a', 'c']);
    });

    test('returns an empty list when nothing matches', () {
      expect(
        ContactSearch.rank(_contacts, query: 'zzz', recentRecipients: const []),
        isEmpty,
      );
    });

    test('isRecent compares normalised names', () {
      expect(
        ContactSearch.isRecent(_contacts[0], const ['PRIYA raghavan']),
        isTrue,
      );
      expect(
        ContactSearch.isRecent(_contacts[1], const ['Priya Raghavan']),
        isFalse,
      );
    });
  });
}
