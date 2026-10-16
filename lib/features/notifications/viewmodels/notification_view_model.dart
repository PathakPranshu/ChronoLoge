import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../settings/viewmodels/settings_view_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final notificationViewModelProvider =
    AsyncNotifierProvider<NotificationViewModel, NotificationState>(
      NotificationViewModel.new,
    );

enum NotificationStatus { disabled, ready, busy, permissionDenied, error }

/// The short status shown beneath the main notification switch.
class NotificationState {
  const NotificationState(this.status, this.message);

  const NotificationState.disabled()
    : this(NotificationStatus.disabled, 'Notifications are off');

  final NotificationStatus status;
  final String message;

  bool get isBusy => status == NotificationStatus.busy;
}

/// Connects notification settings to the Android and iOS notification service.
class NotificationViewModel extends AsyncNotifier<NotificationState> {
  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  Future<NotificationState> build() async {
    try {
      await _service.initialize();
      final settings = await ref.read(settingsViewModelProvider.future);
      if (!settings.notificationsEnabled) {
        await _service.cancelDailyReminder();
        return const NotificationState.disabled();
      }
      await _applyDailyReminder();
      return const NotificationState(
        NotificationStatus.ready,
        'Notifications are enabled',
      );
    } catch (_) {
      return const NotificationState(
        NotificationStatus.error,
        'Notifications could not be initialized',
      );
    }
  }

  // Enables notifications after permission is granted, or disables them.
  Future<void> setNotificationsEnabled(bool enabled) async {
    state = const AsyncData(
      NotificationState(NotificationStatus.busy, 'Updating notifications...'),
    );
    try {
      if (enabled && !await _service.requestPermission()) {
        await ref
            .read(settingsViewModelProvider.notifier)
            .setNotificationsEnabled(false);
        state = const AsyncData(
          NotificationState(
            NotificationStatus.permissionDenied,
            'Permission was not granted. You can enable it in device settings.',
          ),
        );
        return;
      }

      await ref
          .read(settingsViewModelProvider.notifier)
          .setNotificationsEnabled(enabled);
      if (enabled) {
        await _applyDailyReminder();
        state = const AsyncData(
          NotificationState(
            NotificationStatus.ready,
            'Notifications are enabled',
          ),
        );
      } else {
        await _service.cancelDailyReminder();
        state = const AsyncData(NotificationState.disabled());
      }
    } catch (_) {
      state = const AsyncData(
        NotificationState(
          NotificationStatus.error,
          'Notifications could not be updated',
        ),
      );
    }
  }

  // Turns the daily reminder on or off.
  Future<void> setDailyReminderEnabled(bool enabled) async {
    await ref
        .read(settingsViewModelProvider.notifier)
        .setDailyReminderEnabled(enabled);
    await _applyDailyReminder();
  }

  // Reschedules the daily reminder for a new local time.
  Future<void> setDailyReminderTime(int hour, int minute) async {
    await ref
        .read(settingsViewModelProvider.notifier)
        .setDailyReminderTime(hour: hour, minute: minute);
    await _applyDailyReminder();
  }

  // Saves whether newly visited places may trigger memory prompts.
  Future<void> setNewPlacePromptsEnabled(bool enabled) {
    return ref
        .read(settingsViewModelProvider.notifier)
        .setNewPlacePromptsEnabled(enabled);
  }

  Future<void> _applyDailyReminder() async {
    final settings = await ref.read(settingsViewModelProvider.future);
    if (!settings.notificationsEnabled || !settings.dailyReminderEnabled) {
      await _service.cancelDailyReminder();
      return;
    }
    await _service.scheduleDailyReminder(
      hour: settings.dailyReminderHour,
      minute: settings.dailyReminderMinute,
    );
  }
}
