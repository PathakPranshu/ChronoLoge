import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_constants.dart';
import 'database_key_provider.dart';

class AppDatabase {
  AppDatabase({DatabaseKeyProvider? keyProvider})
    : _keyProvider = keyProvider ?? DatabaseKeyProvider();

  final DatabaseKeyProvider _keyProvider;
  Future<Database>? _databaseFuture;

  Future<Database> get database => _databaseFuture ??= _open();

  Future<Database> _open() async {
    final databasePath = await getDatabasesPath();
    final fullPath = path.join(databasePath, DatabaseConstants.name);
    final password = await _keyProvider.getOrCreateKey(
      hasExistingDatabase: await databaseExists(fullPath),
    );

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
