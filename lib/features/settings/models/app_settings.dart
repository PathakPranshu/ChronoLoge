enum TemperatureUnit { celsius, fahrenheit }

enum DistanceUnit { kilometers, miles }

enum TimeFormat { hour24, hour12 }

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

  AppSettings copyWith({
    bool? isDarkMode,
    int? accentColorValue,
    bool? backupsEnabled,
    List<String>? newsInterests,
    TemperatureUnit? temperatureUnit,
    DistanceUnit? distanceUnit,
    TimeFormat? timeFormat,
    bool? automaticTrackingEnabled,
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
    );
  }
}
