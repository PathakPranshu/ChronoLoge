import 'package:sqflite_sqlcipher/sqflite.dart';

import '../utils/display_helpers.dart';
import 'app_database.dart';
import 'database_constants.dart';

typedef DiaryEntryMap = Map<String, Object?>;

class DiaryMediaInput {
  const DiaryMediaInput({required this.location, required this.type});

  final String location;
  final String type;
}

/// Contains all SQLite queries for diary entries, timeline events, and media.
///
/// Views never run SQL directly. They call a view model, which calls this class.
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

    return _entryFromRow(rows.single, await _getEntryMedia(database, date));
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
    List<DiaryMediaInput> media = const [],
    String source = 'snippet',
    String eventType = 'note',
    int? locationSnapshotId,
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
        DiaryTimelineItemsTable.source: source,
        DiaryTimelineItemsTable.eventType: eventType,
        DiaryTimelineItemsTable.locationSnapshotId: locationSnapshotId,
        DiaryTimelineItemsTable.placeId: placeId,
        DiaryTimelineItemsTable.visitId: visitId,
        DiaryTimelineItemsTable.tripId: tripId,
        DiaryTimelineItemsTable.weatherSnapshotId: weatherSnapshotId,
        DiaryTimelineItemsTable.confidence: confidence,
      });
      await _insertMediaRows(
        transaction,
        date: date,
        timelineItemId: id,
        media: media,
      );
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
    required List<DiaryMediaInput> media,
  }) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final updated = await transaction.update(
        DiaryTimelineItemsTable.name,
        {
          DiaryTimelineItemsTable.textData: textData,
          DiaryTimelineItemsTable.mood: mood,
        },
        where:
            '${DiaryTimelineItemsTable.id} = ? AND '
            '${DiaryTimelineItemsTable.entryDate} = ?',
        whereArgs: [id, date],
      );
      if (updated == 0) {
        throw StateError('The timeline item does not exist.');
      }
      await transaction.delete(
        DiaryMediaTable.name,
        where:
            '${DiaryMediaTable.entryDate} = ? AND '
            '${DiaryMediaTable.timelineItemId} = ?',
        whereArgs: [date, id],
      );
      await _insertMediaRows(
        transaction,
        date: date,
        timelineItemId: id,
        media: media,
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
    final rows = await database.rawQuery(
      '''
      SELECT
        timeline.*,
        COALESCE(
          NULLIF(location.${LocationSnapshotsTable.locationLabel}, ''),
          NULLIF(place.${PlacesTable.nameColumn}, ''),
          ''
        ) AS location_label,
        COALESCE(weather.${WeatherSnapshotsTable.weatherLabel}, '')
          AS weather_label
      FROM ${DiaryTimelineItemsTable.name} timeline
      LEFT JOIN ${LocationSnapshotsTable.name} location
        ON location.${LocationSnapshotsTable.id} =
           timeline.${DiaryTimelineItemsTable.locationSnapshotId}
      LEFT JOIN ${PlacesTable.name} place
        ON place.${PlacesTable.id} = timeline.${DiaryTimelineItemsTable.placeId}
      LEFT JOIN ${WeatherSnapshotsTable.name} weather
        ON weather.${WeatherSnapshotsTable.id} =
           timeline.${DiaryTimelineItemsTable.weatherSnapshotId}
      WHERE timeline.${DiaryTimelineItemsTable.entryDate} = ?
      ORDER BY timeline.${DiaryTimelineItemsTable.occurredAt} ASC
      ''',
      [date],
    );
    if (rows.isEmpty) return const [];

    final timelineIds = rows
        .map((row) => row[DiaryTimelineItemsTable.id]! as int)
        .toList(growable: false);
    final placeholders = List.filled(timelineIds.length, '?').join(', ');
    final mediaRows = await database.query(
      DiaryMediaTable.name,
      where: '${DiaryMediaTable.timelineItemId} IN ($placeholders)',
      whereArgs: timelineIds,
      orderBy:
          '${DiaryMediaTable.timelineItemId} ASC, '
          '${DiaryMediaTable.mediaType} ASC, '
          '${DiaryMediaTable.sortOrder} ASC',
    );
    final mediaByTimelineId = <int, List<DiaryEntryMap>>{};
    for (final mediaRow in mediaRows) {
      final timelineItemId = mediaRow[DiaryMediaTable.timelineItemId]! as int;
      mediaByTimelineId
          .putIfAbsent(timelineItemId, () => [])
          .add(_mediaFromRow(mediaRow));
    }

    return rows
        .map((row) {
          final id = row[DiaryTimelineItemsTable.id]! as int;
          return {
            'id': row[DiaryTimelineItemsTable.id],
            'date': row[DiaryTimelineItemsTable.entryDate],
            'occurred_at': row[DiaryTimelineItemsTable.occurredAt],
            'text_data': row[DiaryTimelineItemsTable.textData],
            'mood': row[DiaryTimelineItemsTable.mood],
            'media': mediaByTimelineId[id] ?? const <DiaryEntryMap>[],
            'source': row[DiaryTimelineItemsTable.source],
            'location_label': row['location_label'],
            'weather_label': row['weather_label'],
            'event_type': row[DiaryTimelineItemsTable.eventType],
            'location_snapshot_id':
                row[DiaryTimelineItemsTable.locationSnapshotId],
            'place_id': row[DiaryTimelineItemsTable.placeId],
            'visit_id': row[DiaryTimelineItemsTable.visitId],
            'trip_id': row[DiaryTimelineItemsTable.tripId],
            'weather_snapshot_id':
                row[DiaryTimelineItemsTable.weatherSnapshotId],
            'confidence': row[DiaryTimelineItemsTable.confidence],
          };
        })
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
    return addEntryMedia(
      date,
      location: imageLocation,
      mediaType: DiaryMediaTable.imageType,
    );
  }

  // Removes an image location from the entry for a date.
  Future<void> deleteImage(String date, String imageLocation) async {
    return deleteEntryMedia(
      date,
      location: imageLocation,
      mediaType: DiaryMediaTable.imageType,
    );
  }

  // Adds an ordered voice memo location to the entry for a date.
  Future<void> addVoiceMemo(String date, String audioLocation) async {
    return addEntryMedia(
      date,
      location: audioLocation,
      mediaType: DiaryMediaTable.voiceMemoType,
    );
  }

  // Removes a voice memo location from the entry for a date.
  Future<void> deleteVoiceMemo(String date, String audioLocation) async {
    return deleteEntryMedia(
      date,
      location: audioLocation,
      mediaType: DiaryMediaTable.voiceMemoType,
    );
  }

  // Adds one ordered media file of any type to a diary summary.
  Future<void> addEntryMedia(
    String date, {
    required String location,
    required String mediaType,
  }) async {
    if (location.isEmpty || mediaType.isEmpty) {
      throw ArgumentError('Media location and type must not be empty.');
    }
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await _ensureEntry(transaction, date);
      final result = await transaction.rawQuery(
        '''
        SELECT COALESCE(MAX(${DiaryMediaTable.sortOrder}), -1) + 1
          AS next_order
        FROM ${DiaryMediaTable.name}
        WHERE ${DiaryMediaTable.entryDate} = ?
          AND ${DiaryMediaTable.timelineItemId} IS NULL
          AND ${DiaryMediaTable.mediaType} = ?
        ''',
        [date, mediaType],
      );
      final nextOrder = result.single['next_order'] as int;
      await transaction.insert(DiaryMediaTable.name, {
        DiaryMediaTable.entryDate: date,
        DiaryMediaTable.timelineItemId: null,
        DiaryMediaTable.mediaLocation: location,
        DiaryMediaTable.mediaType: mediaType,
        DiaryMediaTable.sortOrder: nextOrder,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await _touchEntry(transaction, date);
    });
  }

  // Deletes one media file of any type from a diary summary.
  Future<void> deleteEntryMedia(
    String date, {
    required String location,
    required String mediaType,
  }) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final deleted = await transaction.delete(
        DiaryMediaTable.name,
        where:
            '${DiaryMediaTable.entryDate} = ? AND '
            '${DiaryMediaTable.timelineItemId} IS NULL AND '
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

  // Returns every persisted media path for encryption migration.
  Future<List<String>> getAllMediaLocations() async {
    final database = await _appDatabase.database;
    final mediaRows = await database.query(
      DiaryMediaTable.name,
      columns: [DiaryMediaTable.mediaLocation],
    );
    return <String>{
      ...mediaRows
          .map((row) => row[DiaryMediaTable.mediaLocation])
          .whereType<String>(),
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
    final firstDateKey = formatDateKey(firstDate);
    final lastDateKey = formatDateKey(lastDate);
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
      final date = formatDateKey(DateTime(year, month, index + 1));
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
      where:
          '${DiaryMediaTable.entryDate} BETWEEN ? AND ? AND '
          '${DiaryMediaTable.timelineItemId} IS NULL',
      whereArgs: [dates.first, dates.last],
      orderBy:
          '''
        ${DiaryMediaTable.entryDate} DESC,
        ${DiaryMediaTable.mediaType} ASC,
        ${DiaryMediaTable.sortOrder} ASC
      ''',
    );
    final mediaByDate = <String, List<DiaryEntryMap>>{};
    for (final mediaRow in mediaRows) {
      final date = mediaRow[DiaryMediaTable.entryDate]! as String;
      mediaByDate.putIfAbsent(date, () => []).add(_mediaFromRow(mediaRow));
    }

    return rows
        .map((row) {
          final date = row[DiaryEntriesTable.date]! as String;
          return _entryFromRow(row, mediaByDate[date] ?? const []);
        })
        .toList(growable: false);
  }

  // Loads all ordered media belonging directly to one diary summary.
  Future<List<DiaryEntryMap>> _getEntryMedia(
    DatabaseExecutor database,
    String date,
  ) async {
    final rows = await database.query(
      DiaryMediaTable.name,
      where:
          '${DiaryMediaTable.entryDate} = ? AND '
          '${DiaryMediaTable.timelineItemId} IS NULL',
      whereArgs: [date],
      orderBy:
          '${DiaryMediaTable.mediaType} ASC, '
          '${DiaryMediaTable.sortOrder} ASC',
    );
    return rows.map(_mediaFromRow).toList(growable: false);
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

  // Inserts ordered media rows for one timeline item using extensible types.
  Future<void> _insertMediaRows(
    DatabaseExecutor database, {
    required String date,
    required int timelineItemId,
    required List<DiaryMediaInput> media,
  }) async {
    final nextOrderByType = <String, int>{};
    for (final item in media) {
      if (item.location.isEmpty || item.type.isEmpty) {
        throw ArgumentError('Media location and type must not be empty.');
      }
      final sortOrder = nextOrderByType[item.type] ?? 0;
      await database.insert(DiaryMediaTable.name, {
        DiaryMediaTable.entryDate: date,
        DiaryMediaTable.timelineItemId: timelineItemId,
        DiaryMediaTable.mediaLocation: item.location,
        DiaryMediaTable.mediaType: item.type,
        DiaryMediaTable.sortOrder: sortOrder,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      nextOrderByType[item.type] = sortOrder + 1;
    }
  }

  // Converts a database media row into its public representation.
  DiaryEntryMap _mediaFromRow(Map<String, Object?> row) {
    return {
      'id': row[DiaryMediaTable.id],
      'location': row[DiaryMediaTable.mediaLocation],
      'type': row[DiaryMediaTable.mediaType],
      'sort_order': row[DiaryMediaTable.sortOrder],
    };
  }

  // Combines a diary row with all media attached directly to its summary.
  DiaryEntryMap _entryFromRow(
    Map<String, Object?> row,
    List<DiaryEntryMap> media,
  ) {
    final imageLocations = media
        .where((item) => item['type'] == DiaryMediaTable.imageType)
        .map((item) => item['location'])
        .whereType<String>()
        .toList(growable: false);
    final voiceMemoLocations = media
        .where((item) => item['type'] == DiaryMediaTable.voiceMemoType)
        .map((item) => item['location'])
        .whereType<String>()
        .toList(growable: false);
    return {
      'date': row[DiaryEntriesTable.date],
      'title': row[DiaryEntriesTable.title],
      'text_data': row[DiaryEntriesTable.textData],
      'media': media,
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
      'media': <DiaryEntryMap>[],
      'images_loc': <String>[],
      'voice_memos_loc': <String>[],
      'mood': '',
    };
  }

  // Produces a UTC ISO-8601 timestamp for database audit columns.
  String _timestamp() => DateTime.now().toUtc().toIso8601String();
}
