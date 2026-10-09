import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_constants.dart';
import 'database_key_provider.dart';

class AppDatabase {
  AppDatabase({required this.firebaseUid, DatabaseKeyProvider? keyProvider})
    : _keyProvider = keyProvider ?? DatabaseKeyProvider(firebaseUid);

  final String firebaseUid;
  final DatabaseKeyProvider _keyProvider;
  Future<Database>? _databaseFuture;

  Future<Database> get database => _databaseFuture ??= _open();

  Future<String> get filePath async {
    final databasePath = await getDatabasesPath();
    return path.join(databasePath, DatabaseConstants.nameForUser(firebaseUid));
  }

  Future<Database> _open() async {
    final fullPath = await filePath;
    final password = await _keyProvider.getKey();
    final hasExistingDatabase = await databaseExists(fullPath);

    try {
      return await _openWithPassword(fullPath, password);
    } on DatabaseException catch (error) {
      final isWrongKeyError = error.toString().contains('open_failed');
      if (!hasExistingDatabase || !isWrongKeyError) rethrow;

      // One-time migration for databases created by the earlier UID-key demo.
      // The new random key is Base64URL, so it cannot contain a quote.
      Database? legacyDatabase;
      try {
        legacyDatabase = await _openWithPassword(fullPath, firebaseUid);
        await legacyDatabase.execute("PRAGMA rekey = '$password'");
        await legacyDatabase.close();
        legacyDatabase = null;
        return await _openWithPassword(fullPath, password);
      } catch (_) {
        await legacyDatabase?.close();
        rethrow;
      }
    }
  }

  Future<Database> _openWithPassword(String fullPath, String password) {
    return openDatabase(
      fullPath,
      password: password,
      version: DatabaseConstants.version,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE ${DiaryEntriesTable.name} (
        ${DiaryEntriesTable.date} TEXT PRIMARY KEY,
        ${DiaryEntriesTable.title} TEXT NOT NULL DEFAULT '',
        ${DiaryEntriesTable.textData} TEXT NOT NULL DEFAULT '',
        ${DiaryEntriesTable.mood} TEXT NOT NULL DEFAULT '',
        ${DiaryEntriesTable.createdAt} TEXT NOT NULL,
        ${DiaryEntriesTable.updatedAt} TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE ${DiaryImagesTable.name} (
        ${DiaryImagesTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DiaryImagesTable.entryDate} TEXT NOT NULL,
        ${DiaryImagesTable.imageLocation} TEXT NOT NULL,
        ${DiaryImagesTable.sortOrder} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${DiaryImagesTable.entryDate})
          REFERENCES ${DiaryEntriesTable.name} (${DiaryEntriesTable.date})
          ON DELETE CASCADE,
        UNIQUE (
          ${DiaryImagesTable.entryDate},
          ${DiaryImagesTable.imageLocation}
        )
      )
    ''');

    await database.execute('''
      CREATE INDEX diary_images_entry_date_idx
      ON ${DiaryImagesTable.name} (${DiaryImagesTable.entryDate})
    ''');

    await _createSettingsTable(database);
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createSettingsTable(database);
    }
  }

  Future<void> _createSettingsTable(Database database) async {
    await database.execute('''
      CREATE TABLE ${SettingsTable.name} (
        ${SettingsTable.setting} TEXT PRIMARY KEY,
        ${SettingsTable.value} TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final databaseFuture = _databaseFuture;
    _databaseFuture = null;
    if (databaseFuture != null) {
      await (await databaseFuture).close();
    }
  }
}
