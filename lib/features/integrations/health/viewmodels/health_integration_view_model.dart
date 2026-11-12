import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/display_helpers.dart';
import '../../../entries/viewmodels/entries_view_model.dart';
import '../../../settings/viewmodels/settings_view_model.dart';
import '../../../today/viewmodels/today_view_model.dart';
import '../services/health_service.dart';

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());

final healthIntegrationViewModelProvider =
    AsyncNotifierProvider<HealthIntegrationViewModel, HealthIntegrationState>(
      HealthIntegrationViewModel.new,
    );

enum HealthIntegrationStage {
  disabled,
  syncing,
  connected,
  permissionDenied,
  unavailable,
  error,
}

/// The connection message shown beside the Health toggle.
class HealthIntegrationState {
  const HealthIntegrationState(this.stage, this.message);

  const HealthIntegrationState.disabled()
    : this(
        HealthIntegrationStage.disabled,
        'Add steps and workouts to your diary timeline',
      );

  final HealthIntegrationStage stage;
  final String message;

  bool get isBusy => stage == HealthIntegrationStage.syncing;
}

/// Connects the Settings toggle to the health service and diary database.
class HealthIntegrationViewModel extends AsyncNotifier<HealthIntegrationState> {
  HealthService get _healthService => ref.read(healthServiceProvider);

  @override
  Future<HealthIntegrationState> build() async {
    final settings = await ref.read(settingsViewModelProvider.future);
    if (!settings.healthIntegrationEnabled) {
      return const HealthIntegrationState.disabled();
    }
    return _syncToday();
  }

  // Enables or disables health imports after the user changes the toggle.
  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await ref
          .read(settingsViewModelProvider.notifier)
          .setHealthIntegrationEnabled(false);
      state = const AsyncData(HealthIntegrationState.disabled());
      return;
    }

    state = const AsyncData(
      HealthIntegrationState(
        HealthIntegrationStage.syncing,
        'Waiting for health permission...',
      ),
    );

    try {
      if (!await _healthService.isAvailable()) {
        await _saveDisabledSetting();
        state = const AsyncData(
          HealthIntegrationState(
            HealthIntegrationStage.unavailable,
            'Apple Health or Health Connect is not available',
          ),
        );
        return;
      }

      final allowed = await _healthService.requestAccess();
      if (!allowed) {
        await _saveDisabledSetting();
        state = const AsyncData(
          HealthIntegrationState(
            HealthIntegrationStage.permissionDenied,
            'Health permission was not granted',
          ),
        );
        return;
      }

      await ref
          .read(settingsViewModelProvider.notifier)
          .setHealthIntegrationEnabled(true);
      state = AsyncData(await _syncToday());
    } catch (_) {
      await _saveDisabledSetting();
      state = const AsyncData(
        HealthIntegrationState(
          HealthIntegrationStage.error,
          'Could not connect to health data',
        ),
      );
    }
  }

  // Imports the latest health information when the app is opened again.
  Future<void> syncNow() async {
    if (state.value?.isBusy ?? false) return;
    final settings = await ref.read(settingsViewModelProvider.future);
    if (!settings.healthIntegrationEnabled) {
      state = const AsyncData(HealthIntegrationState.disabled());
      return;
    }
    state = const AsyncData(
      HealthIntegrationState(
        HealthIntegrationStage.syncing,
        'Updating today\'s health timeline...',
      ),
    );
    state = AsyncData(await _syncToday());
  }

  // Saves today's steps and workouts as normal diary timeline events.
  Future<HealthIntegrationState> _syncToday() async {
    try {
      final healthData = await _healthService.readToday();
      final database = ref.read(diaryDatabaseProvider);
      final now = DateTime.now();
      final today = formatDateKey(now);
      var savedEvents = 0;

      if (healthData.steps > 0) {
        await database.saveImportedTimelineItem(
          today,
          occurredAt: now,
          textData: 'Walked ${_formatNumber(healthData.steps)} steps so far',
          source: 'health:steps:$today',
          eventType: 'health_steps',
        );
        savedEvents++;
      }

      for (final workout in healthData.workouts) {
        final workoutDate = formatDateKey(workout.startedAt);
        await database.saveImportedTimelineItem(
          workoutDate,
          occurredAt: workout.startedAt,
          textData: _workoutText(workout),
          source: 'health:workout:${workout.id}',
          eventType: 'health_workout',
        );
        savedEvents++;
      }

      if (savedEvents > 0) {
        ref.invalidate(todayViewModelProvider);
        ref.invalidate(entriesViewModelProvider);
      }

      final eventWord = savedEvents == 1 ? 'event' : 'events';
      return HealthIntegrationState(
        HealthIntegrationStage.connected,
        savedEvents == 0
            ? 'Connected · no health activity yet today'
            : 'Connected · $savedEvents health $eventWord updated today',
      );
    } on HealthServiceException catch (error) {
      return HealthIntegrationState(
        HealthIntegrationStage.unavailable,
        error.message,
      );
    } catch (_) {
      return const HealthIntegrationState(
        HealthIntegrationStage.error,
        'Health data could not be updated',
      );
    }
  }

  // Keeps the Settings toggle off when setup is cancelled or fails.
  Future<void> _saveDisabledSetting() async {
    final settings = await ref.read(settingsViewModelProvider.future);
    if (!settings.healthIntegrationEnabled) return;
    await ref
        .read(settingsViewModelProvider.notifier)
        .setHealthIntegrationEnabled(false);
  }

  // Builds a short timeline sentence for one workout.
  static String _workoutText(HealthWorkoutRecord workout) {
    final duration = workout.endedAt.difference(workout.startedAt);
    final minutes = duration.inMinutes < 1 ? 1 : duration.inMinutes;
    return 'Completed a $minutes-minute ${workout.activityName} workout';
  }

  // Adds thousands separators without bringing formatting logic into the UI.
  static String _formatNumber(int number) {
    final digits = number.toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}
