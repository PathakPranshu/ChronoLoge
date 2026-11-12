import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/settings_database.dart';
import '../models/app_settings.dart';

final settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, AppSettings>(
      SettingsViewModel.new,
    );

/// Loads settings from SQLite and updates one setting at a time.
class SettingsViewModel extends AsyncNotifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _accentKey = 'accent_color';
  static const _backupsKey = 'backups_enabled';
  static const _newsInterestsKey = 'news_interests';
  static const _temperatureUnitKey = 'temperature_unit';
  static const _distanceUnitKey = 'distance_unit';
  static const _timeFormatKey = 'time_format';
  static const _automaticTrackingKey = 'automatic_tracking_enabled';
  static const _healthIntegrationKey = 'health_integration_enabled';
  static const _notificationsKey = 'notifications_enabled';
  static const _dailyReminderKey = 'daily_reminder_enabled';
  static const _dailyReminderHourKey = 'daily_reminder_hour';
  static const _dailyReminderMinuteKey = 'daily_reminder_minute';
  static const _newPlacePromptsKey = 'new_place_prompts_enabled';

  SettingsDatabase get _database => ref.read(settingsDatabaseProvider);

  @override
  Future<AppSettings> build() async {
    final database = ref.watch(settingsDatabaseProvider);
    final values = await Future.wait([
      database.getSetting(_themeKey),
      database.getSetting(_accentKey),
      database.getSetting(_backupsKey),
      database.getSetting(_newsInterestsKey),
      database.getSetting(_temperatureUnitKey),
      database.getSetting(_distanceUnitKey),
      database.getSetting(_timeFormatKey),
      database.getSetting(_automaticTrackingKey),
      database.getSetting(_healthIntegrationKey),
      database.getSetting(_notificationsKey),
      database.getSetting(_dailyReminderKey),
      database.getSetting(_dailyReminderHourKey),
      database.getSetting(_dailyReminderMinuteKey),
      database.getSetting(_newPlacePromptsKey),
    ]);

    return AppSettings(
      isDarkMode: values[0] == 'dark',
      accentColorValue:
          int.tryParse(values[1] ?? '') ?? AppSettings.defaultAccentColorValue,
      backupsEnabled: values[2] == 'true',
      newsInterests: _decodeNewsInterests(values[3]),
      temperatureUnit: values[4] == 'fahrenheit'
          ? TemperatureUnit.fahrenheit
          : TemperatureUnit.celsius,
      distanceUnit: values[5] == 'miles'
          ? DistanceUnit.miles
          : DistanceUnit.kilometers,
      timeFormat: values[6] == '12_hour'
          ? TimeFormat.hour12
          : TimeFormat.hour24,
      automaticTrackingEnabled: values[7] != 'false',
      healthIntegrationEnabled: values[8] == 'true',
      notificationsEnabled: values[9] == 'true',
      dailyReminderEnabled: values[10] != 'false',
      dailyReminderHour: _validHour(values[11]),
      dailyReminderMinute: _validMinute(values[12]),
      newPlacePromptsEnabled: values[13] != 'false',
    );
  }

  Future<void> setDarkMode(bool enabled) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isDarkMode: enabled));
    try {
      await _writeSetting(_themeKey, enabled ? 'dark' : 'light');
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> setAccentColor(int colorValue) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(accentColorValue: colorValue));
    try {
      await _writeSetting(_accentKey, colorValue.toString());
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> setBackupsEnabled(bool enabled) async {
    final current = state.requireValue;
    await _writeSetting(_backupsKey, enabled.toString());
    state = AsyncData(current.copyWith(backupsEnabled: enabled));
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    await _writeSetting(
      _temperatureUnitKey,
      unit == TemperatureUnit.fahrenheit ? 'fahrenheit' : 'celsius',
    );
    state = AsyncData(state.requireValue.copyWith(temperatureUnit: unit));
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    await _writeSetting(
      _distanceUnitKey,
      unit == DistanceUnit.miles ? 'miles' : 'kilometers',
    );
    state = AsyncData(state.requireValue.copyWith(distanceUnit: unit));
  }

  Future<void> setTimeFormat(TimeFormat format) async {
    await _writeSetting(
      _timeFormatKey,
      format == TimeFormat.hour12 ? '12_hour' : '24_hour',
    );
    state = AsyncData(state.requireValue.copyWith(timeFormat: format));
  }

  Future<void> setAutomaticTrackingEnabled(bool enabled) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(automaticTrackingEnabled: enabled));
    try {
      await _writeSetting(_automaticTrackingKey, enabled.toString());
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  // Saves whether ChronoLoge may import steps and workouts.
  Future<void> setHealthIntegrationEnabled(bool enabled) async {
    await _writeSetting(_healthIntegrationKey, enabled.toString());
    state = AsyncData(
      state.requireValue.copyWith(healthIntegrationEnabled: enabled),
    );
  }

  // Saves the master notification preference.
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _writeSetting(_notificationsKey, enabled.toString());
    state = AsyncData(
      state.requireValue.copyWith(notificationsEnabled: enabled),
    );
  }

  // Saves whether the daily diary reminder should be scheduled.
  Future<void> setDailyReminderEnabled(bool enabled) async {
    await _writeSetting(_dailyReminderKey, enabled.toString());
    state = AsyncData(
      state.requireValue.copyWith(dailyReminderEnabled: enabled),
    );
  }

  // Saves the user's preferred local reminder time.
  Future<void> setDailyReminderTime({
    required int hour,
    required int minute,
  }) async {
    await Future.wait([
      _writeSetting(_dailyReminderHourKey, hour.toString()),
      _writeSetting(_dailyReminderMinuteKey, minute.toString()),
    ]);
    state = AsyncData(
      state.requireValue.copyWith(
        dailyReminderHour: hour,
        dailyReminderMinute: minute,
      ),
    );
  }

  // Saves whether first visits may show a photo prompt.
  Future<void> setNewPlacePromptsEnabled(bool enabled) async {
    await _writeSetting(_newPlacePromptsKey, enabled.toString());
    state = AsyncData(
      state.requireValue.copyWith(newPlacePromptsEnabled: enabled),
    );
  }

  Future<void> addNewsInterest(String interest) async {
    final cleanInterest = interest.trim();
    if (cleanInterest.isEmpty) return;

    final current = state.requireValue;
    final alreadyExists = current.newsInterests.any(
      (item) => item.toLowerCase() == cleanInterest.toLowerCase(),
    );
    if (alreadyExists) return;

    await _setNewsInterests([...current.newsInterests, cleanInterest]);
  }

  Future<void> removeNewsInterest(String interest) async {
    final current = state.requireValue;
    await _setNewsInterests(
      current.newsInterests.where((item) => item != interest).toList(),
    );
  }

  Future<void> _setNewsInterests(List<String> interests) async {
    await _writeSetting(_newsInterestsKey, jsonEncode(interests));
    state = AsyncData(state.requireValue.copyWith(newsInterests: interests));
  }

  Future<void> _writeSetting(String name, String value) async {
    await _database.setSetting(name, value);
  }

  static List<String> _decodeNewsInterests(String? storedValue) {
    if (storedValue == null || storedValue.isEmpty) return const [];
    try {
      final decoded = jsonDecode(storedValue);
      if (decoded is! List<dynamic>) return const [];
      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  static int _validHour(String? value) {
    final hour = int.tryParse(value ?? '');
    return hour != null && hour >= 0 && hour <= 23 ? hour : 20;
  }

  static int _validMinute(String? value) {
    final minute = int.tryParse(value ?? '');
    return minute != null && minute >= 0 && minute <= 59 ? minute : 0;
  }
}
