import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:intl/intl.dart';

/// The period switcher's options.
enum StatsPeriod {
  week('Week'),
  month('Month'),
  year('Year');

  const StatsPeriod(this.label);

  final String label;
}

/// A local calendar range `[from, to)` (both local midnights).
class StatsRange extends Equatable {
  const StatsRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  /// Number of calendar days covered.
  int get days => StatsMath.dayNumber(to) - StatsMath.dayNumber(from);

  @override
  List<Object?> get props => [from, to];
}

/// One day of the trend line.
class StatsPoint extends Equatable {
  const StatsPoint({
    required this.day,
    required this.spend,
    required this.income,
  });

  final DateTime day;
  final Money spend;
  final Money income;

  @override
  List<Object?> get props => [day, spend, income];
}

/// One bar: a day (week), a six-day slice (month) or a month (year).
class StatsBucket extends Equatable {
  const StatsBucket({
    required this.label,
    required this.start,
    required this.end,
    required this.spend,
    required this.income,
  });

  final String label;

  /// Local midnight, inclusive.
  final DateTime start;

  /// Local midnight, exclusive.
  final DateTime end;
  final Money spend;
  final Money income;

  @override
  List<Object?> get props => [label, start, end, spend, income];
}

/// A slice of the spend donut.
class StatsCategory extends Equatable {
  const StatsCategory({
    required this.key,
    required this.label,
    required this.total,
    required this.share,
  });

  final String key;
  final String label;
  final Money total;

  /// 0…1 of the period's spend.
  final double share;

  @override
  List<Object?> get props => [key, label, total, share];
}

/// A top merchant (by title) for the period.
class StatsMerchant extends Equatable {
  const StatsMerchant({
    required this.title,
    required this.total,
    required this.count,
  });

  final String title;
  final Money total;
  final int count;

  @override
  List<Object?> get props => [title, total, count];
}

/// Everything the statistics screen draws for one period.
class StatsSummary extends Equatable {
  const StatsSummary({
    required this.period,
    required this.range,
    required this.count,
    required this.spend,
    required this.income,
    required this.buckets,
    required this.series,
    required this.categories,
    required this.merchants,
  });

  final StatsPeriod period;
  final StatsRange range;

  /// Rows that fell inside the range.
  final int count;
  final Money spend;
  final Money income;
  final List<StatsBucket> buckets;

  /// One point per calendar day of the range.
  final List<StatsPoint> series;
  final List<StatsCategory> categories;
  final List<StatsMerchant> merchants;

  Money get net => income - spend;

  bool get isEmpty => count == 0;

  @override
  List<Object?> get props => [
    period,
    range,
    count,
    spend,
    income,
    buckets,
    series,
    categories,
    merchants,
  ];

  @override
  String toString() => 'StatsSummary($period, $count rows)';
}

/// Pure aggregation for the statistics screen. Works on local calendar
/// days (DST-safe: days are counted, never 24-hour spans) and on `Money`
/// (int paise; a sum past the int64 bounds throws `MoneyOverflowException`,
/// which the cubit turns into an error state).
abstract final class StatsMath {
  /// How many donut slices before the rest is folded into "Other".
  static const int maxCategories = 5;

  /// How many merchants are listed.
  static const int maxMerchants = 5;

  /// Days per bar in the month view.
  static const int monthBucketDays = 6;

  /// Local midnight of [local].
  static DateTime dayOf(DateTime local) =>
      DateTime(local.year, local.month, local.day);

  /// Calendar day number (days since the epoch, ignoring the zone), so
  /// differences are exact across DST changes.
  static int dayNumber(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// [day] plus [n] calendar days (DST-safe).
  static DateTime addDays(DateTime day, int n) =>
      DateTime(day.year, day.month, day.day + n);

  /// The local range for [period] ending today: the last 7 days, the last
  /// 30 days, or the last 12 calendar months.
  static StatsRange rangeFor(StatsPeriod period, DateTime nowLocal) {
    final today = dayOf(nowLocal);
    final to = addDays(today, 1);
    return switch (period) {
      StatsPeriod.week => StatsRange(from: addDays(today, -6), to: to),
      StatsPeriod.month => StatsRange(from: addDays(today, -29), to: to),
      StatsPeriod.year => StatsRange(
        from: DateTime(today.year, today.month - 11),
        to: to,
      ),
    };
  }

  /// The empty buckets for [period] over [range], in order.
  static List<StatsBucket> emptyBuckets(StatsPeriod period, StatsRange range) {
    StatsBucket bucket(String label, DateTime start, DateTime end) =>
        StatsBucket(
          label: label,
          start: start,
          end: end,
          spend: Money.zero,
          income: Money.zero,
        );
    switch (period) {
      case StatsPeriod.week:
        return [
          for (var i = 0; i < 7; i++)
            bucket(
              DateFormat('E').format(addDays(range.from, i)),
              addDays(range.from, i),
              addDays(range.from, i + 1),
            ),
        ];
      case StatsPeriod.month:
        return [
          for (var i = 0; i < 30 ~/ monthBucketDays; i++)
            bucket(
              DateFormat(
                'd MMM',
              ).format(addDays(range.from, i * monthBucketDays)),
              addDays(range.from, i * monthBucketDays),
              addDays(range.from, (i + 1) * monthBucketDays),
            ),
        ];
      case StatsPeriod.year:
        return [
          for (var i = 0; i < 12; i++)
            bucket(
              DateFormat(
                'MMM',
              ).format(DateTime(range.from.year, range.from.month + i)),
              DateTime(range.from.year, range.from.month + i),
              DateTime(range.from.year, range.from.month + i + 1),
            ),
        ];
    }
  }

  /// Index of the bucket a local [day] falls into, or -1 when outside.
  static int bucketIndex(StatsPeriod period, StatsRange range, DateTime day) {
    final offset = dayNumber(day) - dayNumber(range.from);
    if (offset < 0 || dayNumber(day) >= dayNumber(range.to)) return -1;
    return switch (period) {
      StatsPeriod.week => offset,
      StatsPeriod.month => offset ~/ monthBucketDays,
      StatsPeriod.year =>
        (day.year - range.from.year) * 12 + (day.month - range.from.month),
    };
  }

  /// Category key for a debit: its icon, or its type when the icon is
  /// blank.
  static String categoryKey(Transaction t) =>
      t.icon.trim().isEmpty ? t.type.name : t.icon.trim();

  /// `cart` → `Cart`, `sendMoney` → `Send money`.
  static String categoryLabel(String key) {
    final spaced = key
        .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp('[_-]+'), ' ')
        .trim();
    if (spaced.isEmpty) return 'Other';
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }

  /// Aggregates [rows] for [period] as of [now] (local). [toLocal] maps a
  /// transaction's UTC instant to the wall clock used for grouping
  /// (injectable so tests can pin a zone).
  static StatsSummary summarise(
    List<Transaction> rows, {
    required StatsPeriod period,
    required DateTime now,
    DateTime Function(DateTime utc)? toLocal,
  }) {
    final localOf = toLocal ?? (d) => d.toLocal();
    final range = rangeFor(period, now);
    final buckets = emptyBuckets(period, range);
    final bucketSpend = List.filled(buckets.length, Money.zero);
    final bucketIncome = List.filled(buckets.length, Money.zero);
    final daySpend = List.filled(range.days, Money.zero);
    final dayIncome = List.filled(range.days, Money.zero);
    final categoryTotals = <String, Money>{};
    final merchantTotals = <String, Money>{};
    final merchantCounts = <String, int>{};
    var spend = Money.zero;
    var income = Money.zero;
    var count = 0;

    for (final t in rows) {
      final local = localOf(t.date);
      final day = dayOf(local);
      final dayIdx = dayNumber(day) - dayNumber(range.from);
      if (dayIdx < 0 || dayIdx >= range.days) continue;
      final b = bucketIndex(period, range, day);
      if (b < 0 || b >= buckets.length) continue;
      count++;
      if (t.amount.isNegative) {
        final value = t.amount.abs();
        spend = spend + value;
        bucketSpend[b] = bucketSpend[b] + value;
        daySpend[dayIdx] = daySpend[dayIdx] + value;
        final key = categoryKey(t);
        categoryTotals[key] = (categoryTotals[key] ?? Money.zero) + value;
        final title = t.title.trim().isEmpty ? 'Unknown' : t.title.trim();
        merchantTotals[title] = (merchantTotals[title] ?? Money.zero) + value;
        merchantCounts[title] = (merchantCounts[title] ?? 0) + 1;
      } else {
        income = income + t.amount;
        bucketIncome[b] = bucketIncome[b] + t.amount;
        dayIncome[dayIdx] = dayIncome[dayIdx] + t.amount;
      }
    }

    final filledBuckets = [
      for (var i = 0; i < buckets.length; i++)
        StatsBucket(
          label: buckets[i].label,
          start: buckets[i].start,
          end: buckets[i].end,
          spend: bucketSpend[i],
          income: bucketIncome[i],
        ),
    ];
    final series = [
      for (var i = 0; i < range.days; i++)
        StatsPoint(
          day: addDays(range.from, i),
          spend: daySpend[i],
          income: dayIncome[i],
        ),
    ];

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) {
        final byTotal = b.value.compareTo(a.value);
        return byTotal != 0 ? byTotal : a.key.compareTo(b.key);
      });
    final categories = <StatsCategory>[];
    var other = Money.zero;
    for (final (i, entry) in sortedCategories.indexed) {
      if (i < maxCategories) {
        categories.add(
          StatsCategory(
            key: entry.key,
            label: categoryLabel(entry.key),
            total: entry.value,
            share: share(entry.value, spend),
          ),
        );
      } else {
        other = other + entry.value;
      }
    }
    if (other.isPositive) {
      categories.add(
        StatsCategory(
          key: 'other',
          label: 'Other',
          total: other,
          share: share(other, spend),
        ),
      );
    }

    final merchants =
        merchantTotals.entries
            .map(
              (e) => StatsMerchant(
                title: e.key,
                total: e.value,
                count: merchantCounts[e.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byTotal = b.total.compareTo(a.total);
            return byTotal != 0 ? byTotal : a.title.compareTo(b.title);
          });

    return StatsSummary(
      period: period,
      range: range,
      count: count,
      spend: spend,
      income: income,
      buckets: filledBuckets,
      series: series,
      categories: categories,
      merchants: merchants.take(maxMerchants).toList(),
    );
  }

  /// [part] / [whole] as a fraction (0 when the whole is zero), computed
  /// in integer paise with no double drift until the final division.
  static double share(Money part, Money whole) =>
      whole.isPositive ? part.paise / whole.paise : 0;

  /// Rupees as a double for the chart axes (paise stay exact in `Money`;
  /// the chart only needs a shape).
  static double rupees(Money money) => money.paise / 100;

  /// The largest spend or income in [buckets], or zero.
  static Money peak(List<StatsBucket> buckets) {
    var peak = Money.zero;
    for (final b in buckets) {
      if (b.spend > peak) peak = b.spend;
      if (b.income > peak) peak = b.income;
    }
    return peak;
  }

  /// Which bar a tap at [dx] of a [width]-wide chart with [count] equal
  /// bars hits, or -1.
  static int barAt({
    required double dx,
    required double width,
    required int count,
  }) {
    if (count <= 0 || width <= 0 || dx < 0 || dx >= width) return -1;
    return (dx / width * count).floor().clamp(0, count - 1);
  }
}
