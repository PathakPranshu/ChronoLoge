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

class BackgroundTrackingController
    extends AsyncNotifier<BackgroundTrackingStatus> {
  @override
  Future<BackgroundTrackingStatus> build() async {
    final settings = ref.watch(settingsViewModelProvider);
    final service = ref.watch(backgroundLocationServiceProvider);
    service.onStatusChanged = (status) {
      scheduleMicrotask(() => state = AsyncData(status));
    };
    service.onTimelineChanged = () {
      ref.invalidate(todayViewModelProvider);
    };
    ref.onDispose(() {
      service.onStatusChanged = null;
      service.onTimelineChanged = null;
      unawaited(service.stop());
    });

    final loadedSettings = settings.value;
    if (loadedSettings == null) return BackgroundTrackingStatus.starting;
    if (!loadedSettings.automaticTrackingEnabled) {
      await service.stop();
      return BackgroundTrackingStatus.disabled;
    }
    return service.start();
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
