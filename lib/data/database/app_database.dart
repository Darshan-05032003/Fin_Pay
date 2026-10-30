import 'package:clock/clock.dart';
import 'package:fin_pay/data/database/migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single sqflite connection and runs schema migrations.
///
/// Production code constructs it with the platform [DatabaseFactory]
/// (`databaseFactory` from sqflite); tests pass `databaseFactoryFfi` and a
/// temp path. Data access lives in `SqfliteLocalDataSource`, not here.
class AppDatabase {
  AppDatabase({
    required DatabaseFactory factory,
    required String path,
    this.clock = const Clock(),
    MigrationStepCallback? onMigrationStep,
  }) : _factory = factory,
       _path = path,
       _onMigrationStep = onMigrationStep;

  /// The current schema version. Bump it and add a case to
  /// [Migrations.upgrade] for every schema change.
  static const int schemaVersion = 2;

  /// File name of the production database inside `getDatabasesPath()`.
  static const String fileName = 'finpay.db';

  /// Resolves the production database path.
  static Future<String> defaultPath() async =>
      p.join(await getDatabasesPath(), fileName);

  final DatabaseFactory _factory;
  final String _path;
  final MigrationStepCallback? _onMigrationStep;

  /// Source of `createdAt` timestamps for rows written through this
  /// database.
  final Clock clock;

  Future<Database>? _opening;

  /// The open connection, opening (and migrating) it on first use.
  ///
  /// A failed open (for example an interrupted migration) is not cached, so
  /// the next access tries again.
  Future<Database> get database {
    final opening = _opening;
    if (opening != null) return opening;
    final attempt = _open();
    _opening = attempt;
    return attempt.then(
      (db) => db,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_opening, attempt)) _opening = null;
        return Future<Database>.error(error, stackTrace);
      },
    );
  }

  Future<Database> _open() => _factory.openDatabase(
    _path,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => Migrations.createV2(db),
      onUpgrade: (db, oldVersion, newVersion) => Migrations.upgrade(
        db,
        oldVersion,
        newVersion,
        onStep: _onMigrationStep,
      ),
    ),
  );

  /// Closes the connection if it was opened.
  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening == null) return;
    try {
      final db = await opening;
      await db.close();
    } on Object {
      // The open itself failed; nothing to close.
    }
  }
}
