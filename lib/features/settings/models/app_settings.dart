enum TemperatureUnit { celsius, fahrenheit }

enum DistanceUnit { kilometers, miles }

enum TimeFormat { hour24, hour12 }

/// A simple in-memory copy of every setting used by the UI.
class AppSettings {
  const AppSettings({
    this.isDarkMode = false,
    this.accentColorValue = defaultAccentColorValue,
    this.backupsEnabled = false,
    this.newsInterests = const [],
    this.temperatureUnit = TemperatureUnit.celsius,
    this.distanceUnit = DistanceUnit.kilometers,
    this.timeFormat = TimeFormat.hour24,
    this.automaticTrackingEnabled = true,
    this.healthIntegrationEnabled = false,
    this.notificationsEnabled = false,
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
    this.newPlacePromptsEnabled = true,
  });

  static const defaultAccentColorValue = 0xffa2391a;

  final bool isDarkMode;
  final int accentColorValue;
  final bool backupsEnabled;
  final List<String> newsInterests;
  final TemperatureUnit temperatureUnit;
  final DistanceUnit distanceUnit;
  final TimeFormat timeFormat;
  final bool automaticTrackingEnabled;
  final bool healthIntegrationEnabled;
  final bool notificationsEnabled;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final bool newPlacePromptsEnabled;

  AppSettings copyWith({
    bool? isDarkMode,
    int? accentColorValue,
    bool? backupsEnabled,
    List<String>? newsInterests,
    TemperatureUnit? temperatureUnit,
    DistanceUnit? distanceUnit,
    TimeFormat? timeFormat,
    bool? automaticTrackingEnabled,
    bool? healthIntegrationEnabled,
    bool? notificationsEnabled,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? newPlacePromptsEnabled,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      backupsEnabled: backupsEnabled ?? this.backupsEnabled,
      newsInterests: newsInterests ?? this.newsInterests,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      timeFormat: timeFormat ?? this.timeFormat,
      automaticTrackingEnabled:
          automaticTrackingEnabled ?? this.automaticTrackingEnabled,
      healthIntegrationEnabled:
          healthIntegrationEnabled ?? this.healthIntegrationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      newPlacePromptsEnabled:
          newPlacePromptsEnabled ?? this.newPlacePromptsEnabled,
    );
  }
}
