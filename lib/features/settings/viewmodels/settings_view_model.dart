import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/settings_database.dart';
import '../models/app_settings.dart';

final settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, AppSettings>(
      SettingsViewModel.new,
    );

class SettingsViewModel extends AsyncNotifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _accentKey = 'accent_color';
  static const _backupsKey = 'backups_enabled';
  static const _newsInterestsKey = 'news_interests';
  static const _temperatureUnitKey = 'temperature_unit';
  static const _distanceUnitKey = 'distance_unit';
  static const _timeFormatKey = 'time_format';
  static const _automaticTrackingKey = 'automatic_tracking_enabled';

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
    );
  }

  Future<void> setDarkMode(bool enabled) async {
    final current = state.requireValue;
    await _writeSetting(_themeKey, enabled ? 'dark' : 'light');
    state = AsyncData(current.copyWith(isDarkMode: enabled));
  }

  Future<void> setAccentColor(int colorValue) async {
    final current = state.requireValue;
    await _writeSetting(_accentKey, colorValue.toString());
    state = AsyncData(current.copyWith(accentColorValue: colorValue));
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
    await _writeSetting(_automaticTrackingKey, enabled.toString());
    state = AsyncData(
      state.requireValue.copyWith(automaticTrackingEnabled: enabled),
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
    if (await _database.getSetting(name) == null) {
      await _database.addSetting(name, value);
    } else {
      await _database.changeSetting(name, value);
    }
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
}
