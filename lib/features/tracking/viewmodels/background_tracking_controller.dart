import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/services/background_location_service.dart';
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
    final service = ref.read(backgroundLocationServiceProvider);
    if (enabled) return service.start();
    await service.stop();
    return BackgroundTrackingStatus.disabled;
  }

  // Retries tracking after the user corrects permission or service settings.
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(backgroundLocationServiceProvider).start,
    );
  }

  // Opens the most relevant operating-system location settings page.
  Future<void> openSettings() {
    return ref.read(backgroundLocationServiceProvider).openRelevantSettings();
  }
}
