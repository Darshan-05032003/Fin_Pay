import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';

/// What happened when a transaction was submitted.
enum TransactionOutcome {
  /// A new row was written and the balance adjusted.
  recorded,

  /// A row with the same `idempotencyKey` already existed; nothing changed.
  duplicate,

  /// A debit larger than the current balance; nothing changed.
  insufficientBalance,

  /// No user row exists to apply the balance change to; nothing changed.
  noUser,
}

/// Local persistence for the app's four aggregates.
///
/// Every method returns a [Result] instead of throwing. Card rows never
/// contain the PAN or CVV; those are the `ICardRepository`'s business.
abstract interface class LocalDataSource {
  // User
  Future<Result<User?>> getUser();
  Future<Result<void>> saveUser(User user);
  Future<Result<void>> updateUser(User user);
  Future<Result<void>> deleteUser();

  // Cards (masked rows only)
  Future<Result<List<PaymentCard>>> getCards();
  Future<Result<void>> saveCard(PaymentCard card);
  Future<Result<void>> deleteCard(String cardId);

  // Transactions
  Future<Result<List<Transaction>>> getTransactions({int? limit, int? offset});
  Future<Result<List<Transaction>>> searchTransactions(
    String query, {
    int limit = 50,
  });
  Future<Result<List<Transaction>>> getTransactionsBetween(
    DateTime from,
    DateTime to,
  );

  /// Sum of amounts per UTC calendar day, newest first.
  Future<Result<Map<DateTime, Money>>> getDailyTotals({int? limitDays});
  Future<Result<int>> countTransactions();

  /// Atomically inserts [transaction] (unless its `idempotencyKey` was seen
  /// before) and applies its amount to the user's balance.
  Future<Result<TransactionOutcome>> saveTransaction(Transaction transaction);

  /// Bulk insert (seed/import/stress). Does not touch the balance; rows with
  /// an existing `idempotencyKey` are skipped.
  Future<Result<void>> saveTransactions(List<Transaction> transactions);
  Future<Result<void>> deleteTransaction(String transactionId);

  // Notifications
  Future<Result<List<NotificationItem>>> getNotifications({int? limit});
  Future<Result<void>> saveNotification(NotificationItem notification);
  Future<Result<void>> deleteNotification(String notificationId);

  /// Removes every row from every table (logout / reset).
  Future<Result<void>> clearAll();
}
