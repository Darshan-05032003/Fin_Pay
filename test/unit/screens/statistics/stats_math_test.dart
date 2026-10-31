import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/screens/statistics/stats_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Saturday noon, local wall clock. Tests pin the zone by handing
  // `toLocal` an identity on UTC instants, so the host zone never matters.
  final now = DateTime(2026, 10, 31, 12);
  DateTime utcAsLocal(DateTime utc) =>
      DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);

  Transaction tx(
    String id,
    int paise,
    DateTime utc, {
    String icon = 'cart',
    String title = 'Shop',
    TransactionType? type,
  }) => Transaction(
    id: id,
    title: title,
    amount: Money.paise(paise),
    date: utc,
    type:
        type ??
        (paise < 0 ? TransactionType.payment : TransactionType.receiveMoney),
    icon: icon,
  );

  StatsSummary sum(List<Transaction> rows, StatsPeriod period) =>
      StatsMath.summarise(rows, period: period, now: now, toLocal: utcAsLocal);

  group('ranges', () {
    test('week is the last seven calendar days ending today', () {
      final r = StatsMath.rangeFor(StatsPeriod.week, now);
      expect(r.from, DateTime(2026, 10, 25));
      expect(r.to, DateTime(2026, 11));
      expect(r.days, 7);
    });

    test('month is the last thirty days, year the last twelve months', () {
      final m = StatsMath.rangeFor(StatsPeriod.month, now);
      expect(m.from, DateTime(2026, 10, 2));
      expect(m.days, 30);
      final y = StatsMath.rangeFor(StatsPeriod.year, now);
      expect(y.from, DateTime(2025, 11));
      expect(y.to, DateTime(2026, 11));
      expect(y.days, 365);
    });

    test('a leap year gives 366 days', () {
      final y = StatsMath.rangeFor(StatsPeriod.year, DateTime(2024, 12, 31));
      expect(y.days, 366);
    });

    test('ranges roll over month and year boundaries', () {
      final r = StatsMath.rangeFor(StatsPeriod.week, DateTime(2027, 1, 2));
      expect(r.from, DateTime(2026, 12, 27));
      expect(r.to, DateTime(2027, 1, 3));
    });
  });

  group('buckets', () {
    test('week: seven daily buckets labelled by weekday', () {
      final b = StatsMath.emptyBuckets(
        StatsPeriod.week,
        StatsMath.rangeFor(StatsPeriod.week, now),
      );
      expect(b.map((x) => x.label), [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
      ]);
      expect(b.every((x) => x.spend.isZero && x.income.isZero), isTrue);
    });

    test('month: five six-day slices; year: twelve months', () {
      final m = StatsMath.emptyBuckets(
        StatsPeriod.month,
        StatsMath.rangeFor(StatsPeriod.month, now),
      );
      expect(m.length, 5);
      expect(m.first.label, '2 Oct');
      expect(m.last.end, DateTime(2026, 11));
      final y = StatsMath.emptyBuckets(
        StatsPeriod.year,
        StatsMath.rangeFor(StatsPeriod.year, now),
      );
      expect(y.length, 12);
      expect(y.first.label, 'Nov');
      expect(y.last.label, 'Oct');
      expect(y.last.end, DateTime(2026, 11));
    });

    test('bucketIndex maps days and rejects outsiders', () {
      final r = StatsMath.rangeFor(StatsPeriod.week, now);
      expect(
        StatsMath.bucketIndex(StatsPeriod.week, r, DateTime(2026, 10, 25)),
        0,
      );
      expect(
        StatsMath.bucketIndex(StatsPeriod.week, r, DateTime(2026, 10, 31)),
        6,
      );
      expect(
        StatsMath.bucketIndex(StatsPeriod.week, r, DateTime(2026, 10, 24)),
        -1,
      );
      expect(
        StatsMath.bucketIndex(StatsPeriod.week, r, DateTime(2026, 11)),
        -1,
      );
      final y = StatsMath.rangeFor(StatsPeriod.year, now);
      expect(
        StatsMath.bucketIndex(StatsPeriod.year, y, DateTime(2025, 11, 30)),
        0,
      );
      expect(
        StatsMath.bucketIndex(StatsPeriod.year, y, DateTime(2026, 10, 31)),
        11,
      );
      final m = StatsMath.rangeFor(StatsPeriod.month, now);
      expect(
        StatsMath.bucketIndex(StatsPeriod.month, m, DateTime(2026, 10, 7)),
        0,
      );
      expect(
        StatsMath.bucketIndex(StatsPeriod.month, m, DateTime(2026, 10, 8)),
        1,
      );
    });
  });

  group('summarise', () {
    test('totals, buckets, series, categories and merchants', () {
      final rows = [
        tx(
          'a',
          -10000,
          DateTime.utc(2026, 10, 31, 9),
          icon: 'cup',
          title: 'Coffee',
        ),
        tx('b', -20000, DateTime.utc(2026, 10, 31, 10), title: 'Grocer'),
        tx('c', 50000, DateTime.utc(2026, 10, 30, 8), title: 'Salary'),
        tx(
          'd',
          -5000,
          DateTime.utc(2026, 10, 25, 1),
          icon: 'cup',
          title: 'Coffee',
        ),
        tx('e', -999, DateTime.utc(2026, 10, 24, 23, 59), title: 'Too old'),
        tx('f', -999, DateTime.utc(2026, 11), title: 'Tomorrow'),
      ];
      final s = sum(rows, StatsPeriod.week);
      expect(s.count, 4);
      expect(s.spend, const Money.paise(35000));
      expect(s.income, const Money.paise(50000));
      expect(s.net, const Money.paise(15000));
      expect(s.buckets.length, 7);
      expect(s.buckets[6].spend, const Money.paise(30000));
      expect(s.buckets[5].income, const Money.paise(50000));
      expect(s.buckets[0].spend, const Money.paise(5000));
      expect(s.series.length, 7);
      expect(s.series.first.day, DateTime(2026, 10, 25));
      expect(s.series.last.spend, const Money.paise(30000));
      expect(s.categories.map((c) => c.key), ['cart', 'cup']);
      expect(s.categories.first.label, 'Cart');
      expect(s.categories.first.share, closeTo(20000 / 35000, 1e-9));
      expect(s.categories.last.share, closeTo(15000 / 35000, 1e-9));
      expect(s.merchants.map((m) => m.title), ['Grocer', 'Coffee']);
      expect(s.merchants.last.count, 2);
      expect(s.merchants.last.total, const Money.paise(15000));
      expect(s.isEmpty, isFalse);
    });

    test('empty rows → empty summary with full-length empty series', () {
      final s = sum(const [], StatsPeriod.month);
      expect(s.isEmpty, isTrue);
      expect(s.spend, Money.zero);
      expect(s.series.length, 30);
      expect(s.buckets.length, 5);
      expect(s.categories, isEmpty);
      expect(s.merchants, isEmpty);
    });

    test('year: 365 daily points and twelve monthly buckets', () {
      final rows = [
        for (var i = 0; i < 365; i++)
          tx(
            'y$i',
            -100,
            DateTime.utc(2026, 10, 31, 6).subtract(Duration(days: i)),
          ),
      ];
      final s = sum(rows, StatsPeriod.year);
      expect(s.count, 365);
      expect(s.series.length, 365);
      expect(s.series.every((p) => p.spend == const Money.paise(100)), isTrue);
      expect(s.buckets.length, 12);
      expect(s.buckets.last.spend, const Money.paise(3100));
      expect(s.buckets.first.spend, const Money.paise(3000));
    });

    test('more than five categories fold into Other; type is the key when '
        'the icon is blank', () {
      final rows = [
        for (var i = 0; i < 8; i++)
          tx(
            'c$i',
            -(1000 * (i + 1)),
            DateTime.utc(2026, 10, 31, 8),
            icon: 'cat$i',
          ),
        tx(
          'blank',
          -500,
          DateTime.utc(2026, 10, 31, 8),
          icon: '  ',
          type: TransactionType.sendMoney,
        ),
      ];
      final s = sum(rows, StatsPeriod.week);
      expect(s.categories.length, 6);
      expect(s.categories.last.key, 'other');
      expect(s.categories.last.label, 'Other');
      // cat2 (3000), cat1 (2000), cat0 (1000) and blank (500) fold in.
      expect(s.categories.last.total, const Money.paise(6500));
      expect(
        s.categories.fold<double>(0, (acc, c) => acc + c.share),
        closeTo(1, 1e-9),
      );
      expect(StatsMath.categoryLabel('sendMoney'), 'Send money');
      expect(StatsMath.categoryLabel('top_up'), 'Top up');
      expect(StatsMath.categoryLabel(''), 'Other');
    });

    test('zone edges: a late-night UTC row lands on the local day the '
        'injected zone says', () {
      DateTime ist(DateTime utc) {
        final shifted = utc.add(const Duration(hours: 5, minutes: 30));
        return utcAsLocal(shifted);
      }

      final rows = [tx('n', -100, DateTime.utc(2026, 10, 30, 20))];
      final asUtc = sum(rows, StatsPeriod.week);
      expect(asUtc.buckets[5].spend, const Money.paise(100), reason: 'Fri');
      final asIst = StatsMath.summarise(
        rows,
        period: StatsPeriod.week,
        now: now,
        toLocal: ist,
      );
      expect(asIst.buckets[6].spend, const Money.paise(100), reason: 'Sat');
    });

    test('DST-sized day: calendar days are counted, not 24-hour spans', () {
      // 25 hours between the two rows, consecutive calendar days.
      final rows = [
        tx('a', -100, DateTime.utc(2026, 10, 30, 23)),
        tx('b', -100, DateTime.utc(2026, 10, 29, 22)),
      ];
      final s = sum(rows, StatsPeriod.week);
      expect(s.buckets[5].spend, const Money.paise(100));
      expect(s.buckets[4].spend, const Money.paise(100));
      expect(
        StatsMath.addDays(DateTime(2026, 3, 29), 1),
        DateTime(2026, 3, 30),
      );
      expect(
        StatsMath.dayNumber(DateTime(2026, 3, 30)) -
            StatsMath.dayNumber(DateTime(2026, 3, 29)),
        1,
      );
    });

    test('paise sums near the int64 bounds overflow loudly, never wrap', () {
      final big = tx(
        'big',
        -(Money.max.paise - 1),
        DateTime.utc(2026, 10, 31, 8),
      );
      final small = tx('small', -2, DateTime.utc(2026, 10, 31, 9));
      expect(
        () => sum([big, small], StatsPeriod.week),
        throwsA(isA<MoneyOverflowException>()),
      );
      final fine = sum([big], StatsPeriod.week);
      expect(fine.spend.paise, Money.max.paise - 1);
      expect(fine.categories.single.share, 1);
      final credit = tx(
        'c',
        Money.max.paise - 1,
        DateTime.utc(2026, 10, 31, 8),
      );
      expect(
        () => sum([
          credit,
          tx('c2', 5, DateTime.utc(2026, 10, 31, 9)),
        ], StatsPeriod.week),
        throwsA(isA<MoneyOverflowException>()),
      );
    });

    test('merchants are capped at five, ties broken by title', () {
      final rows = [
        for (var i = 0; i < 7; i++)
          tx('m$i', -1000, DateTime.utc(2026, 10, 31, 8), title: 'M$i'),
      ];
      final s = sum(rows, StatsPeriod.week);
      expect(s.merchants.length, 5);
      expect(s.merchants.map((m) => m.title), ['M0', 'M1', 'M2', 'M3', 'M4']);
    });
  });

  group('helpers', () {
    test('share, rupees, peak, barAt', () {
      expect(StatsMath.share(const Money.paise(1), const Money.paise(4)), 0.25);
      expect(StatsMath.share(const Money.paise(1), Money.zero), 0);
      expect(StatsMath.rupees(const Money.paise(12345)), 123.45);
      expect(
        StatsMath.peak([
          StatsBucket(
            label: 'a',
            start: DateTime(2026),
            end: DateTime(2026, 1, 2),
            spend: const Money.paise(5),
            income: const Money.paise(9),
          ),
        ]),
        const Money.paise(9),
      );
      expect(StatsMath.peak(const []), Money.zero);
      expect(StatsMath.barAt(dx: 0, width: 700, count: 7), 0);
      expect(StatsMath.barAt(dx: 699, width: 700, count: 7), 6);
      expect(StatsMath.barAt(dx: 350, width: 700, count: 7), 3);
      expect(StatsMath.barAt(dx: -1, width: 700, count: 7), -1);
      expect(StatsMath.barAt(dx: 700, width: 700, count: 7), -1);
      expect(StatsMath.barAt(dx: 10, width: 0, count: 7), -1);
      expect(StatsMath.barAt(dx: 10, width: 700, count: 0), -1);
    });
  });
}
