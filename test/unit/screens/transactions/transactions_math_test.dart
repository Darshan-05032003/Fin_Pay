import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/screens/transactions/transactions_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31, 12);

  Transaction at(String id, DateTime date) => Transaction(
    id: id,
    title: id,
    amount: const Money.paise(-100),
    date: date,
    type: TransactionType.payment,
    icon: 'x',
  );

  group('dayLabel', () {
    test('today, yesterday, same year, other year', () {
      expect(
        TransactionsMath.dayLabel(DateTime(2026, 10, 31, 23), now),
        'Today',
      );
      expect(
        TransactionsMath.dayLabel(DateTime(2026, 10, 30, 1), now),
        'Yesterday',
      );
      expect(TransactionsMath.dayLabel(DateTime(2026, 3, 9), now), '9 Mar');
      expect(
        TransactionsMath.dayLabel(DateTime(2025, 12, 31), now),
        '31 Dec 2025',
      );
    });

    test('a date in the future is just a date', () {
      expect(TransactionsMath.dayLabel(DateTime(2026, 11, 2), now), '2 Nov');
    });
  });

  group('groupByDay', () {
    test('keeps order and splits on local calendar days', () {
      final rows = [
        at('a', DateTime(2026, 10, 31, 11)),
        at('b', DateTime(2026, 10, 31, 1)),
        at('c', DateTime(2026, 10, 30, 23, 59)),
        at('d', DateTime(2026, 10)),
      ];
      final groups = TransactionsMath.groupByDay(rows, now);
      expect(groups.map((g) => g.label), ['Today', 'Yesterday', '1 Oct']);
      expect(groups.first.items.map((t) => t.id), ['a', 'b']);
      expect(groups[1].items.map((t) => t.id), ['c']);
      expect(groups.last.items.map((t) => t.id), ['d']);
    });

    test('empty input → no groups', () {
      expect(TransactionsMath.groupByDay(const [], now), isEmpty);
    });

    test('rows across a DST-sized gap still land on calendar days', () {
      // 23 h apart but on different calendar days.
      final rows = [
        at('a', DateTime(2026, 10, 31, 0, 30)),
        at('b', DateTime(2026, 10, 30, 1, 30)),
      ];
      expect(TransactionsMath.groupByDay(rows, now).length, 2);
    });
  });

  group('maskCounterparty', () {
    test('keeps first and last character', () {
      expect(
        TransactionsMath.maskCounterparty('Priya Raghavan'),
        'P••••••••••••n',
      );
      expect(TransactionsMath.maskCounterparty('Priya'), 'P•••a');
      expect(TransactionsMath.maskCounterparty('Al'), 'A•');
      expect(TransactionsMath.maskCounterparty('A'), 'A');
    });

    test('blank → em dash; unicode is masked by code point', () {
      expect(TransactionsMath.maskCounterparty(null), '—');
      expect(TransactionsMath.maskCounterparty('   '), '—');
      expect(TransactionsMath.maskCounterparty('मीरा'), 'म••ा');
      expect(TransactionsMath.maskCounterparty('🙂🙂🙂'), '🙂•🙂');
    });
  });

  group('typeLabel and nearEnd', () {
    test('every type has a label', () {
      for (final t in TransactionType.values) {
        expect(TransactionsMath.typeLabel(t), isNotEmpty);
      }
    });

    test('nearEnd within the threshold', () {
      expect(TransactionsMath.nearEnd(pixels: 0, maxScrollExtent: 0), isTrue);
      expect(
        TransactionsMath.nearEnd(pixels: 1000, maxScrollExtent: 1500),
        isTrue,
      );
      expect(
        TransactionsMath.nearEnd(pixels: 0, maxScrollExtent: 1500),
        isFalse,
      );
    });
  });
}
