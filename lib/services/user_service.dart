import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/core/di/injection_container.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';

/// Thin static facade over the repositories for the legacy screens.
///
/// Screens that still call these statics are rewritten against the BLoCs in
/// F3–F6, at which point this file is deleted. It holds no state and no
/// credentials: everything resolves through GetIt.
abstract final class UserService {
  static IUserRepository get _users => sl<IUserRepository>();
  static ITransactionRepository get _transactions =>
      sl<ITransactionRepository>();
  static ICardRepository get _cards => sl<ICardRepository>();
  static INotificationRepository get _notifications =>
      sl<INotificationRepository>();

  static T _orThrow<T>(Result<T> result) => switch (result) {
    Success(data: final d) => d,
    Failure(message: final m) => throw StateError(m),
  };

  static Future<void> saveUser(User user) async {
    _orThrow(await _users.saveUser(user));
  }

  static Future<User?> getCurrentUser() async =>
      (await _users.getCurrentUser()).dataOrNull;

  static Future<void> updateUser(User user) async {
    _orThrow(await _users.updateUser(user));
  }

  static Future<void> updateBalance(Money balance) async {
    _orThrow(await _users.updateBalance(balance));
  }

  static Future<Money> getBalance() async =>
      (await getCurrentUser())?.balance ?? Money.zero;

  static Future<List<PaymentCard>> getCards() async =>
      (await _cards.getCards()).dataOrNull ?? const [];

  static Future<void> addCard(PaymentCard card) async {
    _orThrow(await _cards.addCard(card));
  }

  static Future<List<Transaction>> getTransactions() async =>
      (await _transactions.getTransactions()).dataOrNull ?? const [];

  /// Records the transaction once (per `idempotencyKey`) and applies it to
  /// the balance.
  static Future<TransactionOutcome> addTransaction(
    Transaction transaction,
  ) async {
    final result = await sl<AddTransactionUseCase>()(transaction);
    return _orThrow<TransactionOutcome>(result);
  }

  /// Deletes every stored transaction that is not in [transactions].
  static Future<void> saveTransactions(List<Transaction> transactions) async {
    final keep = transactions.map((t) => t.id).toSet();
    for (final existing in await getTransactions()) {
      if (!keep.contains(existing.id)) {
        _orThrow(await _transactions.deleteTransaction(existing.id));
      }
    }
  }

  static Future<List<NotificationItem>> getNotifications() async =>
      (await _notifications.getNotifications()).dataOrNull ?? const [];

  static Future<void> addNotification(NotificationItem notification) async {
    _orThrow(await _notifications.addNotification(notification));
  }

  /// Deletes every stored notification that is not in [notifications].
  static Future<void> saveNotifications(
    List<NotificationItem> notifications,
  ) async {
    final keep = notifications.map((n) => n.id).toSet();
    for (final existing in await getNotifications()) {
      if (!keep.contains(existing.id)) {
        _orThrow(await _notifications.deleteNotification(existing.id));
      }
    }
  }

  /// Ends the session. The user row and data stay on the device.
  static Future<void> logout() => sl<SessionCubit>().signOut();
}
