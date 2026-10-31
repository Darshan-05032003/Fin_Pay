import 'package:fin_pay/models/transaction.dart';
import 'package:intl/intl.dart';

/// One date group in the transactions list.
class TransactionDayGroup {
  const TransactionDayGroup({
    required this.day,
    required this.label,
    required this.items,
  });

  /// Local calendar day (midnight).
  final DateTime day;
  final String label;
  final List<Transaction> items;
}

/// Pure helpers for the transactions screen (grouping, labels, masking).
abstract final class TransactionsMath {
  /// Local calendar day of [local] (midnight, same zone).
  static DateTime dayOf(DateTime local) =>
      DateTime(local.year, local.month, local.day);

  /// "Today", "Yesterday", `d MMM`, or `d MMM yyyy` for another year.
  static String dayLabel(DateTime day, DateTime now) {
    final today = dayOf(now);
    final diff = today.difference(dayOf(day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return day.year == today.year
        ? DateFormat('d MMM').format(day)
        : DateFormat('d MMM yyyy').format(day);
  }

  /// Groups [items] (already newest first) by local calendar day, keeping
  /// their order inside each group.
  static List<TransactionDayGroup> groupByDay(
    List<Transaction> items,
    DateTime now,
  ) {
    final groups = <TransactionDayGroup>[];
    DateTime? currentDay;
    List<Transaction>? bucket;
    for (final t in items) {
      final day = dayOf(t.localDate);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        bucket = [];
        groups.add(
          TransactionDayGroup(
            day: day,
            label: dayLabel(day, now),
            items: bucket,
          ),
        );
      }
      bucket!.add(t);
    }
    return groups;
  }

  /// `Priya Raghavan` → `P••••••••••••n`: first and last character kept
  /// (just the first for very short names), everything else bulleted.
  static String maskCounterparty(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return '—';
    final chars = trimmed.runes.toList();
    if (chars.length <= 2) {
      return String.fromCharCode(chars.first) + '•' * (chars.length - 1);
    }
    return String.fromCharCode(chars.first) +
        '•' * (chars.length - 2) +
        String.fromCharCode(chars.last);
  }

  /// Human label for a ledger type.
  static String typeLabel(TransactionType type) => switch (type) {
    TransactionType.payment => 'Payment',
    TransactionType.sendMoney => 'Sent',
    TransactionType.receiveMoney => 'Received',
    TransactionType.topUp => 'Card top-up',
  };

  /// True when the list is scrolled close enough to the end to fetch the
  /// next page.
  static bool nearEnd({
    required double pixels,
    required double maxScrollExtent,
    double threshold = 600,
  }) => maxScrollExtent - pixels <= threshold;
}
