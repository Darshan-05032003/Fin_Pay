import 'package:fin_pay/core/errors/app_exception.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/models/card.dart' as card_models;
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/transaction.dart' as models;
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/services/database_service.dart';

/// Concrete implementation of LocalDataSource using SQLite
class LocalDataSourceImpl implements LocalDataSource {

  LocalDataSourceImpl(this._db);
  final DatabaseService _db;

  @override
  Future<Result<User?>> getUser() async {
    try {
      final user = await _db.getUser();
      return Success(user);
    } catch (e) {
      return Failure('Failed to get user', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> saveUser(User user) async {
    try {
      await _db.insertUser(user);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save user', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> updateUser(User user) async {
    try {
      await _db.updateUser(user);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update user', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> deleteUser() async {
    try {
      await _db.deleteUser();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete user', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<List<card_models.Card>>> getCards() async {
    try {
      final cards = await _db.getCards();
      return Success(cards);
    } catch (e) {
      return Failure('Failed to get cards', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> saveCard(card_models.Card card) async {
    try {
      await _db.insertCard(card);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save card', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> deleteCard(String cardId) async {
    try {
      // Implement delete card in DatabaseService if needed
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete card', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<List<models.Transaction>>> getTransactions({int? limit}) async {
    try {
      final transactions = await _db.getTransactions();
      final limited = limit != null ? transactions.take(limit).toList() : transactions;
      return Success(limited);
    } catch (e) {
      return Failure('Failed to get transactions', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> saveTransaction(models.Transaction transaction) async {
    try {
      await _db.insertTransaction(transaction);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save transaction', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> deleteTransaction(String transactionId) async {
    try {
      await _db.deleteTransaction(transactionId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete transaction', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<List<NotificationItem>>> getNotifications({int? limit}) async {
    try {
      final notifications = await _db.getNotifications();
      final limited = limit != null ? notifications.take(limit).toList() : notifications;
      return Success(limited);
    } catch (e) {
      return Failure('Failed to get notifications', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> saveNotification(NotificationItem notification) async {
    try {
      await _db.insertNotification(notification);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save notification', DatabaseException('Database error', e));
    }
  }

  @override
  Future<Result<void>> deleteNotification(String notificationId) async {
    try {
      await _db.deleteNotification(notificationId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete notification', DatabaseException('Database error', e));
    }
  }
}

