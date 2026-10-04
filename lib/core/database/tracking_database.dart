import 'package:sqflite_sqlcipher/sqflite.dart';

import 'app_database.dart';
import 'database_constants.dart';

typedef TrackingRow = Map<String, Object?>;

class TrackingDatabase {
  // Creates the tracking data-access layer backed by the shared app database.
  const TrackingDatabase(this._appDatabase);

  final AppDatabase _appDatabase;

  // Stores one raw location and activity sample for later visit detection.
  Future<int> addLocationSample({
    required DateTime recordedAt,
    required double latitude,
    required double longitude,
    required double accuracyMetres,
    required double speedMetresSecond,
    required String activity,
    required int activityConfidence,
  }) async {
    final database = await _appDatabase.database;
    return database.insert(LocationSamplesTable.name, {
      LocationSamplesTable.recordedAt: recordedAt.toUtc().toIso8601String(),
      LocationSamplesTable.latitude: latitude,
      LocationSamplesTable.longitude: longitude,
      LocationSamplesTable.accuracyMetres: accuracyMetres,
      LocationSamplesTable.speedMetresSecond: speedMetresSecond,
      LocationSamplesTable.activity: activity,
      LocationSamplesTable.activityConfidence: activityConfidence.clamp(0, 100),
    });
  }

  // Returns location samples in chronological order for a requested interval.
  Future<List<TrackingRow>> getLocationSamples({
    required DateTime from,
    required DateTime to,
  }) async {
    final database = await _appDatabase.database;
    return database.query(
      LocationSamplesTable.name,
      where:
          '${LocationSamplesTable.recordedAt} >= ? AND '
          '${LocationSamplesTable.recordedAt} <= ?',
      whereArgs: [from.toUtc().toIso8601String(), to.toUtc().toIso8601String()],
      orderBy: '${LocationSamplesTable.recordedAt} ASC',
    );
  }

  // Removes raw samples older than the configured privacy retention period.
  Future<int> deleteLocationSamplesBefore(DateTime cutoff) async {
    final database = await _appDatabase.database;
    return database.delete(
      LocationSamplesTable.name,
      where: '${LocationSamplesTable.recordedAt} < ?',
      whereArgs: [cutoff.toUtc().toIso8601String()],
    );
  }

  // Creates a recognized or candidate place and returns its identifier.
  Future<int> addPlace({
    required double latitude,
    required double longitude,
    required DateTime firstVisitedAt,
    String name = '',
    double radiusMetres = 100,
    String category = 'unknown',
    bool isUserNamed = false,
    bool isConfirmed = false,
  }) async {
    final database = await _appDatabase.database;
    final timestamp = firstVisitedAt.toUtc().toIso8601String();
    return database.insert(PlacesTable.name, {
      PlacesTable.nameColumn: name.trim(),
      PlacesTable.latitude: latitude,
      PlacesTable.longitude: longitude,
      PlacesTable.radiusMetres: radiusMetres,
      PlacesTable.category: category,
      PlacesTable.isUserNamed: isUserNamed ? 1 : 0,
      PlacesTable.firstVisitedAt: timestamp,
      PlacesTable.lastVisitedAt: timestamp,
      PlacesTable.visitCount: 0,
      PlacesTable.isConfirmed: isConfirmed ? 1 : 0,
      PlacesTable.isIgnored: 0,
    });
  }

  // Returns all places, including unconfirmed candidates used for matching.
  Future<List<TrackingRow>> getPlaces() async {
    final database = await _appDatabase.database;
    return database.query(
      PlacesTable.name,
      orderBy: '${PlacesTable.lastVisitedAt} DESC',
    );
  }

  // Returns one recognized place by identifier, or null when it is missing.
  Future<TrackingRow?> getPlace(int placeId) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      PlacesTable.name,
      where: '${PlacesTable.id} = ?',
      whereArgs: [placeId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  // Updates a place after the user names, categorizes, confirms, or ignores it.
  Future<void> updatePlace(
    int placeId, {
    String? name,
    String? category,
    double? radiusMetres,
    bool? isUserNamed,
    bool? isConfirmed,
    bool? isIgnored,
  }) async {
    final values = <String, Object?>{};
    if (name != null) values[PlacesTable.nameColumn] = name.trim();
    if (category != null) values[PlacesTable.category] = category;
    if (radiusMetres != null) {
      values[PlacesTable.radiusMetres] = radiusMetres;
    }
    if (isUserNamed != null) {
      values[PlacesTable.isUserNamed] = isUserNamed ? 1 : 0;
    }
    if (isConfirmed != null) {
      values[PlacesTable.isConfirmed] = isConfirmed ? 1 : 0;
    }
    if (isIgnored != null) {
      values[PlacesTable.isIgnored] = isIgnored ? 1 : 0;
    }
    if (values.isEmpty) return;

    final database = await _appDatabase.database;
    await database.update(
      PlacesTable.name,
      values,
      where: '${PlacesTable.id} = ?',
      whereArgs: [placeId],
    );
  }

  // Starts a visit and atomically updates the matched place's visit history.
  Future<int> addVisit({
    required DateTime arrivedAt,
    required double latitude,
    required double longitude,
    required double confidence,
    int? placeId,
    bool isFirstVisit = false,
  }) async {
    final database = await _appDatabase.database;
    return database.transaction((transaction) async {
      final timestamp = arrivedAt.toUtc().toIso8601String();
      final visitId = await transaction.insert(VisitsTable.name, {
        VisitsTable.placeId: placeId,
        VisitsTable.arrivedAt: timestamp,
        VisitsTable.latitude: latitude,
        VisitsTable.longitude: longitude,
        VisitsTable.confidence: confidence.clamp(0, 1),
        VisitsTable.isFirstVisit: isFirstVisit ? 1 : 0,
      });
      if (placeId != null) {
        await transaction.rawUpdate(
          '''
          UPDATE ${PlacesTable.name}
          SET ${PlacesTable.lastVisitedAt} = ?,
              ${PlacesTable.visitCount} = ${PlacesTable.visitCount} + 1
          WHERE ${PlacesTable.id} = ?
          ''',
          [timestamp, placeId],
        );
      }
      return visitId;
    });
  }

  // Completes an active visit with its departure time.
  Future<void> endVisit(int visitId, DateTime departedAt) async {
    final database = await _appDatabase.database;
    await database.update(
      VisitsTable.name,
      {VisitsTable.departedAt: departedAt.toUtc().toIso8601String()},
      where: '${VisitsTable.id} = ?',
      whereArgs: [visitId],
    );
  }

  // Returns the most recently started visit that has not ended yet.
  Future<TrackingRow?> getActiveVisit() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      VisitsTable.name,
      where: '${VisitsTable.departedAt} IS NULL',
      orderBy: '${VisitsTable.arrivedAt} DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  // Starts a detected trip and returns its identifier.
  Future<int> addTrip({
    required DateTime startedAt,
    int? startVisitId,
    String transportMode = 'unknown',
    double confidence = 0,
  }) async {
    final database = await _appDatabase.database;
    return database.insert(TripsTable.name, {
      TripsTable.startedAt: startedAt.toUtc().toIso8601String(),
      TripsTable.startVisitId: startVisitId,
      TripsTable.transportMode: transportMode,
      TripsTable.confidence: confidence.clamp(0, 1),
    });
  }

  // Returns the most recently started trip that has not ended yet.
  Future<TrackingRow?> getActiveTrip() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      TripsTable.name,
      where: '${TripsTable.endedAt} IS NULL',
      orderBy: '${TripsTable.startedAt} DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  // Adds a measured segment to an active trip's travelled distance.
  Future<void> addTripDistance(int tripId, double distanceMetres) async {
    if (distanceMetres <= 0) return;
    final database = await _appDatabase.database;
    await database.rawUpdate(
      '''
      UPDATE ${TripsTable.name}
      SET ${TripsTable.distanceMetres} = ${TripsTable.distanceMetres} + ?
      WHERE ${TripsTable.id} = ? AND ${TripsTable.endedAt} IS NULL
      ''',
      [distanceMetres, tripId],
    );
  }

  // Completes a trip with its destination, travel mode, and measured distance.
  Future<void> endTrip(
    int tripId, {
    required DateTime endedAt,
    required double distanceMetres,
    int? endVisitId,
    String? transportMode,
    double? confidence,
  }) async {
    final database = await _appDatabase.database;
    final values = <String, Object?>{
      TripsTable.endedAt: endedAt.toUtc().toIso8601String(),
      TripsTable.endVisitId: endVisitId,
      TripsTable.distanceMetres: distanceMetres,
    };
    if (transportMode != null) {
      values[TripsTable.transportMode] = transportMode;
    }
    if (confidence != null) {
      values[TripsTable.confidence] = confidence.clamp(0, 1);
    }
    await database.update(
      TripsTable.name,
      values,
      where: '${TripsTable.id} = ?',
      whereArgs: [tripId],
    );
  }

  // Saves an Open-Meteo snapshot in canonical units and returns its identifier.
  Future<int> addWeatherSnapshot({
    required DateTime observedAt,
    required DateTime retrievedAt,
    required double latitude,
    required double longitude,
    required double temperatureCelsius,
    required double apparentTemperatureCelsius,
    required double precipitationMm,
    required double cloudCoverPercent,
    required double windSpeedKph,
    required int weatherCode,
    bool isHistorical = false,
    String provider = 'open_meteo',
  }) async {
    final database = await _appDatabase.database;
    return database.insert(WeatherSnapshotsTable.name, {
      WeatherSnapshotsTable.observedAt: observedAt.toUtc().toIso8601String(),
      WeatherSnapshotsTable.retrievedAt: retrievedAt.toUtc().toIso8601String(),
      WeatherSnapshotsTable.latitude: latitude,
      WeatherSnapshotsTable.longitude: longitude,
      WeatherSnapshotsTable.temperatureCelsius: temperatureCelsius,
      WeatherSnapshotsTable.apparentTemperatureCelsius:
          apparentTemperatureCelsius,
      WeatherSnapshotsTable.precipitationMm: precipitationMm,
      WeatherSnapshotsTable.cloudCoverPercent: cloudCoverPercent,
      WeatherSnapshotsTable.windSpeedKph: windSpeedKph,
      WeatherSnapshotsTable.weatherCode: weatherCode,
      WeatherSnapshotsTable.provider: provider,
      WeatherSnapshotsTable.isHistorical: isHistorical ? 1 : 0,
    });
  }

  // Returns recent weather snapshots for cache and change detection.
  Future<List<TrackingRow>> getWeatherSnapshotsSince(DateTime cutoff) async {
    final database = await _appDatabase.database;
    return database.query(
      WeatherSnapshotsTable.name,
      where: '${WeatherSnapshotsTable.observedAt} >= ?',
      whereArgs: [cutoff.toUtc().toIso8601String()],
      orderBy: '${WeatherSnapshotsTable.observedAt} DESC',
    );
  }

  // Returns the newest stored weather snapshot, or null when none exists.
  Future<TrackingRow?> getLatestWeatherSnapshot() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      WeatherSnapshotsTable.name,
      orderBy: '${WeatherSnapshotsTable.retrievedAt} DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  // Queues one deduplicated memory prompt for a detected visit.
  Future<int> addMemoryPrompt({
    required int visitId,
    required DateTime createdAt,
    int? timelineItemId,
    String promptType = 'photo',
  }) async {
    final database = await _appDatabase.database;
    return database.insert(MemoryPromptsTable.name, {
      MemoryPromptsTable.visitId: visitId,
      MemoryPromptsTable.timelineItemId: timelineItemId,
      MemoryPromptsTable.promptType: promptType,
      MemoryPromptsTable.createdAt: createdAt.toUtc().toIso8601String(),
      MemoryPromptsTable.status: 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Returns prompts that are ready for the notification layer to display.
  Future<List<TrackingRow>> getPendingMemoryPrompts() async {
    final database = await _appDatabase.database;
    return database.query(
      MemoryPromptsTable.name,
      where: '${MemoryPromptsTable.status} = ?',
      whereArgs: ['pending'],
      orderBy: '${MemoryPromptsTable.createdAt} ASC',
    );
  }

  // Records whether a memory prompt was shown, accepted, dismissed, or expired.
  Future<void> updateMemoryPromptStatus(
    int promptId, {
    required String status,
    DateTime? shownAt,
    DateTime? respondedAt,
  }) async {
    final database = await _appDatabase.database;
    await database.update(
      MemoryPromptsTable.name,
      {
        MemoryPromptsTable.status: status,
        if (shownAt != null)
          MemoryPromptsTable.shownAt: shownAt.toUtc().toIso8601String(),
        if (respondedAt != null)
          MemoryPromptsTable.respondedAt: respondedAt.toUtc().toIso8601String(),
      },
      where: '${MemoryPromptsTable.id} = ?',
      whereArgs: [promptId],
    );
  }
}
