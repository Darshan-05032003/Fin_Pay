import 'package:sqflite/sqflite.dart';

/// Checkpoints inside a migration, reported through
/// `AppDatabase.onMigrationStep` so tests can simulate a crash at any point.
enum MigrationStep {
  usersRecreated,
  cardsRecreated,
  transactionsConverted,
  notificationsRecreated,
  indexesCreated,
}

/// Callback invoked after every [MigrationStep].
typedef MigrationStepCallback = void Function(MigrationStep step);

/// Schema DDL and versioned upgrades for the FinPay database.
///
/// Every step is written so that re-running it on a partially migrated
/// database is harmless (`IF EXISTS` / `IF NOT EXISTS`, scratch tables that
/// are dropped first). sqflite runs `onCreate`/`onUpgrade` inside one
/// exclusive transaction and only bumps `user_version` at the end, so an
/// interrupted upgrade rolls back and simply runs again on the next open.
abstract final class Migrations {
  /// Creates the current schema on a fresh database.
  static Future<void> createV2(DatabaseExecutor db) async {
    await db.execute(_usersDdl);
    await db.execute(_cardsDdl);
    await db.execute(_transactionsDdl);
    await db.execute(_notificationsDdl);
    await createIndexes(db);
  }

  /// Indexes used by date lookups, search and the idempotency guard.
  static Future<void> createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date '
      'ON transactions(date DESC)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_idempotency '
      'ON transactions(idempotencyKey)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_title '
      'ON transactions(title COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_time '
      'ON notifications(time DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cards_created ON cards(createdAt DESC)',
    );
  }

  /// Applies every upgrade between [oldVersion] and [newVersion].
  static Future<void> upgrade(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion, {
    MigrationStepCallback? onStep,
  }) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _v1ToV2(db, onStep ?? (_) {});
    }
  }

  /// v1 → v2: REAL rupees become INTEGER paise, the plaintext `password`
  /// column is dropped, card PAN/CVV columns are dropped (only the mask is
  /// kept; the PAN and CVV now live in secure storage), enum strings lose their
  /// `Enum.` prefix, and transactions gain an `idempotencyKey`. v1 dates
  /// were written as local ISO-8601 without an offset; they are kept as-is
  /// and normalised to UTC by the models when read and rewritten.
  static Future<void> _v1ToV2(
    DatabaseExecutor db,
    MigrationStepCallback onStep,
  ) async {
    // users
    await db.execute('DROP TABLE IF EXISTS users_v2');
    await db.execute(_usersDdl.replaceFirst('TABLE users', 'TABLE users_v2'));
    await db.execute('''
      INSERT INTO users_v2
        (id, fullName, email, phone, balance, profileImageUrl, createdAt)
      SELECT id, fullName, email, phone, ${_toPaise('balance')},
             profileImageUrl, createdAt
      FROM users
    ''');
    await db.execute('DROP TABLE users');
    await db.execute('ALTER TABLE users_v2 RENAME TO users');
    onStep(MigrationStep.usersRecreated);

    // cards
    await db.execute('DROP TABLE IF EXISTS cards_v2');
    await db.execute(_cardsDdl.replaceFirst('TABLE cards', 'TABLE cards_v2'));
    await db.execute('''
      INSERT INTO cards_v2
        (id, maskedNumber, cardHolderName, expireDate, cardType, balance,
         createdAt)
      SELECT id,
             '**** **** **** ' || substr(replace(cardNumber, ' ', ''), -4),
             cardHolderName, expireDate,
             ${_stripEnum('cardType', 'CardType.')},
             ${_toPaise('balance')},
             createdAt
      FROM cards
    ''');
    await db.execute('DROP TABLE cards');
    await db.execute('ALTER TABLE cards_v2 RENAME TO cards');
    onStep(MigrationStep.cardsRecreated);

    // transactions
    await db.execute('DROP TABLE IF EXISTS transactions_v2');
    await db.execute(
      _transactionsDdl.replaceFirst(
        'TABLE transactions',
        'TABLE transactions_v2',
      ),
    );
    await db.execute('''
      INSERT INTO transactions_v2
        (id, title, amount, date, type, icon, recipient, idempotencyKey,
         createdAt)
      SELECT id, title, ${_toPaise('amount')}, date,
             ${_stripEnum('type', 'TransactionType.')},
             icon, recipient, id, createdAt
      FROM transactions
    ''');
    await db.execute('DROP TABLE transactions');
    await db.execute('ALTER TABLE transactions_v2 RENAME TO transactions');
    onStep(MigrationStep.transactionsConverted);

    // notifications
    await db.execute('DROP TABLE IF EXISTS notifications_v2');
    await db.execute(
      _notificationsDdl.replaceFirst(
        'TABLE notifications',
        'TABLE notifications_v2',
      ),
    );
    await db.execute('''
      INSERT INTO notifications_v2
        (id, title, message, time, type, isRead, createdAt)
      SELECT id, title, message, time,
             ${_stripEnum('type', 'NotificationType.')}, 0,
             createdAt
      FROM notifications
    ''');
    await db.execute('DROP TABLE notifications');
    await db.execute('ALTER TABLE notifications_v2 RENAME TO notifications');
    onStep(MigrationStep.notificationsRecreated);

    await createIndexes(db);
    onStep(MigrationStep.indexesCreated);
  }

  /// `REAL` rupees → `INTEGER` paise. The tiny epsilon pushes values such as
  /// 2.675 (stored as 2.67499999…) over the half-paisa boundary the user
  /// meant, matching `Money.rupees` in Dart.
  static String _toPaise(String column) =>
      'CAST(ROUND(COALESCE($column, 0) * 100 + '
      'CASE WHEN COALESCE($column, 0) < 0 THEN -1e-6 ELSE 1e-6 END) '
      'AS INTEGER)';

  /// Strips a legacy `EnumName.` prefix from an enum column.
  static String _stripEnum(String column, String prefix) =>
      "replace($column, '$prefix', '')";

  static const String _usersDdl = '''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      fullName TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      phone TEXT,
      balance INTEGER NOT NULL DEFAULT 0,
      profileImageUrl TEXT,
      createdAt TEXT NOT NULL
    )''';

  static const String _cardsDdl = '''
    CREATE TABLE cards (
      id TEXT PRIMARY KEY,
      maskedNumber TEXT NOT NULL,
      cardHolderName TEXT NOT NULL,
      expireDate TEXT NOT NULL,
      cardType TEXT NOT NULL,
      balance INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )''';

  static const String _transactionsDdl = '''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      amount INTEGER NOT NULL,
      date TEXT NOT NULL,
      type TEXT NOT NULL,
      icon TEXT NOT NULL,
      recipient TEXT,
      idempotencyKey TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )''';

  static const String _notificationsDdl = '''
    CREATE TABLE notifications (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      time TEXT NOT NULL,
      type TEXT NOT NULL,
      isRead INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )''';
}
