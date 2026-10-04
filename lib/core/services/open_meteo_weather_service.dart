import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenMeteoWeather {
  const OpenMeteoWeather({
    required this.observedAt,
    required this.temperature,
    required this.apparentTemperature,
    required this.precipitation,
    required this.cloudCover,
    required this.windSpeed,
    required this.weatherCode,
    required this.temperatureUnit,
  });

  final DateTime observedAt;
  final double temperature;
  final double apparentTemperature;
  final double precipitation;
  final double cloudCover;
  final double windSpeed;
  final int weatherCode;
  final String temperatureUnit;

  String get condition => OpenMeteoWeatherService.weatherLabel(weatherCode);

  String get summary => '$condition • ${temperature.round()}$temperatureUnit';
}

class OpenMeteoWeatherService {
  const OpenMeteoWeatherService();

  static const _currentHost = 'api.open-meteo.com';
  static const _historicalHost = 'historical-forecast-api.open-meteo.com';
  static const _variables =
      'temperature_2m,apparent_temperature,precipitation,weather_code,'
      'cloud_cover,wind_speed_10m';

  Future<OpenMeteoWeather> loadCurrent({
    required double latitude,
    required double longitude,
    bool useFahrenheit = false,
  }) async {
    final uri = Uri.https(_currentHost, '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': _variables,
      'temperature_unit': useFahrenheit ? 'fahrenheit' : 'celsius',
      'wind_speed_unit': 'kmh',
      'timezone': 'auto',
    });
    final body = await _getJson(uri);
    final current = body['current'] as Map<String, dynamic>?;
    if (current == null) throw const OpenMeteoException();

    return _weatherFromCurrent(
      current,
      temperatureUnit: useFahrenheit ? '°F' : '°C',
    );
  }

  Future<OpenMeteoWeather> loadHistorical({
    required double latitude,
    required double longitude,
    required DateTime at,
    bool useFahrenheit = false,
  }) async {
    final date = _dateKey(at);
    final uri = Uri.https(_historicalHost, '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'start_date': date,
      'end_date': date,
      'hourly': _variables,
      'temperature_unit': useFahrenheit ? 'fahrenheit' : 'celsius',
      'wind_speed_unit': 'kmh',
      'timezone': 'auto',
    });
    final body = await _getJson(uri);
    final hourly = body['hourly'] as Map<String, dynamic>?;
    if (hourly == null) throw const OpenMeteoException();

    final times = _list(hourly['time']);
    if (times.isEmpty) throw const OpenMeteoException();
    final targetHour = at.hour.toString().padLeft(2, '0');
    final targetTime = '${_dateKey(at)}T$targetHour:00';
    final index = times.indexOf(targetTime);
    final selectedIndex = index < 0
        ? at.hour.clamp(0, times.length - 1)
        : index;

    return OpenMeteoWeather(
      observedAt: DateTime.tryParse(times[selectedIndex].toString()) ?? at,
      temperature: _numberAt(hourly, 'temperature_2m', selectedIndex),
      apparentTemperature: _numberAt(
        hourly,
        'apparent_temperature',
        selectedIndex,
      ),
      precipitation: _numberAt(hourly, 'precipitation', selectedIndex),
      cloudCover: _numberAt(hourly, 'cloud_cover', selectedIndex),
      windSpeed: _numberAt(hourly, 'wind_speed_10m', selectedIndex),
      weatherCode: _numberAt(hourly, 'weather_code', selectedIndex).round(),
      temperatureUnit: useFahrenheit ? '°F' : '°C',
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw const OpenMeteoException();
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const OpenMeteoException();
    return decoded;
  }

  OpenMeteoWeather _weatherFromCurrent(
    Map<String, dynamic> current, {
    required String temperatureUnit,
  }) {
    return OpenMeteoWeather(
      observedAt:
          DateTime.tryParse(current['time'] as String? ?? '') ?? DateTime.now(),
      temperature: _number(current['temperature_2m']),
      apparentTemperature: _number(current['apparent_temperature']),
      precipitation: _number(current['precipitation']),
      cloudCover: _number(current['cloud_cover']),
      windSpeed: _number(current['wind_speed_10m']),
      weatherCode: _number(current['weather_code']).round(),
      temperatureUnit: temperatureUnit,
    );
  }

  double _numberAt(Map<String, dynamic> values, String key, int index) {
    final items = _list(values[key]);
    if (index >= items.length) throw const OpenMeteoException();
    return _number(items[index]);
  }

  List<dynamic> _list(Object? value) {
    if (value is! List<dynamic>) throw const OpenMeteoException();
    return value;
  }

  double _number(Object? value) {
    if (value is! num) throw const OpenMeteoException();
    return value.toDouble();
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String weatherLabel(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly cloudy';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorms';
    return 'Current weather';
  }
}

class OpenMeteoException implements Exception {
  const OpenMeteoException();
}
