import 'package:clock/clock.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'home_cards_fixtures.dart';
import 'screen_harness.dart';

class MockNotificationRepository extends Mock
    implements INotificationRepository {}

/// The fixed "now" every insights/activity test runs at (a Saturday noon,
/// UTC; the test host's zone is UTC too).
final DateTime insightsNow = DateTime.utc(2026, 10, 31, 12);

/// A deterministic ledger of [count] rows spread over the past days:
/// `rowsPerDay` rows per calendar day, alternating debits and credits,
/// several categories (icons) and counterparties. Newest first.
List<Transaction> fixtureLedger(
  int count, {
  DateTime? now,
  int rowsPerDay = 6,
}) {
  final at = now ?? insightsNow;
  const titles = [
    'Grocery run',
    'Coffee',
    'Sent to Priya',
    'Salary',
    'Electricity bill',
    'Cinema',
    'Wallet top-up',
    'Rent',
  ];
  const icons = ['cart', 'cup', 'send', 'bank', 'bolt', 'film', 'plus', 'home'];
  const types = [
    TransactionType.payment,
    TransactionType.payment,
    TransactionType.sendMoney,
    TransactionType.receiveMoney,
    TransactionType.payment,
    TransactionType.payment,
    TransactionType.topUp,
    TransactionType.payment,
  ];
  return [
    for (var i = 0; i < count; i++)
      Transaction(
        id: 'tx${i.toString().padLeft(6, '0')}',
        title: titles[i % titles.length],
        amount: Money.paise(
          types[i % types.length] == TransactionType.receiveMoney ||
                  types[i % types.length] == TransactionType.topUp
              ? 250000 + (i % 5) * 100000
              : -(15000 + (i % 9) * 23000),
        ),
        date: at.subtract(
          Duration(days: i ~/ rowsPerDay, minutes: 17 * (i % rowsPerDay) + 5),
        ),
        type: types[i % types.length],
        icon: icons[i % icons.length],
        recipient: i % 8 == 2 ? 'Priya Raghavan' : null,
      ),
  ];
}

/// Eight notifications, three unread, newest first.
List<NotificationItem> fixtureNotifications({DateTime? now}) {
  final at = now ?? insightsNow;
  const titles = [
    'Cashback credited',
    'Bill due tomorrow',
    'Card linked',
    'Payment request',
    'Profile updated',
    'Reminder: rent',
    'Cashback credited',
    'Bill paid',
  ];
  const types = [
    NotificationType.cashback,
    NotificationType.billDue,
    NotificationType.cardLinked,
    NotificationType.paymentRequest,
    NotificationType.profileUpdate,
    NotificationType.paymentReminder,
    NotificationType.cashback,
    NotificationType.billDue,
  ];
  return [
    for (var i = 0; i < titles.length; i++)
      NotificationItem(
        id: 'n$i',
        title: titles[i],
        message: 'Message ${i + 1} for ${titles[i].toLowerCase()}.',
        time: at.subtract(Duration(hours: 3 * i + 1)),
        type: types[i],
        isRead: i >= 3,
      ),
  ];
}

/// Mocked repositories for the statistics, transactions, notifications and
/// profile screens. The transaction mock pages a fixture ledger honestly
/// (limit / offset / type / search), so paging is exercised end to end.
class InsightsRepos {
  InsightsRepos({int ledgerRows = 40, DateTime? now})
    : now = now ?? insightsNow {
    ledger = fixtureLedger(ledgerRows, now: this.now);
    notifications = fixtureNotifications(now: this.now);
    registerFallbackValue(fixtureLedger(1).first);
    registerFallbackValue(notifications.first);
    registerFallbackValue(harnessUser);
    registerFallbackValue(fixtureCards.first);
    when(
      () => txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((inv) async {
      final limit = inv.namedArguments[#limit] as int?;
      final offset = inv.namedArguments[#offset] as int? ?? 0;
      final type = inv.namedArguments[#type] as TransactionType?;
      final filtered = ledger.where((t) => type == null || t.type == type);
      final page = filtered.skip(offset);
      return Success((limit == null ? page : page.take(limit)).toList());
    });
    when(
      () => txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((inv) async {
      final limit = inv.namedArguments[#limit] as int?;
      final offset = inv.namedArguments[#offset] as int? ?? 0;
      final page = ledger.skip(offset);
      return Success((limit == null ? page : page.take(limit)).toList());
    });
    when(txns.getTransactions).thenAnswer((_) async => Success(ledger));
    when(
      () => txns.getRecentTransactions(limit: any(named: 'limit')),
    ).thenAnswer((_) async => Success(ledger.take(5).toList()));
    when(
      () => txns.searchTransactions(any(), type: any(named: 'type')),
    ).thenAnswer((inv) async {
      final q = (inv.positionalArguments.first as String).toLowerCase();
      final type = inv.namedArguments[#type] as TransactionType?;
      return Success(
        ledger
            .where((t) => type == null || t.type == type)
            .where(
              (t) =>
                  t.title.toLowerCase().contains(q) ||
                  (t.recipient?.toLowerCase().contains(q) ?? false),
            )
            .take(50)
            .toList(),
      );
    });
    when(() => txns.getTransactionsBetween(any(), any())).thenAnswer((
      inv,
    ) async {
      final from = inv.positionalArguments[0] as DateTime;
      final to = inv.positionalArguments[1] as DateTime;
      return Success(
        ledger
            .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
            .toList(),
      );
    });
    when(() => txns.deleteTransaction(any())).thenAnswer((inv) async {
      ledger.removeWhere((t) => t.id == inv.positionalArguments.first);
      return const Success(null);
    });
    when(() => txns.addTransactions(any())).thenAnswer((inv) async {
      final rows = inv.positionalArguments.first as List<Transaction>;
      for (final r in rows) {
        if (ledger.every((t) => t.id != r.id)) ledger.add(r);
      }
      ledger.sort((a, b) => b.date.compareTo(a.date));
      return const Success(null);
    });
    when(
      () => txns.addTransaction(any()),
    ).thenAnswer((_) async => const Success(TransactionOutcome.recorded));

    when(
      () => notes.getNotifications(limit: any(named: 'limit')),
    ).thenAnswer((_) async => Success(List.of(notifications)));
    when(
      notes.getNotifications,
    ).thenAnswer((_) async => Success(List.of(notifications)));
    when(() => notes.addNotification(any())).thenAnswer((inv) async {
      final n = inv.positionalArguments.first as NotificationItem;
      notifications
        ..removeWhere((e) => e.id == n.id)
        ..add(n)
        ..sort((a, b) => b.time.compareTo(a.time));
      return const Success(null);
    });
    when(() => notes.deleteNotification(any())).thenAnswer((inv) async {
      notifications.removeWhere((e) => e.id == inv.positionalArguments.first);
      return const Success(null);
    });
    when(() => notes.markRead(any())).thenAnswer((inv) async {
      final ids = inv.positionalArguments.first as List<String>;
      for (var i = 0; i < notifications.length; i++) {
        if (ids.contains(notifications[i].id)) {
          notifications[i] = notifications[i].copyWith(isRead: true);
        }
      }
      return const Success(null);
    });

    when(users.getCurrentUser).thenAnswer((_) async => Success(harnessUser));
    when(
      () => users.updateUser(any()),
    ).thenAnswer((_) async => const Success(null));
    when(cards.getCards).thenAnswer((_) async => const Success(fixtureCards));
  }

  final MockTransactionRepository txns = MockTransactionRepository();
  final MockNotificationRepository notes = MockNotificationRepository();
  final MockUserRepository users = MockUserRepository();
  final MockCardRepository cards = MockCardRepository();

  /// "Now" for the fixtures and the harness clock.
  final DateTime now;

  /// Mutable: deletes and undos change it.
  late final List<Transaction> ledger;
  late final List<NotificationItem> notifications;

  Future<void> init(
    ScreenHarness h, {
    required WidgetTester tester,
    bool signedIn = true,
    AppSettings initialSettings = AppSettings.defaults,
  }) => h.init(
    tester,
    signedIn: signedIn,
    initialSettings: initialSettings,
    // Day labels ("Today") and the statistics periods depend on "now".
    clock: Clock.fixed(now),
    cardRepository: cards,
    transactionRepository: txns,
    userRepository: users,
    notificationRepository: notes,
  );
}
