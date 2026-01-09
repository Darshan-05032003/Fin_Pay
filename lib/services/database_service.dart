import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/transaction.dart' as models;
import '../models/card.dart' as card_models;
import '../models/notification_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static sqflite.Database? _database;

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sqflite.Database> _initDatabase() async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, 'finpay.db');

    return await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(sqflite.Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        fullName TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT,
        password TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        profileImageUrl TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Cards table
    await db.execute('''
      CREATE TABLE cards (
        id TEXT PRIMARY KEY,
        cardNumber TEXT NOT NULL,
        maskedNumber TEXT NOT NULL,
        cardHolderName TEXT NOT NULL,
        expireDate TEXT NOT NULL,
        cvv TEXT NOT NULL,
        cardType TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        createdAt TEXT NOT NULL
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        recipient TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        time TEXT NOT NULL,
        type TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_notifications_time ON notifications(time)');
  }

  Future<void> _onUpgrade(sqflite.Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here if needed
  }

  // User operations
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toJson(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<User?> getUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', limit: 1);
    if (maps.isEmpty) return null;
    return User.fromJson(maps.first);
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update(
      'users',
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> deleteUser() async {
    final db = await database;
    await db.delete('users');
  }

  // Card operations
  Future<void> insertCard(card_models.Card card) async {
    final db = await database;
    await db.insert(
      'cards',
      {
        'id': card.id,
        'cardNumber': card.cardNumber,
        'maskedNumber': card.maskedNumber ?? card.cardNumber,
        'cardHolderName': card.cardHolderName,
        'expireDate': card.expireDate,
        'cvv': card.cvv,
        'cardType': card.cardType.toString(),
        'balance': card.balance,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<List<card_models.Card>> getCards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cards',
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) {
      return card_models.Card(
        id: map['id'],
        cardNumber: map['cardNumber'],
        cardHolderName: map['cardHolderName'],
        expireDate: map['expireDate'],
        cvv: map['cvv'],
        cardType: card_models.CardType.values.firstWhere(
          (e) => e.toString() == map['cardType'],
          orElse: () => card_models.CardType.visa,
        ),
        balance: (map['balance'] ?? 0.0).toDouble(),
      );
    }).toList();
  }

  Future<void> deleteCard(String cardId) async {
    final db = await database;
    await db.delete('cards', where: 'id = ?', whereArgs: [cardId]);
  }

  // Transaction operations
  Future<void> insertTransaction(models.Transaction transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      {
        'id': transaction.id,
        'title': transaction.title,
        'amount': transaction.amount,
        'date': transaction.date.toIso8601String(),
        'type': transaction.type.toString(),
        'icon': transaction.icon,
        'recipient': transaction.recipient,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<List<models.Transaction>> getTransactions({int? limit, String? orderBy}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: orderBy ?? 'date DESC',
      limit: limit,
    );
    return maps.map((map) {
      return models.Transaction(
        id: map['id'],
        title: map['title'],
        amount: (map['amount'] ?? 0.0).toDouble(),
        date: DateTime.parse(map['date']),
        type: models.TransactionType.values.firstWhere(
          (e) => e.toString() == map['type'],
          orElse: () => models.TransactionType.payment,
        ),
        icon: map['icon'],
        recipient: map['recipient'],
      );
    }).toList();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
  }

  // Notification operations
  Future<void> insertNotification(NotificationItem notification) async {
    final db = await database;
    await db.insert(
      'notifications',
      {
        'id': notification.id,
        'title': notification.title,
        'message': notification.message,
        'time': notification.time.toIso8601String(),
        'type': notification.type.toString(),
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<List<NotificationItem>> getNotifications({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      orderBy: 'time DESC',
      limit: limit,
    );
    return maps.map((map) {
      return NotificationItem(
        id: map['id'],
        title: map['title'],
        message: map['message'],
        time: DateTime.parse(map['time']),
        type: NotificationType.values.firstWhere(
          (e) => e.toString() == map['type'],
          orElse: () => NotificationType.cashback,
        ),
      );
    }).toList();
  }

  Future<void> deleteNotification(String notificationId) async {
    final db = await database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [notificationId]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('cards');
    await db.delete('transactions');
    await db.delete('notifications');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

