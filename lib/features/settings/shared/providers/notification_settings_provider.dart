import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_service.dart';
import 'settings_provider.dart';

class NotificationSettingsState {
  final bool isEnabled;
  final TimeOfDay reminderTime;

  const NotificationSettingsState({
    this.isEnabled = true,
    this.reminderTime = const TimeOfDay(
      hour: 20,
      minute: 0,
    ), // Default 08:00 PM
  });

  NotificationSettingsState copyWith({
    bool? isEnabled,
    TimeOfDay? reminderTime,
  }) {
    return NotificationSettingsState(
      isEnabled: isEnabled ?? this.isEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

final notificationSettingsProvider =
    AsyncNotifierProvider<
      NotificationSettingsNotifier,
      NotificationSettingsState
    >(NotificationSettingsNotifier.new);

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettingsState> {
  static const String _enabledKey = 'notifications_enabled';
  static const String _timeKey = 'notifications_reminder_time';

  @override
  FutureOr<NotificationSettingsState> build() async {
    final repo = ref.watch(settingsRepositoryProvider);

    final enabledRaw = await repo.getSetting(_enabledKey);
    final isEnabled = enabledRaw == null ? true : enabledRaw == 'true';

    final timeRaw = await repo.getSetting(_timeKey);
    final reminderTime = _parseTime(timeRaw);

    final settings = NotificationSettingsState(
      isEnabled: isEnabled,
      reminderTime: reminderTime,
    );

    if (settings.isEnabled) {
      final pending = await NotificationService.instance
          .getPendingNotifications();
      final hasDailyPrompt = pending.any((n) => n.content?.id == 100);
      if (!hasDailyPrompt) {
        await _syncSchedule(settings);
      }
    } else {
      await NotificationService.instance.cancelDailyPrompt();
    }
    return settings;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.value ?? const NotificationSettingsState();
    final updated = current.copyWith(isEnabled: enabled);

    state = AsyncData(updated);

    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.saveSetting(_enabledKey, enabled.toString());
      await _syncSchedule(updated);
    } catch (e, st) {
      state = AsyncData(current);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> setReminderTime(TimeOfDay newTime) async {
    final current = state.value ?? const NotificationSettingsState();
    if (current.reminderTime == newTime) return;

    final updated = current.copyWith(reminderTime: newTime);
    state = AsyncData(updated);

    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.saveSetting(_timeKey, _formatTimeForStorage(newTime));
      await _syncSchedule(updated);
    } catch (e, st) {
      state = AsyncData(current);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> _syncSchedule(NotificationSettingsState settings) async {
    if (settings.isEnabled) {
      await NotificationService.instance.scheduleDailyPrompt(
        hour: settings.reminderTime.hour,
        minute: settings.reminderTime.minute,
      );
    } else {
      await NotificationService.instance.cancelDailyPrompt();
    }
  }

  TimeOfDay _parseTime(String? raw) {
    if (raw == null || !raw.contains(':')) {
      return const TimeOfDay(hour: 20, minute: 0);
    }
    final parts = raw.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTimeForStorage(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
