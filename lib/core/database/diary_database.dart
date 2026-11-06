import 'package:sqflite_sqlcipher/sqflite.dart';

import 'app_database.dart';
import 'database_constants.dart';

typedef DiaryEntryMap = Map<String, Object?>;

class DiaryDatabase {
  // Creates a diary data-access layer backed by the shared app database.
  const DiaryDatabase(this._appDatabase);

  final AppDatabase _appDatabase;

  // Returns a saved entry or an empty editable entry when one does not exist.
  Future<DiaryEntryMap?> getEntry(String date, {bool readOnly = false}) async {
    final entry = await readEntry(date);
    if (entry != null || readOnly) return entry;

    // Do not silently create an editable entry for a diary in the Recycle Bin.
    final database = await _appDatabase.database;
    final trashedRows = await database.query(
      DiaryEntriesTable.name,
      columns: [DiaryEntriesTable.deletedAt],
      where: '${DiaryEntriesTable.date} = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (trashedRows.isNotEmpty &&
        trashedRows.single[DiaryEntriesTable.deletedAt] != null) {
      throw StateError(
        'This diary is in the Recycle Bin. Restore it before editing.',
      );
    }

    return _emptyEntry(date);
  }

  // Reads an active saved entry without creating a default entry.
  Future<DiaryEntryMap?> readEntry(String date) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      DiaryEntriesTable.name,
      where:
          '${DiaryEntriesTable.date} = ? AND '
          '${DiaryEntriesTable.deletedAt} IS NULL',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final imageLocations = await _getImageLocations(database, date);
    return _entryFromRow(rows.single, imageLocations);
  }

  // Updates the diary text for a date, creating the entry when necessary.
  Future<void> changeText(String date, String textData) {
    return _changeValue(date, DiaryEntriesTable.textData, textData);
  }

  // Updates the diary title for a date, creating the entry when necessary.
  Future<void> changeTitle(String date, String title) {
    return _changeValue(date, DiaryEntriesTable.title, title);
  }

  // Updates the diary mood for a date, creating the entry when necessary.
  Future<void> changeMood(String date, String mood) {
    return _changeValue(date, DiaryEntriesTable.mood, mood);
  }

  // Writes one supported entry column inside a transaction.
  Future<void> _changeValue(String date, String column, String value) async {
    final database = await _appDatabase.database;

    await database.transaction((transaction) async {
      await _ensureEntry(transaction, date);

      await transaction.update(
        DiaryEntriesTable.name,
        {column: value, DiaryEntriesTable.updatedAt: _timestamp()},
        where:
            '${DiaryEntriesTable.date} = ? AND '
            '${DiaryEntriesTable.deletedAt} IS NULL',
        whereArgs: [date],
      );
    });
  }

  // Adds an ordered image location to an active entry.
  Future<void> addImage(String date, String imageLocation) async {
    final database = await _appDatabase.database;

    await database.transaction((transaction) async {
      await _ensureEntry(transaction, date);

      final result = await transaction.rawQuery(
        '''
        SELECT COALESCE(MAX(${DiaryImagesTable.sortOrder}), -1) + 1
          AS next_order
        FROM ${DiaryImagesTable.name}
        WHERE ${DiaryImagesTable.entryDate} = ?
      ''',
        [date],
      );

      final nextOrder = result.single['next_order'] as int;

      await transaction.insert(DiaryImagesTable.name, {
        DiaryImagesTable.entryDate: date,
        DiaryImagesTable.imageLocation: imageLocation,
        DiaryImagesTable.sortOrder: nextOrder,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await _touchEntry(transaction, date);
    });
  }

  // Removes an image location from an active entry.
  Future<void> deleteImage(String date, String imageLocation) async {
    final database = await _appDatabase.database;

    await database.transaction((transaction) async {
      final deleted = await transaction.delete(
        DiaryImagesTable.name,
        where:
            '''
          ${DiaryImagesTable.entryDate} = ? AND
          ${DiaryImagesTable.imageLocation} = ? AND
          EXISTS (
            SELECT 1 FROM ${DiaryEntriesTable.name}
            WHERE ${DiaryEntriesTable.date} = ?
            AND ${DiaryEntriesTable.deletedAt} IS NULL
          )
        ''',
        whereArgs: [date, imageLocation, date],
      );

      if (deleted > 0) {
        await _touchEntry(transaction, date);
      }
    });
  }

  // Returns active diary entries ordered from newest to oldest.
  Future<List<DiaryEntryMap>> getAllEntriesNewestFirst() async {
    final database = await _appDatabase.database;

    final rows = await database.query(
      DiaryEntriesTable.name,
      where: '${DiaryEntriesTable.deletedAt} IS NULL',
      orderBy: '${DiaryEntriesTable.date} DESC',
    );

    return _attachImages(database, rows);
  }

  // Searches active diary dates, titles, text, and moods.
  Future<List<DiaryEntryMap>> searchDiary(String text) async {
    final searchText = text.trim();
    if (searchText.isEmpty) return [];

    final database = await _appDatabase.database;

    final rows = await database.query(
      DiaryEntriesTable.name,
      where:
          '''
        ${DiaryEntriesTable.deletedAt} IS NULL AND (
          INSTR(LOWER(${DiaryEntriesTable.date}), LOWER(?)) > 0 OR
          INSTR(LOWER(${DiaryEntriesTable.title}), LOWER(?)) > 0 OR
          INSTR(LOWER(${DiaryEntriesTable.textData}), LOWER(?)) > 0 OR
          INSTR(LOWER(${DiaryEntriesTable.mood}), LOWER(?)) > 0
        )
      ''',
      whereArgs: List.filled(4, searchText),
      orderBy: '${DiaryEntriesTable.date} DESC',
    );

    return _attachImages(database, rows);
  }

  // Returns active diary entries for the requested month.
  Future<List<DiaryEntryMap>> getMonthData(int year, int month) async {
    final firstDate = DateTime(year, month);
    final lastDate = DateTime(year, month + 1, 0);

    final firstDateKey = _dateKey(firstDate);
    final lastDateKey = _dateKey(lastDate);

    final database = await _appDatabase.database;

    final rows = await database.query(
      DiaryEntriesTable.name,
      where:
          '''
        ${DiaryEntriesTable.date} BETWEEN ? AND ? AND
        ${DiaryEntriesTable.deletedAt} IS NULL
      ''',
      whereArgs: [firstDateKey, lastDateKey],
    );

    final entries = await _attachImages(database, rows);

    final entriesByDate = {
      for (final entry in entries) entry['date']! as String: entry,
    };

    return List.generate(lastDate.day, (index) {
      final date = _dateKey(DateTime(year, month, index + 1));
      return {'date': date, 'entry': entriesByDate[date]};
    });
  }

  // Moves an active diary entry to the Recycle Bin.
  // Its associated images remain preserved.
  Future<void> deleteEntry(String date) async {
    final database = await _appDatabase.database;
    final now = _timestamp();

    await database.update(
      DiaryEntriesTable.name,
      {DiaryEntriesTable.deletedAt: now, DiaryEntriesTable.updatedAt: now},
      where:
          '${DiaryEntriesTable.date} = ? AND '
          '${DiaryEntriesTable.deletedAt} IS NULL',
      whereArgs: [date],
    );
  }

  // Returns deleted diary entries, newest deletion first.
  Future<List<DiaryEntryMap>> getTrashedEntries() async {
    final database = await _appDatabase.database;

    final rows = await database.query(
      DiaryEntriesTable.name,
      where: '${DiaryEntriesTable.deletedAt} IS NOT NULL',
      orderBy: '${DiaryEntriesTable.deletedAt} DESC',
    );

    return _attachImages(database, rows);
  }

  // Restores a diary entry from the Recycle Bin.
  Future<void> restoreEntry(String date) async {
    final database = await _appDatabase.database;

    await database.update(
      DiaryEntriesTable.name,
      {
        DiaryEntriesTable.deletedAt: null,
        DiaryEntriesTable.updatedAt: _timestamp(),
      },
      where:
          '${DiaryEntriesTable.date} = ? AND '
          '${DiaryEntriesTable.deletedAt} IS NOT NULL',
      whereArgs: [date],
    );
  }

  // Permanently deletes a trashed diary and its associated images.
  Future<void> permanentlyDeleteEntry(String date) async {
    final database = await _appDatabase.database;

    await database.delete(
      DiaryEntriesTable.name,
      where:
          '${DiaryEntriesTable.date} = ? AND '
          '${DiaryEntriesTable.deletedAt} IS NOT NULL',
      whereArgs: [date],
    );
  }

  // Permanently removes trashed diary entries older than the given number
  // of days. The default retention period is 30 days.
  Future<int> permanentlyDeleteExpiredEntries({int retentionDays = 30}) async {
    if (retentionDays < 0) {
      throw ArgumentError.value(
        retentionDays,
        'retentionDays',
        'Must not be negative.',
      );
    }

    final database = await _appDatabase.database;
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(Duration(days: retentionDays))
        .toIso8601String();

    return database.delete(
      DiaryEntriesTable.name,
      where:
          '${DiaryEntriesTable.deletedAt} IS NOT NULL AND '
          '${DiaryEntriesTable.deletedAt} < ?',
      whereArgs: [cutoff],
    );
  }

  // Combines entry rows with their ordered image locations.
  Future<List<DiaryEntryMap>> _attachImages(
    DatabaseExecutor database,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return [];

    final dates =
        rows.map((row) => row[DiaryEntriesTable.date]! as String).toList()
          ..sort();

    final imageRows = await database.query(
      DiaryImagesTable.name,
      where: '${DiaryImagesTable.entryDate} BETWEEN ? AND ?',
      whereArgs: [dates.first, dates.last],
      orderBy:
          '''
        ${DiaryImagesTable.entryDate} DESC,
        ${DiaryImagesTable.sortOrder} ASC
      ''',
    );

    final imagesByDate = <String, List<String>>{};

    for (final imageRow in imageRows) {
      final date = imageRow[DiaryImagesTable.entryDate]! as String;
      final location = imageRow[DiaryImagesTable.imageLocation]! as String;

      imagesByDate.putIfAbsent(date, () => []).add(location);
    }

    return rows
        .map((row) {
          final date = row[DiaryEntriesTable.date]! as String;
          return _entryFromRow(row, imagesByDate[date] ?? const []);
        })
        .toList(growable: false);
  }

  // Loads the ordered image locations belonging to one diary entry.
  Future<List<String>> _getImageLocations(
    DatabaseExecutor database,
    String date,
  ) async {
    final rows = await database.query(
      DiaryImagesTable.name,
      columns: [DiaryImagesTable.imageLocation],
      where: '${DiaryImagesTable.entryDate} = ?',
      whereArgs: [date],
      orderBy: '${DiaryImagesTable.sortOrder} ASC',
    );

    return rows
        .map((row) => row[DiaryImagesTable.imageLocation]! as String)
        .toList(growable: false);
  }

  // Inserts a blank entry when the requested date does not exist.
  // Prevents accidental editing of an entry currently in the Recycle Bin.
  Future<void> _ensureEntry(DatabaseExecutor database, String date) async {
    final existingRows = await database.query(
      DiaryEntriesTable.name,
      columns: [DiaryEntriesTable.deletedAt],
      where: '${DiaryEntriesTable.date} = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (existingRows.isNotEmpty &&
        existingRows.single[DiaryEntriesTable.deletedAt] != null) {
      throw StateError(
        'This diary is in the Recycle Bin. Restore it before editing.',
      );
    }

    final now = _timestamp();

    await database.insert(DiaryEntriesTable.name, {
      DiaryEntriesTable.date: date,
      DiaryEntriesTable.createdAt: now,
      DiaryEntriesTable.updatedAt: now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Refreshes the updated timestamp of an active entry.
  Future<void> _touchEntry(DatabaseExecutor database, String date) async {
    await database.update(
      DiaryEntriesTable.name,
      {DiaryEntriesTable.updatedAt: _timestamp()},
      where:
          '${DiaryEntriesTable.date} = ? AND '
          '${DiaryEntriesTable.deletedAt} IS NULL',
      whereArgs: [date],
    );
  }

  // Converts a database row and its images into the public entry map.
  DiaryEntryMap _entryFromRow(
    Map<String, Object?> row,
    List<String> imageLocations,
  ) {
    return {
      'date': row[DiaryEntriesTable.date],
      'title': row[DiaryEntriesTable.title],
      'text_data': row[DiaryEntriesTable.textData],
      'images_loc': imageLocations,
      'mood': row[DiaryEntriesTable.mood],
    };
  }

  // Builds an unsaved blank entry for the requested date.
  DiaryEntryMap _emptyEntry(String date) {
    return {
      'date': date,
      'title': '',
      'text_data': '',
      'images_loc': <String>[],
      'mood': '',
    };
  }

  // Produces a UTC ISO-8601 timestamp for database audit columns.
  String _timestamp() => DateTime.now().toUtc().toIso8601String();

  // Formats a date as the sortable YYYY-MM-DD database key.
  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
