import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_constants.dart';
import 'database_key_provider.dart';

/// Opens the one encrypted SQLite database used by the whole app.
///
/// This file only creates tables and handles schema versions. Feature-specific
/// queries live in DiaryDatabase, TrackingDatabase, and SettingsDatabase.
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

    await _createSettingsTable(database);
    await _createTrackingCoreTables(database);
    await _createTimelineItemsTable(database);
    await _createDiaryMediaTable(database);
    await _createMemoryPromptsTable(database);
    await _seedTrackingSettings(database);
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    await _resetSchema(database);
  }

  Future<void> _resetSchema(Database database) async {
    const tables = [
      'memory_prompts',
      'diary_media',
      'diary_timeline_items',
      'location_snapshots',
      'trips',
      'visits',
      'location_samples',
      'weather_snapshots',
      'places',
      'diary_images',
      'diary_voice_memos',
      'settings',
      'diary_entries',
    ];
    for (final table in tables) {
      await database.execute('DROP TABLE IF EXISTS $table');
    }
    await _createSchema(database, DatabaseConstants.version);
  }

  Future<void> _createDiaryMediaTable(Database database) async {
    await database.execute('''
      CREATE TABLE ${DiaryMediaTable.name} (
        ${DiaryMediaTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DiaryMediaTable.entryDate} TEXT NOT NULL,
        ${DiaryMediaTable.timelineItemId} INTEGER,
        ${DiaryMediaTable.mediaLocation} TEXT NOT NULL,
        ${DiaryMediaTable.mediaType} TEXT NOT NULL,
        ${DiaryMediaTable.sortOrder} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${DiaryMediaTable.entryDate})
          REFERENCES ${DiaryEntriesTable.name} (${DiaryEntriesTable.date})
          ON DELETE CASCADE,
        FOREIGN KEY (
          ${DiaryMediaTable.timelineItemId},
          ${DiaryMediaTable.entryDate}
        ) REFERENCES ${DiaryTimelineItemsTable.name} (
          ${DiaryTimelineItemsTable.id},
          ${DiaryTimelineItemsTable.entryDate}
        )
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX diary_media_owner_type_order_idx
      ON ${DiaryMediaTable.name} (
        ${DiaryMediaTable.entryDate},
        ${DiaryMediaTable.timelineItemId},
        ${DiaryMediaTable.mediaType},
        ${DiaryMediaTable.sortOrder}
      )
    ''');

    await database.execute('''
      CREATE UNIQUE INDEX diary_media_entry_location_type_idx
      ON ${DiaryMediaTable.name} (
        ${DiaryMediaTable.entryDate},
        ${DiaryMediaTable.mediaLocation},
        ${DiaryMediaTable.mediaType}
      )
      WHERE ${DiaryMediaTable.timelineItemId} IS NULL
    ''');

    await database.execute('''
      CREATE UNIQUE INDEX diary_media_timeline_location_type_idx
      ON ${DiaryMediaTable.name} (
        ${DiaryMediaTable.timelineItemId},
        ${DiaryMediaTable.mediaLocation},
        ${DiaryMediaTable.mediaType}
      )
      WHERE ${DiaryMediaTable.timelineItemId} IS NOT NULL
    ''');
  }

  Future<void> _createTimelineItemsTable(Database database) async {
    await database.execute('''
      CREATE TABLE ${DiaryTimelineItemsTable.name} (
        ${DiaryTimelineItemsTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DiaryTimelineItemsTable.entryDate} TEXT NOT NULL,
        ${DiaryTimelineItemsTable.occurredAt} TEXT NOT NULL,
        ${DiaryTimelineItemsTable.textData} TEXT NOT NULL DEFAULT '',
        ${DiaryTimelineItemsTable.mood} TEXT NOT NULL DEFAULT '',
        ${DiaryTimelineItemsTable.source} TEXT NOT NULL DEFAULT 'snippet',
        ${DiaryTimelineItemsTable.eventType} TEXT NOT NULL DEFAULT 'note',
        ${DiaryTimelineItemsTable.locationSnapshotId} INTEGER,
        ${DiaryTimelineItemsTable.placeId} INTEGER,
        ${DiaryTimelineItemsTable.visitId} INTEGER,
        ${DiaryTimelineItemsTable.tripId} INTEGER,
        ${DiaryTimelineItemsTable.weatherSnapshotId} INTEGER,
        ${DiaryTimelineItemsTable.confidence} REAL NOT NULL DEFAULT 1.0,
        FOREIGN KEY (${DiaryTimelineItemsTable.entryDate})
          REFERENCES ${DiaryEntriesTable.name} (${DiaryEntriesTable.date})
          ON DELETE CASCADE,
        FOREIGN KEY (${DiaryTimelineItemsTable.locationSnapshotId})
          REFERENCES ${LocationSnapshotsTable.name} (${LocationSnapshotsTable.id})
          ON DELETE SET NULL,
        FOREIGN KEY (${DiaryTimelineItemsTable.placeId})
          REFERENCES ${PlacesTable.name} (${PlacesTable.id})
          ON DELETE SET NULL,
        FOREIGN KEY (${DiaryTimelineItemsTable.visitId})
          REFERENCES ${VisitsTable.name} (${VisitsTable.id})
          ON DELETE SET NULL,
        FOREIGN KEY (${DiaryTimelineItemsTable.tripId})
          REFERENCES ${TripsTable.name} (${TripsTable.id})
          ON DELETE SET NULL,
        FOREIGN KEY (${DiaryTimelineItemsTable.weatherSnapshotId})
          REFERENCES ${WeatherSnapshotsTable.name} (${WeatherSnapshotsTable.id})
          ON DELETE SET NULL,
        UNIQUE (
          ${DiaryTimelineItemsTable.id},
          ${DiaryTimelineItemsTable.entryDate}
        )
      )
    ''');

    await database.execute('''
      CREATE INDEX diary_timeline_items_date_time_idx
      ON ${DiaryTimelineItemsTable.name} (
        ${DiaryTimelineItemsTable.entryDate},
        ${DiaryTimelineItemsTable.occurredAt}
      )
    ''');
  }

  Future<void> _createTrackingCoreTables(Database database) async {
    await database.execute('''
      CREATE TABLE ${LocationSamplesTable.name} (
        ${LocationSamplesTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${LocationSamplesTable.recordedAt} TEXT NOT NULL,
        ${LocationSamplesTable.latitude} REAL NOT NULL,
        ${LocationSamplesTable.longitude} REAL NOT NULL,
        ${LocationSamplesTable.accuracyMetres} REAL NOT NULL,
        ${LocationSamplesTable.speedMetresSecond} REAL NOT NULL DEFAULT 0,
        ${LocationSamplesTable.activity} TEXT NOT NULL DEFAULT 'unknown',
        ${LocationSamplesTable.activityConfidence} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE INDEX location_samples_recorded_at_idx
      ON ${LocationSamplesTable.name} (${LocationSamplesTable.recordedAt})
    ''');

    await database.execute('''
      CREATE TABLE ${LocationSnapshotsTable.name} (
        ${LocationSnapshotsTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${LocationSnapshotsTable.recordedAt} TEXT NOT NULL,
        ${LocationSnapshotsTable.latitude} REAL NOT NULL,
        ${LocationSnapshotsTable.longitude} REAL NOT NULL,
        ${LocationSnapshotsTable.locationLabel} TEXT NOT NULL DEFAULT ''
      )
    ''');

    await database.execute('''
      CREATE INDEX location_snapshots_recorded_at_idx
      ON ${LocationSnapshotsTable.name} (${LocationSnapshotsTable.recordedAt})
    ''');

    await database.execute('''
      CREATE TABLE ${PlacesTable.name} (
        ${PlacesTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${PlacesTable.nameColumn} TEXT NOT NULL DEFAULT '',
        ${PlacesTable.latitude} REAL NOT NULL,
        ${PlacesTable.longitude} REAL NOT NULL,
        ${PlacesTable.radiusMetres} REAL NOT NULL DEFAULT 100,
        ${PlacesTable.category} TEXT NOT NULL DEFAULT 'unknown',
        ${PlacesTable.isUserNamed} INTEGER NOT NULL DEFAULT 0,
        ${PlacesTable.firstVisitedAt} TEXT NOT NULL,
        ${PlacesTable.lastVisitedAt} TEXT NOT NULL,
        ${PlacesTable.visitCount} INTEGER NOT NULL DEFAULT 0,
        ${PlacesTable.isConfirmed} INTEGER NOT NULL DEFAULT 0,
        ${PlacesTable.isIgnored} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE INDEX places_location_idx
      ON ${PlacesTable.name} (
        ${PlacesTable.latitude},
        ${PlacesTable.longitude}
      )
    ''');

    await database.execute('''
      CREATE TABLE ${VisitsTable.name} (
        ${VisitsTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${VisitsTable.placeId} INTEGER,
        ${VisitsTable.arrivedAt} TEXT NOT NULL,
        ${VisitsTable.departedAt} TEXT,
        ${VisitsTable.latitude} REAL NOT NULL,
        ${VisitsTable.longitude} REAL NOT NULL,
        ${VisitsTable.confidence} REAL NOT NULL DEFAULT 0,
        ${VisitsTable.isFirstVisit} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${VisitsTable.placeId})
          REFERENCES ${PlacesTable.name} (${PlacesTable.id})
          ON DELETE SET NULL
      )
    ''');

    await database.execute('''
      CREATE INDEX visits_arrived_at_idx
      ON ${VisitsTable.name} (${VisitsTable.arrivedAt})
    ''');

    await database.execute('''
      CREATE TABLE ${TripsTable.name} (
        ${TripsTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${TripsTable.startedAt} TEXT NOT NULL,
        ${TripsTable.endedAt} TEXT,
        ${TripsTable.startVisitId} INTEGER,
        ${TripsTable.endVisitId} INTEGER,
        ${TripsTable.transportMode} TEXT NOT NULL DEFAULT 'unknown',
        ${TripsTable.distanceMetres} REAL NOT NULL DEFAULT 0,
        ${TripsTable.confidence} REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (${TripsTable.startVisitId})
          REFERENCES ${VisitsTable.name} (${VisitsTable.id})
          ON DELETE SET NULL,
        FOREIGN KEY (${TripsTable.endVisitId})
          REFERENCES ${VisitsTable.name} (${VisitsTable.id})
          ON DELETE SET NULL
      )
    ''');

    await database.execute('''
      CREATE INDEX trips_started_at_idx
      ON ${TripsTable.name} (${TripsTable.startedAt})
    ''');

    await database.execute('''
      CREATE TABLE ${WeatherSnapshotsTable.name} (
        ${WeatherSnapshotsTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${WeatherSnapshotsTable.observedAt} TEXT NOT NULL,
        ${WeatherSnapshotsTable.retrievedAt} TEXT NOT NULL,
        ${WeatherSnapshotsTable.latitude} REAL NOT NULL,
        ${WeatherSnapshotsTable.longitude} REAL NOT NULL,
        ${WeatherSnapshotsTable.temperatureCelsius} REAL NOT NULL,
        ${WeatherSnapshotsTable.apparentTemperatureCelsius} REAL NOT NULL,
        ${WeatherSnapshotsTable.precipitationMm} REAL NOT NULL DEFAULT 0,
        ${WeatherSnapshotsTable.cloudCoverPercent} REAL NOT NULL DEFAULT 0,
        ${WeatherSnapshotsTable.windSpeedKph} REAL NOT NULL DEFAULT 0,
        ${WeatherSnapshotsTable.weatherCode} INTEGER NOT NULL,
        ${WeatherSnapshotsTable.weatherLabel} TEXT NOT NULL DEFAULT '',
        ${WeatherSnapshotsTable.provider} TEXT NOT NULL DEFAULT 'open_meteo',
        ${WeatherSnapshotsTable.isHistorical} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE INDEX weather_snapshots_time_location_idx
      ON ${WeatherSnapshotsTable.name} (
        ${WeatherSnapshotsTable.observedAt},
        ${WeatherSnapshotsTable.latitude},
        ${WeatherSnapshotsTable.longitude}
      )
    ''');
  }

  Future<void> _createMemoryPromptsTable(Database database) async {
    await database.execute('''
      CREATE TABLE ${MemoryPromptsTable.name} (
        ${MemoryPromptsTable.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${MemoryPromptsTable.visitId} INTEGER NOT NULL,
        ${MemoryPromptsTable.timelineItemId} INTEGER,
        ${MemoryPromptsTable.promptType} TEXT NOT NULL DEFAULT 'photo',
        ${MemoryPromptsTable.createdAt} TEXT NOT NULL,
        ${MemoryPromptsTable.shownAt} TEXT,
        ${MemoryPromptsTable.respondedAt} TEXT,
        ${MemoryPromptsTable.status} TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (${MemoryPromptsTable.visitId})
          REFERENCES ${VisitsTable.name} (${VisitsTable.id})
          ON DELETE CASCADE,
        FOREIGN KEY (${MemoryPromptsTable.timelineItemId})
          REFERENCES ${DiaryTimelineItemsTable.name} (${DiaryTimelineItemsTable.id})
          ON DELETE SET NULL,
        UNIQUE (
          ${MemoryPromptsTable.visitId},
          ${MemoryPromptsTable.promptType}
        )
      )
    ''');

    await database.execute('''
      CREATE INDEX memory_prompts_status_idx
      ON ${MemoryPromptsTable.name} (${MemoryPromptsTable.status})
    ''');
  }

  Future<void> _seedTrackingSettings(Database database) async {
    const values = {
      'automatic_tracking_enabled': 'true',
      'location_retention_days': '14',
      'weather_refresh_minutes': '60',
    };
    for (final entry in values.entries) {
      await database.insert(SettingsTable.name, {
        SettingsTable.setting: entry.key,
        SettingsTable.value: entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
