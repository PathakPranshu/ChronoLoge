import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_service.dart';
import 'settings_provider.dart';

const _notificationSettingKey = 'daily_reminders_enabled';

final dailyRemindersEnabledProvider =
    NotifierProvider<DailyRemindersController, bool>(
      DailyRemindersController.new,
    );

class DailyRemindersController extends Notifier<bool> {
  bool _hasUserChanged = false;

  @override
  bool build() {
    _loadSavedPreference();
    return true;
  }

  Future<void> _loadSavedPreference() async {
    try {
      final repository = ref.read(settingsRepositoryProvider);
      final savedValue = await repository.getSetting(_notificationSettingKey);

      if (!ref.mounted || _hasUserChanged) return;

      final enabled = savedValue != 'false';
      state = enabled;

      if (enabled) {
        await NotificationService.instance.scheduleDailyPrompt();
      } else {
        await NotificationService.instance.cancelDailyPrompt();
      }
    } catch (_) {
      // Keep the default preference if loading fails.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _hasUserChanged = true;

    final previousValue = state;

    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveSetting(_notificationSettingKey, enabled.toString());

      state = enabled;

      if (enabled) {
        await NotificationService.instance.scheduleDailyPrompt();
      } else {
        await NotificationService.instance.cancelDailyPrompt();
      }
    } catch (_) {
      state = previousValue;
      rethrow;
    }
  }
}
