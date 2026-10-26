import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';
import 'notification_service.dart';

const _notificationSettingKey = 'daily_reminders_enabled';

final dailyRemindersEnabledProvider =
    NotifierProvider<DailyRemindersController, bool>(
      DailyRemindersController.new,
    );

class DailyRemindersController extends Notifier<bool> {
  @override
  bool build() {
    _loadSavedPreference();
    return true;
  }

  Future<void> _loadSavedPreference() async {
    try {
      final database = ref.read(settingsDatabaseProvider);
      final savedValue = await database.getSetting(_notificationSettingKey);

      if (!ref.mounted) return;

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
    final database = ref.read(settingsDatabaseProvider);
    final previousValue = state;

    try {
      final existingValue = await database.getSetting(_notificationSettingKey);

      if (existingValue == null) {
        await database.addSetting(_notificationSettingKey, enabled.toString());
      } else {
        await database.changeSetting(
          _notificationSettingKey,
          enabled.toString(),
        );
      }

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
