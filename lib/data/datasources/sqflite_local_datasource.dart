import 'package:fin_pay/core/errors/app_exception.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/database/app_database.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:sqflite/sqflite.dart' as sql;

/// [LocalDataSource] backed by sqflite through [AppDatabase].
class SqfliteLocalDataSource implements LocalDataSource {
  SqfliteLocalDataSource(this._db);

  final AppDatabase _db;

  String _now() => _db.clock.now().toUtc().toIso8601String();

  Future<Result<T>> _guard<T>(
    String what,
    Future<T> Function(sql.Database db) body,
  ) async {
    try {
      return Success(await body(await _db.database));
    } on MoneyOverflowException catch (e) {
      return Failure('Failed to $what: amount out of range', e);
    } on Exception catch (e) {
      return Failure('Failed to $what', DatabaseException('Database error', e));
    }
  }

  // ---------------------------------------------------------------- users

  @override
  Future<Result<User?>> getUser() => _guard('get user', (db) async {
    final rows = await db.query('users', limit: 1);
    return rows.isEmpty ? null : User.fromJson(rows.first);
  });

  @override
  Future<Result<void>> saveUser(User user) => _guard('save user', (db) async {
    await db.insert(
      'users',
      user.toJson(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  });

  @override
  Future<Result<void>> updateUser(User user) =>
      _guard('update user', (db) async {
        await db.update(
          'users',
          user.toJson(),
          where: 'id = ?',
          whereArgs: [user.id],
        );
      });

  @override
  Future<Result<void>> deleteUser() =>
      _guard('delete user', (db) => db.delete('users'));

  // ---------------------------------------------------------------- cards

  @override
  Future<Result<List<PaymentCard>>> getCards() => _guard('get cards', (
    db,
  ) async {
    final rows = await db.query('cards', orderBy: 'createdAt DESC, id DESC');
    return rows.map(PaymentCard.fromJson).toList();
  });

  @override
  Future<Result<void>> saveCard(PaymentCard card) =>
      _guard('save card', (db) async {
        await db.insert('cards', {
          ...card.toJson(),
          'createdAt': _now(),
        }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
      });

  @override
  Future<Result<void>> deleteCard(String cardId) => _guard(
    'delete card',
    (db) => db.delete('cards', where: 'id = ?', whereArgs: [cardId]),
  );

  // --------------------------------------------------------- transactions

  @override
  Future<Result<List<Transaction>>> getTransactions({
    int? limit,
    int? offset,
  }) => _guard('get transactions', (db) async {
    final rows = await db.query(
      'transactions',
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Transaction.fromJson).toList();
  });

  @override
  Future<Result<List<Transaction>>> searchTransactions(
    String query, {
    int limit = 50,
  }) => _guard('search transactions', (db) async {
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    final rows = await db.query(
      'transactions',
      where: r"title LIKE ? ESCAPE '\' OR recipient LIKE ? ESCAPE '\'",
      whereArgs: [pattern, pattern],
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map(Transaction.fromJson).toList();
  });

  @override
  Future<Result<List<Transaction>>> getTransactionsBetween(
    DateTime from,
    DateTime to,
  ) => _guard('get transactions by date', (db) async {
    final rows = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [from.toUtc().toIso8601String(), to.toUtc().toIso8601String()],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transaction.fromJson).toList();
  });

  @override
  Future<Result<Map<DateTime, Money>>> getDailyTotals({int? limitDays}) =>
      _guard('get daily totals', (db) async {
        // With a day limit, bound the scan by date first so the date index
        // does the work instead of grouping every row and then LIMITing.
        var where = '';
        var args = const <Object?>[];
        if (limitDays != null) {
          final newest = await db.rawQuery(
            'SELECT MAX(date) AS newest FROM transactions',
          );
          final newestDate = newest.first['newest'] as String?;
          if (newestDate == null) return const {};
          final newestDay = DateTime.parse(
            '${newestDate.substring(0, 10)}T00:00:00Z',
          );
          final from = newestDay.subtract(Duration(days: limitDays - 1));
          where = 'WHERE date >= ? ';
          args = [from.toIso8601String()];
        }
        final rows = await db.rawQuery(
          'SELECT substr(date, 1, 10) AS day, SUM(amount) AS total '
          'FROM transactions ${where}GROUP BY day ORDER BY day DESC'
          '${limitDays == null ? '' : ' LIMIT $limitDays'}',
          args,
        );
        return {
          for (final row in rows)
            DateTime.parse('${row['day']}T00:00:00Z'): Money.fromJson(
              row['total'],
            ),
        };
      });

  @override
  Future<Result<int>> countTransactions() => _guard('count transactions', (
    db,
  ) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM transactions');
    return rows.first['n']! as int;
  });

  @override
  Future<Result<TransactionOutcome>> saveTransaction(Transaction transaction) =>
      _guard('save transaction', (db) async {
        return await db.transaction((txn) async {
          final users = await txn.query('users', limit: 1);
          if (users.isEmpty) return TransactionOutcome.noUser;
          final user = User.fromJson(users.first);

          final existing = await txn.query(
            'transactions',
            columns: ['id'],
            where: 'idempotencyKey = ?',
            whereArgs: [transaction.idempotencyKey],
            limit: 1,
          );
          if (existing.isNotEmpty) return TransactionOutcome.duplicate;

          // Throws MoneyOverflowException (mapped to Failure) on overflow.
          final newBalance = user.balance + transaction.amount;
          if (newBalance.isNegative) {
            return TransactionOutcome.insufficientBalance;
          }

          await txn.insert('transactions', {
            ...transaction.toJson(),
            'createdAt': _now(),
          });
          await txn.update(
            'users',
            {'balance': newBalance.toJson()},
            where: 'id = ?',
            whereArgs: [user.id],
          );
          return TransactionOutcome.recorded;
        }, exclusive: true);
      });

  @override
  Future<Result<void>> saveTransactions(List<Transaction> transactions) =>
      _guard('save transactions', (db) async {
        final now = _now();
        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final t in transactions) {
            batch.insert('transactions', {
              ...t.toJson(),
              'createdAt': now,
            }, conflictAlgorithm: sql.ConflictAlgorithm.ignore);
          }
          await batch.commit(noResult: true);
        });
      });

  @override
  Future<Result<void>> deleteTransaction(String transactionId) => _guard(
    'delete transaction',
    (db) =>
        db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]),
  );

  // -------------------------------------------------------- notifications

  @override
  Future<Result<List<NotificationItem>>> getNotifications({int? limit}) =>
      _guard('get notifications', (db) async {
        final rows = await db.query(
          'notifications',
          orderBy: 'time DESC, id DESC',
          limit: limit,
        );
        return rows.map(NotificationItem.fromJson).toList();
      });

  @override
  Future<Result<void>> saveNotification(NotificationItem notification) =>
      _guard('save notification', (db) async {
        await db.insert('notifications', {
          ...notification.toJson(),
          'createdAt': _now(),
        }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
      });

  @override
  Future<Result<void>> deleteNotification(String notificationId) => _guard(
    'delete notification',
    (db) => db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [notificationId],
    ),
  );

  @override
  Future<Result<void>> clearAll() => _guard('clear data', (db) async {
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('notifications');
      await txn.delete('cards');
      await txn.delete('users');
    });
  });
}
