import 'dart:io';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// A workout read from Apple Health or Google Health Connect.
class HealthWorkoutRecord {
  const HealthWorkoutRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.activityName,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String activityName;
}

/// The small set of health information ChronoLoge uses for one day.
class HealthDayData {
  const HealthDayData({required this.steps, required this.workouts});

  final int steps;
  final List<HealthWorkoutRecord> workouts;
}

/// A readable error that can be shown on the Settings page.
class HealthServiceException implements Exception {
  const HealthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads steps and workouts without writing anything back to the health app.
class HealthService {
  HealthService({Health? health}) : _health = health ?? Health();

  static const _types = [HealthDataType.STEPS, HealthDataType.WORKOUT];
  static const _permissions = [HealthDataAccess.READ, HealthDataAccess.READ];

  final Health _health;

  // Checks whether this device can provide Apple Health or Health Connect data.
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    await _health.configure();
    return _health.isHealthConnectAvailable();
  }

  // Requests the two read-only permissions used by the diary timeline.
  Future<bool> requestAccess() async {
    if (!await isAvailable()) return false;

    if (Platform.isAndroid) {
      final activityPermission = await Permission.activityRecognition.request();
      if (!activityPermission.isGranted) return false;
    }

    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  // Reads today's current step total and all workouts completed today.
  Future<HealthDayData> readToday() async {
    if (!await isAvailable()) {
      throw const HealthServiceException(
        'Health Connect is not available on this device.',
      );
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: startOfDay,
      endTime: now,
    );

    final workouts = <HealthWorkoutRecord>[];
    for (final point in points) {
      final value = point.value;
      if (value is! WorkoutHealthValue) continue;
      final fallbackId = [
        point.sourceId,
        point.dateFrom.toUtc().toIso8601String(),
        point.dateTo.toUtc().toIso8601String(),
        value.workoutActivityType.name,
      ].join('|');
      workouts.add(
        HealthWorkoutRecord(
          id: point.uuid.isEmpty ? fallbackId : point.uuid,
          startedAt: point.dateFrom,
          endedAt: point.dateTo,
          activityName: _friendlyActivityName(value.workoutActivityType.name),
        ),
      );
    }

    workouts.sort(
      (first, second) => first.startedAt.compareTo(second.startedAt),
    );
    return HealthDayData(steps: steps, workouts: workouts);
  }

  // Turns an enum name such as STRENGTH_TRAINING into readable text.
  static String _friendlyActivityName(String enumName) {
    return enumName
        .toLowerCase()
        .split('_')
        .where((word) => word.isNotEmpty)
        .join(' ');
  }
}
