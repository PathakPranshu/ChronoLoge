import 'dart:io';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'open_meteo_weather_service.dart';

class WeatherLocation {
  const WeatherLocation({
    required this.location,
    required this.weather,
    this.latitude,
    this.longitude,
  });

  final String location;
  final String weather;
  final double? latitude;
  final double? longitude;
}

class WeatherLocationService {
  const WeatherLocationService();

  static const _weatherService = OpenMeteoWeatherService();

  Future<WeatherLocation> loadCurrent({bool useFahrenheit = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return const WeatherLocation(
        location: 'Location unavailable',
        weather: 'Weather unavailable',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return const WeatherLocation(
        location: 'Location is turned off',
        weather: 'Weather unavailable',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const WeatherLocation(
        location: 'Location permission needed',
        weather: 'Weather unavailable',
      );
    }

    late final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return const WeatherLocation(
        location: 'Location unavailable',
        weather: 'Weather unavailable',
      );
    }

    final location = await _locationName(position);
    try {
      final weather = await _weatherService.loadCurrent(
        latitude: position.latitude,
        longitude: position.longitude,
        useFahrenheit: useFahrenheit,
      );
      return WeatherLocation(
        location: location,
        weather: weather.summary,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return WeatherLocation(
        location: location,
        weather: 'Weather unavailable',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  Future<WeatherLocation> loadHistorical({
    required double latitude,
    required double longitude,
    required DateTime at,
    bool useFahrenheit = false,
  }) async {
    try {
      final results = await Future.wait([
        _locationNameFromCoordinates(latitude, longitude),
        _weatherService.loadHistorical(
          latitude: latitude,
          longitude: longitude,
          at: at,
          useFahrenheit: useFahrenheit,
        ),
      ]);
      final weather = results[1] as OpenMeteoWeather;
      return WeatherLocation(
        location: results[0] as String,
        weather: weather.summary,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return const WeatherLocation(
        location: 'Location unavailable',
        weather: 'Historical weather unavailable',
      );
    }
  }

  Future<String> _locationName(Position position) async {
    return _locationNameFromCoordinates(position.latitude, position.longitude);
  }

  Future<String> _locationNameFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city = _firstNotEmpty([
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ]);
        final region = _firstNotEmpty([
          place.administrativeArea,
          place.country,
        ]);
        final parts = <String>{?city, ?region};
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // Coordinate text below is still useful when reverse geocoding fails.
    }

    return '${latitude.toStringAsFixed(2)}, '
        '${longitude.toStringAsFixed(2)}';
  }

  String? _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
