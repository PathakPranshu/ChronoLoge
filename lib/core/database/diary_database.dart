import 'dart:convert';

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
    return _emptyEntry(date);
  }

  // Reads a saved entry for a date without creating a default entry.
  Future<DiaryEntryMap?> readEntry(String date) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      DiaryEntriesTable.name,
      where: '${DiaryEntriesTable.date} = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final mediaLocations = await Future.wait([
      _getImageLocations(database, date),
      _getVoiceMemoLocations(database, date),
    ]);
    return _entryFromRow(rows.single, mediaLocations[0], mediaLocations[1]);
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

  // Updates the manual title and text together, creating the entry if needed.
  Future<void> changeManualContent(
    String date, {
    required String title,
    required String textData,
  }) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await _ensureEntry(transaction, date);
      await transaction.update(
        DiaryEntriesTable.name,
        {
          DiaryEntriesTable.title: title,
          DiaryEntriesTable.textData: textData,
          DiaryEntriesTable.updatedAt: _timestamp(),
        },
        where: '${DiaryEntriesTable.date} = ?',
        whereArgs: [date],
      );
    });
  }

  // Adds one timestamped item to the automatic diary timeline.
  Future<int> addTimelineItem(
    String date, {
    required DateTime occurredAt,
    required String textData,
    required String mood,
    required List<String> imageLocations,
    required List<String> voiceMemoLocations,
    String source = 'snippet',
    String locationLabel = '',
    String weatherLabel = '',
    String eventType = 'note',
    int? placeId,
    int? visitId,
    int? tripId,
    int? weatherSnapshotId,
    double confidence = 1,
  }) async {
    final database = await _appDatabase.database;
    return database.transaction((transaction) async {
      await _ensureEntry(transaction, date);
      final id = await transaction.insert(DiaryTimelineItemsTable.name, {
        DiaryTimelineItemsTable.entryDate: date,
        DiaryTimelineItemsTable.occurredAt: occurredAt
            .toUtc()
            .toIso8601String(),
        DiaryTimelineItemsTable.textData: textData,
        DiaryTimelineItemsTable.mood: mood,
        DiaryTimelineItemsTable.imageLocations: jsonEncode(imageLocations),
        DiaryTimelineItemsTable.voiceMemoLocations: jsonEncode(
          voiceMemoLocations,
        ),
        DiaryTimelineItemsTable.source: source,
        DiaryTimelineItemsTable.locationLabel: locationLabel,
        DiaryTimelineItemsTable.weatherLabel: weatherLabel,
        DiaryTimelineItemsTable.eventType: eventType,
        DiaryTimelineItemsTable.placeId: placeId,
        DiaryTimelineItemsTable.visitId: visitId,
        DiaryTimelineItemsTable.tripId: tripId,
        DiaryTimelineItemsTable.weatherSnapshotId: weatherSnapshotId,
        DiaryTimelineItemsTable.confidence: confidence,
      });
      await _touchEntry(transaction, date);
      return id;
    });
  }

  // Replaces the editable content and media for one timeline item.
  Future<void> updateTimelineItem(
    int id, {
    required String date,
    required String textData,
    required String mood,
    required List<String> imageLocations,
    required List<String> voiceMemoLocations,
  }) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await transaction.update(
        DiaryTimelineItemsTable.name,
        {
          DiaryTimelineItemsTable.textData: textData,
          DiaryTimelineItemsTable.mood: mood,
          DiaryTimelineItemsTable.imageLocations: jsonEncode(imageLocations),
          DiaryTimelineItemsTable.voiceMemoLocations: jsonEncode(
            voiceMemoLocations,
          ),
        },
        where:
            '${DiaryTimelineItemsTable.id} = ? AND '
            '${DiaryTimelineItemsTable.entryDate} = ?',
        whereArgs: [id, date],
      );
      await _touchEntry(transaction, date);
    });
  }

  // Deletes one timeline item belonging to the requested diary date.
  Future<void> deleteTimelineItem(int id, String date) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await transaction.delete(
        DiaryTimelineItemsTable.name,
        where:
            '${DiaryTimelineItemsTable.id} = ? AND '
            '${DiaryTimelineItemsTable.entryDate} = ?',
        whereArgs: [id, date],
      );
      await _touchEntry(transaction, date);
    });
  }

  // Returns a day's automatic timeline in chronological order.
  Future<List<DiaryEntryMap>> getTimelineItems(String date) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      DiaryTimelineItemsTable.name,
      where: '${DiaryTimelineItemsTable.entryDate} = ?',
      whereArgs: [date],
      orderBy: '${DiaryTimelineItemsTable.occurredAt} ASC',
    );
    return rows
        .map(
          (row) => {
            'id': row[DiaryTimelineItemsTable.id],
            'date': row[DiaryTimelineItemsTable.entryDate],
            'occurred_at': row[DiaryTimelineItemsTable.occurredAt],
            'text_data': row[DiaryTimelineItemsTable.textData],
            'mood': row[DiaryTimelineItemsTable.mood],
            'image_locations': _decodeLocations(
              row[DiaryTimelineItemsTable.imageLocations],
            ),
            'voice_memo_locations': _decodeLocations(
              row[DiaryTimelineItemsTable.voiceMemoLocations],
            ),
            'source': row[DiaryTimelineItemsTable.source],
            'location_label': row[DiaryTimelineItemsTable.locationLabel],
            'weather_label': row[DiaryTimelineItemsTable.weatherLabel],
            'event_type': row[DiaryTimelineItemsTable.eventType],
            'place_id': row[DiaryTimelineItemsTable.placeId],
            'visit_id': row[DiaryTimelineItemsTable.visitId],
            'trip_id': row[DiaryTimelineItemsTable.tripId],
            'weather_snapshot_id':
                row[DiaryTimelineItemsTable.weatherSnapshotId],
            'confidence': row[DiaryTimelineItemsTable.confidence],
          },
        )
        .toList(growable: false);
  }

  // Writes one supported entry column inside a transaction.
  Future<void> _changeValue(String date, String column, String value) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await _ensureEntry(transaction, date);
      await transaction.update(
        DiaryEntriesTable.name,
        {column: value, DiaryEntriesTable.updatedAt: _timestamp()},
        where: '${DiaryEntriesTable.date} = ?',
        whereArgs: [date],
      );
    });
  }

  // Adds an ordered image location to the entry for a date.
  Future<void> addImage(String date, String imageLocation) async {
    return _addMedia(date, imageLocation, DiaryMediaTable.imageType);
  }

  // Removes an image location from the entry for a date.
  Future<void> deleteImage(String date, String imageLocation) async {
    return _deleteMedia(date, imageLocation, DiaryMediaTable.imageType);
  }

  // Adds an ordered voice memo location to the entry for a date.
  Future<void> addVoiceMemo(String date, String audioLocation) async {
    return _addMedia(date, audioLocation, DiaryMediaTable.voiceMemoType);
  }

  // Removes a voice memo location from the entry for a date.
  Future<void> deleteVoiceMemo(String date, String audioLocation) async {
    return _deleteMedia(date, audioLocation, DiaryMediaTable.voiceMemoType);
  }

  // Adds one ordered media location using its image or voice-memo type.
  Future<void> _addMedia(String date, String location, String mediaType) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await _ensureEntry(transaction, date);
      final result = await transaction.rawQuery(
        '''
        SELECT COALESCE(MAX(${DiaryMediaTable.sortOrder}), -1) + 1
          AS next_order
        FROM ${DiaryMediaTable.name}
        WHERE ${DiaryMediaTable.entryDate} = ?
          AND ${DiaryMediaTable.mediaType} = ?
        ''',
        [date, mediaType],
      );
      final nextOrder = result.single['next_order'] as int;
      await transaction.insert(DiaryMediaTable.name, {
        DiaryMediaTable.entryDate: date,
        DiaryMediaTable.mediaLocation: location,
        DiaryMediaTable.mediaType: mediaType,
        DiaryMediaTable.sortOrder: nextOrder,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await _touchEntry(transaction, date);
    });
  }

  // Deletes one media location of the requested type from an entry.
  Future<void> _deleteMedia(
    String date,
    String location,
    String mediaType,
  ) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final deleted = await transaction.delete(
        DiaryMediaTable.name,
        where:
            '${DiaryMediaTable.entryDate} = ? AND '
            '${DiaryMediaTable.mediaLocation} = ? AND '
            '${DiaryMediaTable.mediaType} = ?',
        whereArgs: [date, location, mediaType],
      );
      if (deleted > 0) {
        await _touchEntry(transaction, date);
      }
    });
  }

  // Returns every saved diary entry ordered from newest to oldest.
  Future<List<DiaryEntryMap>> getAllEntriesNewestFirst() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      DiaryEntriesTable.name,
      orderBy: '${DiaryEntriesTable.date} DESC',
    );
    return _attachMedia(database, rows);
  }

  // Returns every persisted image and voice-memo path for encryption migration.
  Future<List<String>> getAllMediaLocations() async {
    final database = await _appDatabase.database;
    final mediaRows = await database.query(
      DiaryMediaTable.name,
      columns: [DiaryMediaTable.mediaLocation],
    );
    final timelineRows = await database.query(
      DiaryTimelineItemsTable.name,
      columns: [
        DiaryTimelineItemsTable.imageLocations,
        DiaryTimelineItemsTable.voiceMemoLocations,
      ],
    );
    return <String>{
      ...mediaRows
          .map((row) => row[DiaryMediaTable.mediaLocation])
          .whereType<String>(),
      for (final row in timelineRows)
        ..._decodeLocations(row[DiaryTimelineItemsTable.imageLocations]),
      for (final row in timelineRows)
        ..._decodeLocations(row[DiaryTimelineItemsTable.voiceMemoLocations]),
    }.toList(growable: false);
  }

  // Searches manual and automatic diary content using a case-insensitive match.
  Future<List<DiaryEntryMap>> searchDiary(String text) async {
    final searchText = text.trim();
    if (searchText.isEmpty) return [];

    final database = await _appDatabase.database;
    final rows = await database.query(
      DiaryEntriesTable.name,
      where:
          '''
        INSTR(LOWER(${DiaryEntriesTable.date}), LOWER(?)) > 0 OR
        INSTR(LOWER(${DiaryEntriesTable.title}), LOWER(?)) > 0 OR
        INSTR(LOWER(${DiaryEntriesTable.textData}), LOWER(?)) > 0 OR
        INSTR(LOWER(${DiaryEntriesTable.mood}), LOWER(?)) > 0 OR
        EXISTS (
          SELECT 1
          FROM ${DiaryTimelineItemsTable.name} timeline
          WHERE timeline.${DiaryTimelineItemsTable.entryDate} =
                ${DiaryEntriesTable.name}.${DiaryEntriesTable.date}
            AND (
              INSTR(
                LOWER(timeline.${DiaryTimelineItemsTable.textData}), LOWER(?)
              ) > 0 OR
              INSTR(
                LOWER(timeline.${DiaryTimelineItemsTable.mood}), LOWER(?)
              ) > 0
            )
        )
      ''',
      whereArgs: List.filled(6, searchText),
      orderBy: '${DiaryEntriesTable.date} DESC',
    );
    return _attachMedia(database, rows);
  }

  // Returns one calendar item per day for the requested month.
  Future<List<DiaryEntryMap>> getMonthData(int year, int month) async {
    final firstDate = DateTime(year, month);
    final lastDate = DateTime(year, month + 1, 0);
    final firstDateKey = _dateKey(firstDate);
    final lastDateKey = _dateKey(lastDate);
    final database = await _appDatabase.database;
    final rows = await database.query(
      DiaryEntriesTable.name,
      where: '${DiaryEntriesTable.date} BETWEEN ? AND ?',
      whereArgs: [firstDateKey, lastDateKey],
    );
    final entries = await _attachMedia(database, rows);
    final entriesByDate = {
      for (final entry in entries) entry['date']! as String: entry,
    };

    return List.generate(lastDate.day, (index) {
      final date = _dateKey(DateTime(year, month, index + 1));
      return {'date': date, 'entry': entriesByDate[date]};
    });
  }

  // Deletes an entry and its related media through cascade deletion.
  Future<void> deleteEntry(String date) async {
    final database = await _appDatabase.database;
    await database.delete(
      DiaryEntriesTable.name,
      where: '${DiaryEntriesTable.date} = ?',
      whereArgs: [date],
    );
  }

  // Combines entry rows with their ordered image and voice memo locations.
  Future<List<DiaryEntryMap>> _attachMedia(
    DatabaseExecutor database,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return [];

    final dates =
        rows.map((row) => row[DiaryEntriesTable.date]! as String).toList()
          ..sort();
    final mediaRows = await database.query(
      DiaryMediaTable.name,
      where: '${DiaryMediaTable.entryDate} BETWEEN ? AND ?',
      whereArgs: [dates.first, dates.last],
      orderBy:
          '''
        ${DiaryMediaTable.entryDate} DESC,
        ${DiaryMediaTable.mediaType} ASC,
        ${DiaryMediaTable.sortOrder} ASC
      ''',
    );
    final imagesByDate = <String, List<String>>{};
    final voiceMemosByDate = <String, List<String>>{};
    for (final mediaRow in mediaRows) {
      final date = mediaRow[DiaryMediaTable.entryDate]! as String;
      final location = mediaRow[DiaryMediaTable.mediaLocation]! as String;
      final type = mediaRow[DiaryMediaTable.mediaType]! as String;
      if (type == DiaryMediaTable.imageType) {
        imagesByDate.putIfAbsent(date, () => []).add(location);
      } else if (type == DiaryMediaTable.voiceMemoType) {
        voiceMemosByDate.putIfAbsent(date, () => []).add(location);
      }
    }

    return rows
        .map((row) {
          final date = row[DiaryEntriesTable.date]! as String;
          return _entryFromRow(
            row,
            imagesByDate[date] ?? const [],
            voiceMemosByDate[date] ?? const [],
          );
        })
        .toList(growable: false);
  }

  // Loads the ordered image locations belonging to one diary entry.
  Future<List<String>> _getImageLocations(
    DatabaseExecutor database,
    String date,
  ) async {
    return _getMediaLocations(database, date, DiaryMediaTable.imageType);
  }

  // Loads the ordered voice memo locations belonging to one diary entry.
  Future<List<String>> _getVoiceMemoLocations(
    DatabaseExecutor database,
    String date,
  ) async {
    return _getMediaLocations(database, date, DiaryMediaTable.voiceMemoType);
  }

  // Loads ordered media locations of one type for a diary entry.
  Future<List<String>> _getMediaLocations(
    DatabaseExecutor database,
    String date,
    String mediaType,
  ) async {
    final rows = await database.query(
      DiaryMediaTable.name,
      columns: [DiaryMediaTable.mediaLocation],
      where:
          '${DiaryMediaTable.entryDate} = ? AND '
          '${DiaryMediaTable.mediaType} = ?',
      whereArgs: [date, mediaType],
      orderBy: '${DiaryMediaTable.sortOrder} ASC',
    );
    return rows
        .map((row) => row[DiaryMediaTable.mediaLocation]! as String)
        .toList(growable: false);
  }

  // Inserts a blank entry when the requested date does not exist.
  Future<void> _ensureEntry(DatabaseExecutor database, String date) async {
    final now = _timestamp();
    await database.insert(DiaryEntriesTable.name, {
      DiaryEntriesTable.date: date,
      DiaryEntriesTable.createdAt: now,
      DiaryEntriesTable.updatedAt: now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Refreshes the updated timestamp after an entry-related change.
  Future<void> _touchEntry(DatabaseExecutor database, String date) async {
    await database.update(
      DiaryEntriesTable.name,
      {DiaryEntriesTable.updatedAt: _timestamp()},
      where: '${DiaryEntriesTable.date} = ?',
      whereArgs: [date],
    );
  }

  // Converts a database row and its images into the public entry map.
  DiaryEntryMap _entryFromRow(
    Map<String, Object?> row,
    List<String> imageLocations,
    List<String> voiceMemoLocations,
  ) {
    return {
      'date': row[DiaryEntriesTable.date],
      'title': row[DiaryEntriesTable.title],
      'text_data': row[DiaryEntriesTable.textData],
      'images_loc': imageLocations,
      'voice_memos_loc': voiceMemoLocations,
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
      'voice_memos_loc': <String>[],
      'mood': '',
    };
  }

  // Produces a UTC ISO-8601 timestamp for database audit columns.
  String _timestamp() => DateTime.now().toUtc().toIso8601String();

  // Decodes a stored list of media paths while tolerating malformed data.
  List<String> _decodeLocations(Object? storedValue) {
    if (storedValue is! String || storedValue.isEmpty) return const [];
    try {
      final decoded = jsonDecode(storedValue);
      if (decoded is! List<dynamic>) return const [];
      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  // Formats a date as the sortable YYYY-MM-DD database key.
  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
