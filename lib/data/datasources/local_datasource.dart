import '../../models/user.dart';
import '../../models/transaction.dart' as models;
import '../../models/card.dart' as card_models;
import '../../models/notification_item.dart';
import '../../core/result/result.dart';
import '../../core/errors/app_exception.dart';

/// Abstract interface for local data source
abstract class LocalDataSource {
  // User operations
  Future<Result<User?>> getUser();
  Future<Result<void>> saveUser(User user);
  Future<Result<void>> updateUser(User user);
  Future<Result<void>> deleteUser();
  
  // Card operations
  Future<Result<List<card_models.Card>>> getCards();
  Future<Result<void>> saveCard(card_models.Card card);
  Future<Result<void>> deleteCard(String cardId);
  
  // Transaction operations
  Future<Result<List<models.Transaction>>> getTransactions({int? limit});
  Future<Result<void>> saveTransaction(models.Transaction transaction);
  Future<Result<void>> deleteTransaction(String transactionId);
  
  // Notification operations
  Future<Result<List<NotificationItem>>> getNotifications({int? limit});
  Future<Result<void>> saveNotification(NotificationItem notification);
  Future<Result<void>> deleteNotification(String notificationId);
}

