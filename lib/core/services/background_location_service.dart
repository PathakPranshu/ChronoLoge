import 'dart:async';
import 'dart:io';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../database/database_constants.dart';
import '../database/diary_database.dart';
import '../database/settings_database.dart';
import '../database/tracking_database.dart';
import '../utils/display_helpers.dart';
import '../notifications/notification_service.dart';
import 'diagnostic_log_service.dart';
import 'open_meteo_weather_service.dart';

enum BackgroundTrackingStatus {
  disabled,
  starting,
  active,
  unsupported,
  locationServicesDisabled,
  permissionDenied,
  backgroundPermissionNeeded,
  permissionDeniedForever,
  error,
}

extension BackgroundTrackingStatusLabel on BackgroundTrackingStatus {
  String get label => switch (this) {
    BackgroundTrackingStatus.disabled => 'Automatic tracking is off',
    BackgroundTrackingStatus.starting => 'Starting location tracking…',
    BackgroundTrackingStatus.active => 'Tracking location in the background',
    BackgroundTrackingStatus.unsupported =>
      'Background tracking is unavailable on this device',
    BackgroundTrackingStatus.locationServicesDisabled =>
      'Turn on device location services',
    BackgroundTrackingStatus.permissionDenied =>
      'Location permission is required',
    BackgroundTrackingStatus.backgroundPermissionNeeded =>
      'Choose Allow all the time for background tracking',
    BackgroundTrackingStatus.permissionDeniedForever =>
      'Allow location access in system settings',
    BackgroundTrackingStatus.error => 'Location tracking needs attention',
  };
}

/// Turns a stream of raw phone locations into useful diary events.
///
/// The main steps are: save a point, detect a stay, create a visit or trip,
/// check weather, and finally add an automatic timeline item.
class BackgroundLocationService {
  BackgroundLocationService(
    this._trackingDatabase,
    this._diaryDatabase,
    this._settingsDatabase, [
    this._weatherService = const OpenMeteoWeatherService(),
    NotificationService? notificationService,
  ]) : _notificationService =
           notificationService ?? NotificationService.instance;

  static const _stayRadiusMetres = 120.0;
  static const _departureRadiusMetres = 220.0;
  static const _maximumUsefulAccuracyMetres = 180.0;
  static const _minimumStayDuration = Duration(minutes: 5);
  static const _defaultWeatherRefresh = Duration(hours: 1);
  static const _weatherRetryDelay = Duration(minutes: 10);
  static const _weatherLocationChangeMetres = 1000.0;
  static const _defaultRetentionDays = 14;
  static const _dailyBaselineEvent = 'day_baseline';

  final TrackingDatabase _trackingDatabase;
  final DiaryDatabase _diaryDatabase;
  final SettingsDatabase _settingsDatabase;
  final OpenMeteoWeatherService _weatherService;
  final NotificationService _notificationService;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  Timer? _candidateTimer;
  Timer? _weatherTimer;
  Future<void> _processing = Future.value();
  TrackingRow? _activeVisit;
  TrackingRow? _activeTrip;
  TrackingRow? _lastWeather;
  _LocationPoint? _lastPoint;
  _StayCandidate? _candidate;
  int _outsideVisitSamples = 0;
  DateTime? _lastCleanupAt;
  DateTime? _lastWeatherFailureAt;
  Duration _weatherRefresh = _defaultWeatherRefresh;
  int _retentionDays = _defaultRetentionDays;

  BackgroundTrackingStatus currentStatus = BackgroundTrackingStatus.disabled;
  void Function(BackgroundTrackingStatus status)? onStatusChanged;
  void Function()? onTimelineChanged;

  // Starts continuous location updates after checking services and permission.
  Future<BackgroundTrackingStatus> start() async {
    await DiagnosticLogService.record(
      'tracking',
      'Foreground tracker start requested',
    );
    if (_positionSubscription != null) {
      await DiagnosticLogService.record(
        'tracking',
        'Tracker was already active',
      );
      return _emit(BackgroundTrackingStatus.active);
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      await DiagnosticLogService.record('tracking', 'Unsupported platform');
      return _emit(BackgroundTrackingStatus.unsupported);
    }

    _emit(BackgroundTrackingStatus.starting);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await DiagnosticLogService.record(
          'tracking',
          'Start blocked because device location services are off',
        );
        return _emit(BackgroundTrackingStatus.locationServicesDisabled);
      }

      var permission = await Geolocator.checkPermission();
      await DiagnosticLogService.record(
        'tracking',
        'Initial location permission=$permission',
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        await DiagnosticLogService.record(
          'tracking',
          'Permission after request=$permission',
        );
      }
      if (permission == LocationPermission.denied) {
        return _emit(BackgroundTrackingStatus.permissionDenied);
      }
      if (permission == LocationPermission.deniedForever) {
        return _emit(BackgroundTrackingStatus.permissionDeniedForever);
      }
      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always) {
        return _emit(BackgroundTrackingStatus.backgroundPermissionNeeded);
      }

      await _loadConfiguration();
      await _restoreState();
      await _cleanOldSamples(DateTime.now().toUtc());

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: _locationSettings)
              .listen(
                _queuePosition,
                onError: (Object error) {
                  unawaited(
                    DiagnosticLogService.record(
                      'tracking',
                      'Location stream reported an error',
                      error: error,
                    ),
                  );
                  _emit(BackgroundTrackingStatus.error);
                },
                cancelOnError: false,
              );
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
        (status) => _emit(
          status == ServiceStatus.enabled
              ? BackgroundTrackingStatus.active
              : BackgroundTrackingStatus.locationServicesDisabled,
        ),
      );
      unawaited(checkWeatherNow());
      await DiagnosticLogService.record(
        'tracking',
        'Foreground location stream started',
      );
      return _emit(BackgroundTrackingStatus.active);
    } catch (error) {
      await DiagnosticLogService.record(
        'tracking',
        'Foreground tracker failed to start',
        error: error,
      );
      await stop();
      return _emit(BackgroundTrackingStatus.error);
    }
  }

  // Stops location collection while leaving persisted visit state recoverable.
  Future<void> stop() async {
    await DiagnosticLogService.record(
      'tracking',
      'Stopping foreground tracker',
    );
    _candidateTimer?.cancel();
    _candidateTimer = null;
    _weatherTimer?.cancel();
    _weatherTimer = null;
    _candidate = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
    _emit(BackgroundTrackingStatus.disabled);
  }

  // Checks weather now and keeps it serialized with incoming location work.
  Future<void> checkWeatherNow() {
    if (_positionSubscription == null) {
      return DiagnosticLogService.record(
        'weather',
        'Foreground weather check skipped because tracker is not active',
      );
    }
    unawaited(
      DiagnosticLogService.record('weather', 'Foreground weather check queued'),
    );
    _processing = _processing
        .then((_) async {
          await _refreshWeatherAtCurrentLocation();
        })
        .catchError((Object error, StackTrace _) {
          _lastWeatherFailureAt = DateTime.now().toUtc();
          unawaited(
            DiagnosticLogService.record(
              'weather',
              'Foreground weather check failed',
              error: error,
            ),
          );
        });
    return _processing.whenComplete(_scheduleNextWeatherCheck);
  }

  // Performs one self-contained check from an OS background worker.
  Future<bool> runScheduledCheck({bool ignoreHourlyLimit = false}) async {
    await DiagnosticLogService.record(
      'weather',
      'Scheduled check started; manualTest=$ignoreHourlyLimit',
    );
    if (!Platform.isAndroid && !Platform.isIOS) {
      await DiagnosticLogService.record(
        'weather',
        'Skipped on unsupported platform',
      );
      return true;
    }
    final trackingSetting = await _settingsDatabase.getSetting(
      'automatic_tracking_enabled',
    );
    if (trackingSetting == 'false') {
      await DiagnosticLogService.record(
        'weather',
        'Skipped because automatic tracking setting is off',
      );
      return true;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      await DiagnosticLogService.record(
        'weather',
        'Failed because device location services are off',
      );
      return false;
    }
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      await DiagnosticLogService.record(
        'weather',
        'Skipped because background location permission=$permission',
      );
      return true;
    }

    try {
      await _loadConfiguration();
      await _restoreState();
      final dateKey = formatDateKey(DateTime.now());
      final hasBaseline = await _diaryDatabase.hasTimelineEvent(
        dateKey,
        _dailyBaselineEvent,
      );
      final lastReadingAt = DateTime.tryParse(
        _lastWeather?[WeatherSnapshotsTable.retrievedAt] as String? ?? '',
      );
      if (!ignoreHourlyLimit &&
          hasBaseline &&
          lastReadingAt != null &&
          DateTime.now().toUtc().difference(lastReadingAt).abs() <
              _weatherRefresh) {
        final ageMinutes = DateTime.now()
            .toUtc()
            .difference(lastReadingAt)
            .abs()
            .inMinutes;
        await DiagnosticLogService.record(
          'weather',
          'Skipped because last reading is only ${ageMinutes}m old',
        );
        return true;
      }
      return await _refreshWeatherAtCurrentLocation(force: ignoreHourlyLimit);
    } catch (error) {
      await DiagnosticLogService.record(
        'weather',
        'Scheduled check failed',
        error: error,
      );
      return false;
    }
  }

  // Opens the operating-system page where location access can be corrected.
  Future<void> openRelevantSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    await Geolocator.openAppSettings();
  }

  LocationSettings get _locationSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 25,
        intervalDuration: const Duration(minutes: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'ChronoLoge is remembering your day',
          notificationText:
              'Location is used privately to build your automatic diary.',
          notificationChannelName: 'Automatic diary location',
          setOngoing: true,
        ),
      );
    }
    return AppleSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 25,
      activityType: ActivityType.other,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  }

  Future<void> _loadConfiguration() async {
    final values = await Future.wait([
      _settingsDatabase.getSetting('location_retention_days'),
      _settingsDatabase.getSetting('weather_refresh_minutes'),
    ]);
    _retentionDays = int.tryParse(values[0] ?? '') ?? _defaultRetentionDays;
    final weatherMinutes = int.tryParse(values[1] ?? '') ?? 60;
    // Never let an old setting make automatic collection less than hourly.
    _weatherRefresh = Duration(minutes: weatherMinutes.clamp(15, 60));
    await DiagnosticLogService.record(
      'tracking',
      'Configuration loaded; weather interval=${_weatherRefresh.inMinutes}m',
    );
  }

  Future<void> _restoreState() async {
    _activeVisit = await _trackingDatabase.getActiveVisit();
    _activeTrip = await _trackingDatabase.getActiveTrip();
    _lastWeather = await _trackingDatabase.getLatestWeatherSnapshot();

    final recentSamples = await _trackingDatabase.getLocationSamples(
      from: DateTime.now().toUtc().subtract(const Duration(hours: 6)),
      to: DateTime.now().toUtc(),
    );
    if (recentSamples.isNotEmpty) {
      final sample = recentSamples.last;
      _lastPoint = _LocationPoint(
        latitude: (sample[LocationSamplesTable.latitude]! as num).toDouble(),
        longitude: (sample[LocationSamplesTable.longitude]! as num).toDouble(),
        recordedAt: DateTime.parse(
          sample[LocationSamplesTable.recordedAt]! as String,
        ),
      );
    }
  }

  void _queuePosition(Position position) {
    _processing = _processing
        .then((_) => _processPosition(position))
        .catchError((Object _, StackTrace _) {
          _emit(BackgroundTrackingStatus.error);
        });
  }

  Future<void> _processPosition(Position position) async {
    final recordedAt = position.timestamp.toUtc();
    final point = _LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: recordedAt,
    );
    final activity = _activityForSpeed(position.speed);
    await _trackingDatabase.addLocationSample(
      recordedAt: recordedAt,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMetres: position.accuracy,
      speedMetresSecond: position.speed < 0 ? 0 : position.speed,
      activity: activity,
      activityConfidence: _activityConfidence(position.accuracy),
    );
    await _cleanOldSamples(recordedAt);

    if (position.accuracy > _maximumUsefulAccuracyMetres) {
      _lastPoint = point;
      return;
    }

    await _recordWeatherIfDue(point);
    await _recordTripSegment(point);
    if (_activeVisit != null) {
      await _processActiveVisit(point);
    } else {
      await _processPossibleArrival(point, position.speed);
    }
    _lastPoint = point;
    _emit(BackgroundTrackingStatus.active);
  }

  Future<void> _recordTripSegment(_LocationPoint point) async {
    final trip = _activeTrip;
    final previous = _lastPoint;
    if (trip == null || previous == null) return;

    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );
    final elapsedSeconds = point.recordedAt
        .difference(previous.recordedAt)
        .inSeconds
        .abs();
    final maximumReasonableDistance = (elapsedSeconds * 70).clamp(500, 10000);
    if (distance >= 10 && distance <= maximumReasonableDistance) {
      await _trackingDatabase.addTripDistance(
        trip[TripsTable.id]! as int,
        distance,
      );
      trip[TripsTable.distanceMetres] =
          (trip[TripsTable.distanceMetres]! as num).toDouble() + distance;
    }
  }

  Future<void> _processActiveVisit(_LocationPoint point) async {
    final visit = _activeVisit!;
    final distance = Geolocator.distanceBetween(
      (visit[VisitsTable.latitude]! as num).toDouble(),
      (visit[VisitsTable.longitude]! as num).toDouble(),
      point.latitude,
      point.longitude,
    );
    if (distance <= _departureRadiusMetres) {
      _outsideVisitSamples = 0;
      return;
    }

    _outsideVisitSamples += 1;
    if (_outsideVisitSamples < 2) return;
    _outsideVisitSamples = 0;
    await _finishVisit(point);
    _startCandidate(point);
  }

  Future<void> _finishVisit(_LocationPoint point) async {
    final visit = _activeVisit!;
    final visitId = visit[VisitsTable.id]! as int;
    final placeId = visit[VisitsTable.placeId] as int?;
    await _trackingDatabase.endVisit(visitId, point.recordedAt);
    final tripId = await _trackingDatabase.addTrip(
      startedAt: point.recordedAt,
      startVisitId: visitId,
      transportMode: 'unknown',
    );
    _activeTrip = {
      TripsTable.id: tripId,
      TripsTable.startedAt: point.recordedAt.toIso8601String(),
      TripsTable.distanceMetres: 0.0,
    };

    final place = placeId == null
        ? null
        : await _trackingDatabase.getPlace(placeId);
    final locationSnapshotId = await _trackingDatabase.addLocationSnapshot(
      recordedAt: point.recordedAt,
      latitude: point.latitude,
      longitude: point.longitude,
      locationLabel: _placeLabel(place),
    );
    await _diaryDatabase.addTimelineItem(
      formatDateKey(point.recordedAt.toLocal()),
      occurredAt: point.recordedAt,
      textData: 'Left ${_placeLabel(place)}',
      mood: '',
      source: 'automatic',
      eventType: 'departure',
      locationSnapshotId: locationSnapshotId,
      placeId: placeId,
      visitId: visitId,
      tripId: tripId,
      weatherSnapshotId: _lastWeather?[WeatherSnapshotsTable.id] as int?,
      confidence: (visit[VisitsTable.confidence]! as num).toDouble(),
    );
    _activeVisit = null;
    onTimelineChanged?.call();
  }

  Future<void> _processPossibleArrival(
    _LocationPoint point,
    double speedMetresSecond,
  ) async {
    if (speedMetresSecond > 2.5) {
      _clearCandidate();
      return;
    }

    final candidate = _candidate;
    if (candidate == null) {
      _startCandidate(point);
      return;
    }
    final distance = Geolocator.distanceBetween(
      candidate.latitude,
      candidate.longitude,
      point.latitude,
      point.longitude,
    );
    if (distance > _stayRadiusMetres) {
      _startCandidate(point);
      return;
    }

    candidate.include(point);
    if (point.recordedAt.difference(candidate.startedAt) >=
        _minimumStayDuration) {
      await _confirmArrival(candidate, point.recordedAt);
    }
  }

  void _startCandidate(_LocationPoint point) {
    _candidateTimer?.cancel();
    _candidate = _StayCandidate.fromPoint(point);
    _candidateTimer = Timer(_minimumStayDuration, () async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
        _queuePosition(position);
      } catch (_) {
        // The regular position stream will retry dwell confirmation later.
      }
    });
  }

  void _clearCandidate() {
    _candidateTimer?.cancel();
    _candidateTimer = null;
    _candidate = null;
  }

  Future<void> _confirmArrival(
    _StayCandidate candidate,
    DateTime confirmedAt,
  ) async {
    _clearCandidate();
    final matchedPlace = await _findNearbyPlace(
      candidate.latitude,
      candidate.longitude,
    );
    final isFirstVisit = matchedPlace == null;
    final placeId = matchedPlace == null
        ? await _trackingDatabase.addPlace(
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            firstVisitedAt: candidate.startedAt,
            name: await _locationName(candidate.latitude, candidate.longitude),
          )
        : matchedPlace[PlacesTable.id]! as int;

    final visitId = await _trackingDatabase.addVisit(
      arrivedAt: candidate.startedAt,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      confidence: candidate.confidence,
      placeId: placeId,
      isFirstVisit: isFirstVisit,
    );

    int? completedTripId;
    final activeTrip = _activeTrip;
    if (activeTrip != null) {
      completedTripId = activeTrip[TripsTable.id]! as int;
      await _trackingDatabase.endTrip(
        completedTripId,
        endedAt: confirmedAt,
        endVisitId: visitId,
        distanceMetres: (activeTrip[TripsTable.distanceMetres]! as num)
            .toDouble(),
      );
      _activeTrip = null;
    }

    final place = matchedPlace ?? await _trackingDatabase.getPlace(placeId);
    final locationSnapshotId = await _trackingDatabase.addLocationSnapshot(
      recordedAt: candidate.startedAt,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      locationLabel: _placeLabel(place),
    );
    final timelineId = await _diaryDatabase.addTimelineItem(
      formatDateKey(candidate.startedAt.toLocal()),
      occurredAt: candidate.startedAt,
      textData: isFirstVisit
          ? 'Visited a new place near ${_placeLabel(place)}'
          : 'Arrived at ${_placeLabel(place)}',
      mood: '',
      source: 'automatic',
      eventType: isFirstVisit ? 'new_place' : 'arrival',
      locationSnapshotId: locationSnapshotId,
      placeId: placeId,
      visitId: visitId,
      tripId: completedTripId,
      confidence: candidate.confidence,
    );
    _activeVisit = {
      VisitsTable.id: visitId,
      VisitsTable.placeId: placeId,
      VisitsTable.arrivedAt: candidate.startedAt.toIso8601String(),
      VisitsTable.latitude: candidate.latitude,
      VisitsTable.longitude: candidate.longitude,
      VisitsTable.confidence: candidate.confidence,
      VisitsTable.isFirstVisit: isFirstVisit ? 1 : 0,
    };

    if (isFirstVisit) {
      final promptId = await _trackingDatabase.addMemoryPrompt(
        visitId: visitId,
        timelineItemId: timelineId,
        createdAt: confirmedAt,
      );
      await _showNewPlacePrompt(
        promptId: promptId,
        visitId: visitId,
        placeLabel: _placeLabel(place),
      );
    }
    await _recordWeatherIfDue(
      _LocationPoint(
        latitude: candidate.latitude,
        longitude: candidate.longitude,
        recordedAt: confirmedAt,
      ),
      force: true,
    );
    onTimelineChanged?.call();
  }

  // Shows a first-visit prompt once when the user has allowed it.
  Future<void> _showNewPlacePrompt({
    required int promptId,
    required int visitId,
    required String placeLabel,
  }) async {
    if (promptId == 0) return;
    try {
      final preferences = await Future.wait([
        _settingsDatabase.getSetting('notifications_enabled'),
        _settingsDatabase.getSetting('new_place_prompts_enabled'),
      ]);
      if (preferences[0] != 'true' || preferences[1] == 'false') {
        await _trackingDatabase.updateMemoryPromptStatus(
          promptId,
          status: 'expired',
          respondedAt: DateTime.now(),
        );
        return;
      }

      await _notificationService.showNewPlacePrompt(
        visitId: visitId,
        placeLabel: placeLabel,
      );
      await _trackingDatabase.updateMemoryPromptStatus(
        promptId,
        status: 'shown',
        shownAt: DateTime.now(),
      );
    } catch (_) {
      // Notification or settings failures must not interrupt location tracking.
    }
  }

  Future<TrackingRow?> _findNearbyPlace(
    double latitude,
    double longitude,
  ) async {
    TrackingRow? nearest;
    var nearestDistance = double.infinity;
    for (final place in await _trackingDatabase.getPlaces()) {
      if (place[PlacesTable.isIgnored] == 1) continue;
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        (place[PlacesTable.latitude]! as num).toDouble(),
        (place[PlacesTable.longitude]! as num).toDouble(),
      );
      final radius = (place[PlacesTable.radiusMetres]! as num).toDouble();
      if (distance <= radius && distance < nearestDistance) {
        nearest = place;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  // Schedules the next hourly check, midnight baseline, or network retry.
  void _scheduleNextWeatherCheck() {
    _weatherTimer?.cancel();
    if (_positionSubscription == null) return;

    final now = DateTime.now();
    Duration delay;
    final failedAt = _lastWeatherFailureAt;
    if (failedAt != null) {
      final elapsed = now.toUtc().difference(failedAt).abs();
      final remaining = _weatherRetryDelay - elapsed;
      delay = remaining > Duration.zero
          ? remaining
          : const Duration(seconds: 1);
    } else {
      final retrievedAtText =
          _lastWeather?[WeatherSnapshotsTable.retrievedAt] as String?;
      final retrievedAt = DateTime.tryParse(retrievedAtText ?? '');
      if (retrievedAt == null) {
        delay = _weatherRetryDelay;
      } else {
        final elapsed = now.toUtc().difference(retrievedAt).abs();
        final remaining = _weatherRefresh - elapsed;
        delay = remaining > Duration.zero
            ? remaining
            : const Duration(seconds: 1);
      }
    }

    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).add(const Duration(seconds: 2));
    final untilMidnight = nextMidnight.difference(now);
    if (untilMidnight < delay) delay = untilMidnight;

    unawaited(
      DiagnosticLogService.record(
        'scheduler',
        'Foreground weather timer scheduled in ${delay.inMinutes}m',
      ),
    );

    _weatherTimer = Timer(delay, () {
      unawaited(checkWeatherNow());
    });
  }

  // Gets a fresh coordinate for periodic and foreground-resume checks.
  Future<bool> _refreshWeatherAtCurrentLocation({bool force = false}) async {
    await DiagnosticLogService.record(
      'weather',
      'Requesting a current location fix',
    );
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
    await DiagnosticLogService.record(
      'weather',
      'Location fix received; accuracy=${position.accuracy.round()}m',
    );
    if (position.accuracy > _maximumUsefulAccuracyMetres) {
      _lastWeatherFailureAt = DateTime.now().toUtc();
      await DiagnosticLogService.record(
        'weather',
        'Location rejected because accuracy exceeded '
            '${_maximumUsefulAccuracyMetres.round()}m',
      );
      return false;
    }
    return _recordWeatherIfDue(
      _LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: DateTime.now().toUtc(),
      ),
      force: force,
    );
  }

  Future<bool> _recordWeatherIfDue(
    _LocationPoint point, {
    bool force = false,
  }) async {
    final dateKey = formatDateKey(DateTime.now());
    final needsDailyBaseline = !await _diaryDatabase.hasTimelineEvent(
      dateKey,
      _dailyBaselineEvent,
    );
    final failedAt = _lastWeatherFailureAt;
    if (!force &&
        failedAt != null &&
        DateTime.now().toUtc().difference(failedAt).abs() <
            _weatherRetryDelay) {
      final retryIn =
          _weatherRetryDelay -
          DateTime.now().toUtc().difference(failedAt).abs();
      await DiagnosticLogService.record(
        'weather',
        'Skipped during retry cooldown; retry in ${retryIn.inMinutes}m',
      );
      return true;
    }
    final previous = _lastWeather;
    if (!force &&
        !needsDailyBaseline &&
        _lastWeatherFailureAt == null &&
        previous != null) {
      final retrievedAt = DateTime.tryParse(
        previous[WeatherSnapshotsTable.retrievedAt]! as String,
      );
      final refreshIsDue =
          retrievedAt == null ||
          DateTime.now().toUtc().difference(retrievedAt).abs() >=
              _weatherRefresh;
      final previousLatitude = previous[WeatherSnapshotsTable.latitude] as num?;
      final previousLongitude =
          previous[WeatherSnapshotsTable.longitude] as num?;
      final locationChanged =
          previousLatitude != null &&
          previousLongitude != null &&
          Geolocator.distanceBetween(
                previousLatitude.toDouble(),
                previousLongitude.toDouble(),
                point.latitude,
                point.longitude,
              ) >=
              _weatherLocationChangeMetres;
      if (!refreshIsDue && !locationChanged) {
        await DiagnosticLogService.record(
          'weather',
          'No reading needed yet; no large location change detected',
        );
        return true;
      }
    }

    try {
      await DiagnosticLogService.record(
        'weather',
        'Calling Open-Meteo; dailyBaseline=$needsDailyBaseline, forced=$force',
      );
      final weather = await _weatherService.loadCurrent(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      final retrievedAt = DateTime.now().toUtc();
      _lastWeatherFailureAt = null;
      await DiagnosticLogService.record(
        'weather',
        'Open-Meteo returned ${weather.condition}, '
            '${weather.temperature.round()}C, code=${weather.weatherCode}',
      );
      final weatherId = await _trackingDatabase.addWeatherSnapshot(
        observedAt: retrievedAt,
        retrievedAt: retrievedAt,
        latitude: point.latitude,
        longitude: point.longitude,
        temperatureCelsius: weather.temperature,
        apparentTemperatureCelsius: weather.apparentTemperature,
        precipitationMm: weather.precipitation,
        cloudCoverPercent: weather.cloudCover,
        windSpeedKph: weather.windSpeed,
        weatherCode: weather.weatherCode,
        weatherLabel: '${weather.condition}, ${weather.temperature.round()}°C',
      );
      final oldTemperature =
          (previous?[WeatherSnapshotsTable.temperatureCelsius] as num?)
              ?.toDouble();
      final oldWeatherCode =
          (previous?[WeatherSnapshotsTable.weatherCode] as num?)?.round();
      final temperatureChanged =
          oldTemperature != null &&
          oldTemperature.round() != weather.temperature.round();
      final conditionChanged =
          oldWeatherCode != null &&
          OpenMeteoWeatherService.weatherLabel(oldWeatherCode) !=
              weather.condition;
      _lastWeather = {
        WeatherSnapshotsTable.id: weatherId,
        WeatherSnapshotsTable.retrievedAt: retrievedAt.toIso8601String(),
        WeatherSnapshotsTable.latitude: point.latitude,
        WeatherSnapshotsTable.longitude: point.longitude,
        WeatherSnapshotsTable.temperatureCelsius: weather.temperature,
        WeatherSnapshotsTable.weatherCode: weather.weatherCode,
      };

      final visit = _activeVisit;
      final placeId = visit?[VisitsTable.placeId] as int?;
      final place = placeId == null
          ? null
          : await _trackingDatabase.getPlace(placeId);
      var locationLabel = _placeLabel(place);
      if (place == null || locationLabel == 'this place') {
        locationLabel = await _locationName(point.latitude, point.longitude);
      }
      final locationSnapshotId = await _trackingDatabase.addLocationSnapshot(
        recordedAt: retrievedAt,
        latitude: point.latitude,
        longitude: point.longitude,
        locationLabel: locationLabel,
      );
      final weatherChanged =
          (temperatureChanged || conditionChanged) &&
          oldTemperature != null &&
          oldWeatherCode != null;
      final eventType = needsDailyBaseline
          ? _dailyBaselineEvent
          : weatherChanged
          ? 'weather'
          : 'hourly_checkin';
      final textData = needsDailyBaseline
          ? 'Started tracking today'
          : weatherChanged
          ? _weatherChangeText(
              oldTemperature: oldTemperature,
              oldWeatherCode: oldWeatherCode,
              newTemperature: weather.temperature,
              newWeatherCode: weather.weatherCode,
            )
          : 'Hourly check-in';
      await _diaryDatabase.addTimelineItem(
        dateKey,
        occurredAt: retrievedAt,
        textData: textData,
        mood: '',
        source: 'automatic',
        eventType: eventType,
        locationSnapshotId: locationSnapshotId,
        placeId: placeId,
        visitId: visit?[VisitsTable.id] as int?,
        weatherSnapshotId: weatherId,
      );
      await DiagnosticLogService.record(
        'database',
        'Timeline item saved; date=$dateKey, eventType=$eventType',
      );
      onTimelineChanged?.call();
      return true;
    } catch (error) {
      _lastWeatherFailureAt = DateTime.now().toUtc();
      await DiagnosticLogService.record(
        'weather',
        'Weather fetch or timeline save failed',
        error: error,
      );
      _scheduleNextWeatherCheck();
      return false;
    }
  }

  // Builds a short sentence from the previous and current weather readings.
  String _weatherChangeText({
    required double oldTemperature,
    required int oldWeatherCode,
    required double newTemperature,
    required int newWeatherCode,
  }) {
    final oldRounded = oldTemperature.round();
    final newRounded = newTemperature.round();
    if (oldRounded != newRounded) {
      return 'Weather changed from $oldRounded°C to $newRounded°C';
    }

    final oldCondition = OpenMeteoWeatherService.weatherLabel(oldWeatherCode);
    final newCondition = OpenMeteoWeatherService.weatherLabel(newWeatherCode);
    return 'Weather changed from $oldCondition to $newCondition';
  }

  Future<void> _cleanOldSamples(DateTime now) async {
    final lastCleanupAt = _lastCleanupAt;
    if (lastCleanupAt != null &&
        now.difference(lastCleanupAt) < const Duration(hours: 12)) {
      return;
    }
    await _trackingDatabase.deleteLocationSamplesBefore(
      now.subtract(Duration(days: _retentionDays.clamp(1, 90))),
    );
    _lastCleanupAt = now;
  }

  Future<String> _locationName(double latitude, double longitude) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final areaParts = <String>{
          if (place.subLocality?.trim().isNotEmpty == true)
            place.subLocality!.trim(),
          if (place.locality?.trim().isNotEmpty == true) place.locality!.trim(),
        };
        if (areaParts.isNotEmpty) return areaParts.join(', ');

        for (final value in [place.street, place.name]) {
          final label = value?.trim() ?? '';
          if (label.isNotEmpty && !_looksLikeHouseNumber(label)) return label;
        }
      }
    } catch (_) {
      // A coordinate label below keeps place recognition functional offline.
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  String _placeLabel(TrackingRow? place) {
    final name = place?[PlacesTable.nameColumn] as String?;
    if (name != null &&
        name.trim().isNotEmpty &&
        !_looksLikeHouseNumber(name.trim())) {
      return name.trim();
    }
    return 'this place';
  }

  bool _looksLikeHouseNumber(String label) {
    return RegExp(r'^\d+[A-Za-z]?$').hasMatch(label);
  }

  String _activityForSpeed(double speedMetresSecond) {
    if (speedMetresSecond < 0.5) return 'stationary';
    if (speedMetresSecond < 2.2) return 'walking';
    if (speedMetresSecond < 6.5) return 'cycling';
    return 'moving';
  }

  int _activityConfidence(double accuracyMetres) {
    if (accuracyMetres <= 20) return 90;
    if (accuracyMetres <= 60) return 70;
    if (accuracyMetres <= 120) return 50;
    return 25;
  }

  BackgroundTrackingStatus _emit(BackgroundTrackingStatus status) {
    if (currentStatus == status) return status;
    currentStatus = status;
    unawaited(
      DiagnosticLogService.record('tracking', 'Status changed to $status'),
    );
    onStatusChanged?.call(status);
    return status;
  }
}

class _LocationPoint {
  const _LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
}

class _StayCandidate {
  _StayCandidate({
    required this.startedAt,
    required this.latitude,
    required this.longitude,
  });

  factory _StayCandidate.fromPoint(_LocationPoint point) {
    return _StayCandidate(
      startedAt: point.recordedAt,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  final DateTime startedAt;
  double latitude;
  double longitude;
  int sampleCount = 1;

  double get confidence => (0.55 + sampleCount * 0.08).clamp(0.55, 0.95);

  void include(_LocationPoint point) {
    latitude = (latitude * sampleCount + point.latitude) / (sampleCount + 1);
    longitude = (longitude * sampleCount + point.longitude) / (sampleCount + 1);
    sampleCount += 1;
  }
}
