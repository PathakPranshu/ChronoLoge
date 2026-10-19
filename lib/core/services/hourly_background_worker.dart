import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';
import '../database/diary_database.dart';
import '../database/settings_database.dart';
import '../database/tracking_database.dart';
import 'background_location_service.dart';
import 'diagnostic_log_service.dart';

const hourlyTimelineTask = 'com.example.chronologe.hourlyTimeline';

// Handles an hourly checkpoint when the normal app process is not available.
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await DiagnosticLogService.record(
      'worker',
      'OS woke background callback for task=$task',
    );
    if (task != hourlyTimelineTask && task != Workmanager.iOSBackgroundTask) {
      await DiagnosticLogService.record(
        'worker',
        'Ignored an unrelated background task',
      );
      return true;
    }

    final appDatabase = AppDatabase();
    try {
      final service = BackgroundLocationService(
        TrackingDatabase(appDatabase),
        DiaryDatabase(appDatabase),
        SettingsDatabase(appDatabase),
      );
      final succeeded = await service.runScheduledCheck();
      await DiagnosticLogService.record(
        'worker',
        'Background check finished; succeeded=$succeeded',
      );
      return succeeded;
    } catch (error) {
      await DiagnosticLogService.record(
        'worker',
        'Background check crashed before completion',
        error: error,
      );
      return false;
    } finally {
      await appDatabase.close();
      await DiagnosticLogService.record('worker', 'Background database closed');
    }
  });
}

// Connects the Dart callback to Android WorkManager and Apple BGTaskScheduler.
Future<void> initializeHourlyBackgroundWorker() async {
  await DiagnosticLogService.record('scheduler', 'Initializing Workmanager');
  try {
    await Workmanager().initialize(backgroundTaskDispatcher);
    await DiagnosticLogService.record(
      'scheduler',
      'Workmanager initialized successfully',
    );
  } catch (error) {
    await DiagnosticLogService.record(
      'scheduler',
      'Workmanager initialization failed',
      error: error,
    );
    rethrow;
  }
}

// Wakes regularly, but only collects when the last reading is an hour old.
Future<void> scheduleHourlyBackgroundWorker() async {
  await DiagnosticLogService.record(
    'scheduler',
    'Requesting periodic worker; wake interval=15m, data interval=1h',
  );
  try {
    await Workmanager().registerPeriodicTask(
      hourlyTimelineTask,
      hourlyTimelineTask,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 10),
    );
    await DiagnosticLogService.record(
      'scheduler',
      'OS accepted periodic worker registration',
    );
  } catch (error) {
    await DiagnosticLogService.record(
      'scheduler',
      'Periodic worker registration failed',
      error: error,
    );
    rethrow;
  }
}

// Stops future hourly jobs when automatic tracking is disabled or signed out.
Future<void> cancelHourlyBackgroundWorker() async {
  await Workmanager().cancelByUniqueName(hourlyTimelineTask);
  await DiagnosticLogService.record('scheduler', 'Periodic worker cancelled');
}
