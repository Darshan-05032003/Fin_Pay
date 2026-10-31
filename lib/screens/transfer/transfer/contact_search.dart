import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/models/transaction.dart';

/// Pure filtering and ranking of the payee list.
abstract final class ContactSearch {
  /// How many recently paid names are remembered.
  static const int recentLimit = 5;

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Lower-cases, trims, collapses whitespace and drops zero-width and
  /// bidi-control characters, so a hostile query still only matches text.
  static String normalise(String input) {
    final kept = StringBuffer();
    for (final rune in input.runes) {
      if ((rune >= 0x200B && rune <= 0x200F) ||
          (rune >= 0x202A && rune <= 0x202E) ||
          (rune >= 0x2066 && rune <= 0x2069) ||
          rune == 0xFEFF ||
          rune < 0x20) {
        continue;
      }
      kept.writeCharCode(rune);
    }
    return kept.toString().toLowerCase().replaceAll(_whitespace, ' ').trim();
  }

  /// True when the name or VPA contains the normalised [query]; an empty
  /// query matches everything.
  static bool matches(Contact contact, String query) {
    final q = normalise(query);
    if (q.isEmpty) return true;
    return normalise(contact.name).contains(q) ||
        normalise(contact.vpa).contains(q);
  }

  /// Names of the most recent distinct `sendMoney` recipients, newest
  /// first, at most [recentLimit].
  static List<String> recentRecipients(List<Transaction> transactions) {
    final seen = <String>{};
    final names = <String>[];
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    for (final t in sorted) {
      final name = t.recipient;
      if (t.type != TransactionType.sendMoney || name == null) continue;
      final key = normalise(name);
      if (key.isEmpty || !seen.add(key)) continue;
      names.add(name);
      if (names.length == recentLimit) break;
    }
    return names;
  }

  /// Filters by [query] and puts recently paid contacts first (in recency
  /// order); everything else keeps its original order.
  static List<Contact> rank(
    List<Contact> contacts, {
    required String query,
    required List<String> recentRecipients,
  }) {
    final recent = {
      for (var i = 0; i < recentRecipients.length; i++)
        normalise(recentRecipients[i]): i,
    };
    final filtered = contacts.where((c) => matches(c, query)).toList();
    final indexed = filtered.asMap().entries.toList()
      ..sort((a, b) {
        final ra = recent[normalise(a.value.name)] ?? recentLimit;
        final rb = recent[normalise(b.value.name)] ?? recentLimit;
        if (ra != rb) return ra.compareTo(rb);
        return a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  /// True when [contact] is one of [recentRecipients].
  static bool isRecent(Contact contact, List<String> recentRecipients) =>
      recentRecipients.any((n) => normalise(n) == normalise(contact.name));
}
