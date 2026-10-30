import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A transaction row in the exact shape the v1 app wrote (REAL rupees,
/// `TransactionType.x` enum strings).
Map<String, Object?> v1Transaction(
  String id,
  double rupees, {
  String type = 'TransactionType.payment',
  String date = '2026-10-30T10:00:00.000',
}) => {
  'id': id,
  'title': 'Row $id',
  'amount': rupees,
  'date': date,
  'type': type,
  'icon': 'R',
  'recipient': null,
  'createdAt': date,
};

/// The four sample rows used by the migration tests.
final List<Map<String, Object?>> defaultV1Transactions = [
  v1Transaction('t1', -420.90, type: 'TransactionType.sendMoney'),
  v1Transaction('t2', 1000.05, type: 'TransactionType.receiveMoney'),
  v1Transaction('t3', 0.01),
  v1Transaction('t4', -12345678.91, type: 'TransactionType.topUp'),
];

/// Creates a database at [path] with the verbatim v1 schema (as shipped in
/// `DatabaseService` before F1) and sample rows, then closes it.
Future<void> createV1Database(
  DatabaseFactory factory,
  String path, {
  List<Map<String, Object?>>? transactions,
  double? userBalance = 56246.90,
  bool insertUser = true,
}) async {
  final db = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
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
        await db.execute(
          'CREATE INDEX idx_transactions_date ON transactions(date)',
        );
        await db.execute(
          'CREATE INDEX idx_notifications_time ON notifications(time)',
        );
      },
    ),
  );

  if (insertUser) {
    await db.insert('users', {
      'id': 'default_user_001',
      'fullName': 'John Doe',
      'email': 'user@finpay.com',
      'phone': null,
      'password': 'plaintext-from-v1',
      'balance': userBalance,
      'profileImageUrl': null,
      'createdAt': '2026-01-01T00:00:00.000',
    });
  }
  await db.insert('cards', {
    'id': 'card_1',
    'cardNumber': '4111 1111 1111 1234',
    'maskedNumber': '4111 **** **** 1234',
    'cardHolderName': 'John Doe',
    'expireDate': '12/28',
    'cvv': '123',
    'cardType': 'CardType.visa',
    'balance': 10000.0,
    'createdAt': '2026-01-02T00:00:00.000',
  });
  final batch = db.batch();
  for (final row in transactions ?? defaultV1Transactions) {
    batch.insert('transactions', row);
  }
  await batch.commit(noResult: true);
  await db.insert('notifications', {
    'id': 'n1',
    'title': 'Cashback',
    'message': 'You earned 10',
    'time': '2026-10-30T10:00:00.000',
    'type': 'NotificationType.cashback',
    'createdAt': '2026-10-30T10:00:00.000',
  });
  await db.close();
}
