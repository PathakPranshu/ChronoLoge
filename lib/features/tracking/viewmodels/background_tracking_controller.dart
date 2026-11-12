import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/services/background_location_service.dart';
import '../../../core/services/android_background_health_service.dart';
import '../../../core/services/diagnostic_log_service.dart';
import '../../../core/services/hourly_background_worker.dart';
import '../../settings/viewmodels/settings_view_model.dart';
import '../../today/viewmodels/today_view_model.dart';

final backgroundLocationServiceProvider = Provider<BackgroundLocationService>((
  ref,
) {
  return BackgroundLocationService(
    ref.watch(trackingDatabaseProvider),
    ref.watch(diaryDatabaseProvider),
    ref.watch(settingsDatabaseProvider),
  );
});

final backgroundTrackingControllerProvider =
    AsyncNotifierProvider<
      BackgroundTrackingController,
      BackgroundTrackingStatus
    >(BackgroundTrackingController.new);

/// Starts or stops location tracking when the saved setting changes.
class BackgroundTrackingController
    extends AsyncNotifier<BackgroundTrackingStatus> {
  @override
  Future<BackgroundTrackingStatus> build() async {
    final service = ref.watch(backgroundLocationServiceProvider);
    service.onStatusChanged = (status) {
      if (state.value == status) return;
      scheduleMicrotask(() {
        if (state.value != status) state = AsyncData(status);
      });
    };
    service.onTimelineChanged = () {
      ref.invalidate(todayViewModelProvider);
    };
    ref.onDispose(() {
      service.onStatusChanged = null;
      service.onTimelineChanged = null;
      unawaited(service.stop());
      unawaited(cancelHourlyBackgroundWorker());
    });

    var controllerIsReady = false;
    ref.listen<bool?>(
      settingsViewModelProvider.select(
        (settings) => settings.value?.automaticTrackingEnabled,
      ),
      (previous, enabled) {
        if (!controllerIsReady || enabled == null || enabled == previous) {
          return;
        }
        unawaited(_applyTrackingSetting(enabled));
      },
    );

    final loadedSettings = await ref.read(settingsViewModelProvider.future);
    controllerIsReady = true;
    return _setServiceEnabled(loadedSettings.automaticTrackingEnabled);
  }

  // Applies only the location toggle without reacting to unrelated settings.
  Future<void> _applyTrackingSetting(bool enabled) async {
    if (enabled) {
      state = const AsyncData(BackgroundTrackingStatus.starting);
    }
    state = AsyncData(await _setServiceEnabled(enabled));
  }

  // Starts or stops the shared location service.
  Future<BackgroundTrackingStatus> _setServiceEnabled(bool enabled) async {
    await DiagnosticLogService.record(
      'controller',
      'Applying automatic tracking setting; enabled=$enabled',
    );
    final service = ref.read(backgroundLocationServiceProvider);
    if (enabled) {
      try {
        await scheduleHourlyBackgroundWorker();
      } catch (error) {
        await DiagnosticLogService.record(
          'controller',
          'Continuing with foreground tracker after scheduling failure',
          error: error,
        );
        // The live foreground tracker can still run if OS scheduling fails.
      }
      return service.start();
    }
    await service.stop();
    await cancelHourlyBackgroundWorker();
    return BackgroundTrackingStatus.disabled;
  }

  // Retries tracking after the user corrects permission or service settings.
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(backgroundLocationServiceProvider).start,
    );
  }

  // Performs the catch-up weather check used when the app returns to view.
  Future<void> checkWeatherNow() async {
    final settings = await ref.read(settingsViewModelProvider.future);
    if (!settings.automaticTrackingEnabled) return;
    final status = await _setServiceEnabled(true);
    state = AsyncData(status);
    if (status == BackgroundTrackingStatus.active) {
      await ref.read(backgroundLocationServiceProvider).checkWeatherNow();
    }
  }

  // Runs the background path immediately and ignores the one-hour throttle.
  Future<bool> runDiagnosticCheck() async {
    await DiagnosticLogService.record(
      'diagnostics',
      'Manual background-path test requested from Settings',
    );
    await AndroidBackgroundHealthService.check(writeLog: true);
    final service = ref.read(backgroundLocationServiceProvider);
    final succeeded = await service.runScheduledCheck(ignoreHourlyLimit: true);
    if (succeeded) ref.invalidate(todayViewModelProvider);
    await DiagnosticLogService.record(
      'diagnostics',
      'Manual background-path test finished; succeeded=$succeeded',
    );
    return succeeded;
  }

  // Opens the most relevant operating-system location settings page.
  Future<void> openSettings() {
    return ref.read(backgroundLocationServiceProvider).openRelevantSettings();
  }
}
