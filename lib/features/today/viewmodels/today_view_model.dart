import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/diary_database.dart';
import '../../../core/database/settings_database.dart';
import '../../../core/services/media_encryption_provider.dart';
import '../../../core/services/media_encryption_service.dart';
import '../../../core/services/weather_location_service.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/viewmodels/settings_view_model.dart';

final todayViewModelProvider =
    AsyncNotifierProvider<TodayViewModel, TodayState>(TodayViewModel.new);

class TimelineItem {
  const TimelineItem({
    required this.id,
    required this.occurredAt,
    required this.text,
    required this.mood,
    required this.imageLocations,
    required this.voiceMemoLocations,
    required this.source,
    required this.locationLabel,
    required this.weatherLabel,
  });

  final int id;
  final DateTime occurredAt;
  final String text;
  final String mood;
  final List<String> imageLocations;
  final List<String> voiceMemoLocations;
  final String source;
  final String locationLabel;
  final String weatherLabel;
}

class TodayState {
  const TodayState({
    required this.dateKey,
    required this.dateLabel,
    required this.title,
    required this.text,
    required this.mood,
    required this.imageLocations,
    required this.voiceMemoLocations,
    required this.timelineItems,
    this.isAutomaticMode = true,
    this.locationLabel = 'Finding your location...',
    this.weatherLabel = 'Loading weather...',
    this.latitude,
    this.longitude,
    this.isSavingText = false,
    this.isPickingImages = false,
    this.isAddingSnippet = false,
  });

  final String dateKey;
  final String dateLabel;
  final String title;
  final String text;
  final String mood;
  final List<String> imageLocations;
  final List<String> voiceMemoLocations;
  final List<TimelineItem> timelineItems;
  final bool isAutomaticMode;
  final String locationLabel;
  final String weatherLabel;
  final double? latitude;
  final double? longitude;
  final bool isSavingText;
  final bool isPickingImages;
  final bool isAddingSnippet;

  TodayState copyWith({
    String? title,
    String? text,
    String? mood,
    List<String>? imageLocations,
    List<String>? voiceMemoLocations,
    List<TimelineItem>? timelineItems,
    bool? isAutomaticMode,
    String? locationLabel,
    String? weatherLabel,
    double? latitude,
    double? longitude,
    bool? isSavingText,
    bool? isPickingImages,
    bool? isAddingSnippet,
  }) {
    return TodayState(
      dateKey: dateKey,
      dateLabel: dateLabel,
      title: title ?? this.title,
      text: text ?? this.text,
      mood: mood ?? this.mood,
      imageLocations: imageLocations ?? this.imageLocations,
      voiceMemoLocations: voiceMemoLocations ?? this.voiceMemoLocations,
      timelineItems: timelineItems ?? this.timelineItems,
      isAutomaticMode: isAutomaticMode ?? this.isAutomaticMode,
      locationLabel: locationLabel ?? this.locationLabel,
      weatherLabel: weatherLabel ?? this.weatherLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isSavingText: isSavingText ?? this.isSavingText,
      isPickingImages: isPickingImages ?? this.isPickingImages,
      isAddingSnippet: isAddingSnippet ?? this.isAddingSnippet,
    );
  }
}

class TodayViewModel extends AsyncNotifier<TodayState> {
  static const _diaryModeSetting = 'diary_mode';
  static const _mediaEncryptionMigrationSetting =
      'media_encryption_migrated_v1';

  final ImagePicker _imagePicker = ImagePicker();
  final WeatherLocationService _weatherLocationService =
      const WeatherLocationService();

  DiaryDatabase get _database => ref.read(diaryDatabaseProvider);
  MediaEncryptionService get _mediaEncryption =>
      ref.read(mediaEncryptionServiceProvider);

  @override
  Future<TodayState> build() async {
    final today = DateTime.now();
    final dateKey = _dateKey(today);
    final settingsDatabase = ref.watch(settingsDatabaseProvider);
    final temperatureUnit = ref.watch(
      settingsViewModelProvider.select(
        (settings) =>
            settings.value?.temperatureUnit ?? TemperatureUnit.celsius,
      ),
    );
    await _recoverLostImages(dateKey);
    await _encryptLegacyMedia(settingsDatabase);
    final todayState = await _loadToday(dateKey, today);
    final storedMode = await settingsDatabase.getSetting(_diaryModeSetting);
    unawaited(_loadWeatherAfterBuild(dateKey, temperatureUnit));
    return todayState.copyWith(isAutomaticMode: storedMode != 'manual');
  }

  Future<void> saveText(String text) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(text: text, isSavingText: true));
    try {
      await _database.changeText(current.dateKey, text);
      final latest = state.requireValue;
      state = AsyncData(latest.copyWith(text: text, isSavingText: false));
    } catch (_) {
      final latest = state.requireValue;
      state = AsyncData(latest.copyWith(isSavingText: false));
      rethrow;
    }
  }

  Future<void> saveManualContent({
    required String title,
    required String text,
  }) async {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(title: title, text: text, isSavingText: true),
    );
    try {
      await _database.changeManualContent(
        current.dateKey,
        title: title.trim(),
        textData: text,
      );
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(title: title.trim(), text: text, isSavingText: false),
      );
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSavingText: false));
      rethrow;
    }
  }

  Future<void> addSnippet({
    required DateTime occurredAt,
    required String text,
    required String mood,
    required List<XFile> images,
    required List<String> voiceMemoLocations,
    required String locationLabel,
    required String weatherLabel,
  }) async {
    final current = state.requireValue;
    if (current.isAddingSnippet) return;

    state = AsyncData(current.copyWith(isAddingSnippet: true));
    final storedImages = <String>[];
    var savedToDatabase = false;
    try {
      storedImages.addAll(await _copySnippetImages(current.dateKey, images));
      await _mediaEncryption.encryptFiles(voiceMemoLocations);
      await _database.addTimelineItem(
        current.dateKey,
        occurredAt: occurredAt,
        textData: text.trim(),
        mood: mood,
        imageLocations: storedImages,
        voiceMemoLocations: voiceMemoLocations,
        locationLabel: _usableContextLabel(locationLabel),
        weatherLabel: _usableContextLabel(weatherLabel),
      );
      savedToDatabase = true;
      await _reloadEntry(current.dateKey);
    } catch (_) {
      if (!savedToDatabase) {
        for (final location in [...storedImages, ...voiceMemoLocations]) {
          await _deleteFileIfPresent(location);
        }
      }
      final latest = state.value;
      if (latest != null) {
        state = AsyncData(latest.copyWith(isAddingSnippet: false));
      }
      rethrow;
    }
  }

  Future<void> updateSnippet({
    required TimelineItem original,
    required String text,
    required String mood,
    required List<String> retainedImageLocations,
    required List<XFile> newImages,
    required List<String> retainedVoiceMemoLocations,
    required List<String> newVoiceMemoLocations,
  }) async {
    final current = state.requireValue;
    if (current.isAddingSnippet) return;

    state = AsyncData(current.copyWith(isAddingSnippet: true));
    final copiedImages = <String>[];
    var savedToDatabase = false;
    try {
      copiedImages.addAll(await _copySnippetImages(current.dateKey, newImages));
      await _mediaEncryption.encryptFiles(newVoiceMemoLocations);
      final finalImages = [...retainedImageLocations, ...copiedImages];
      final finalVoiceMemos = [
        ...retainedVoiceMemoLocations,
        ...newVoiceMemoLocations,
      ];
      await _database.updateTimelineItem(
        original.id,
        date: current.dateKey,
        textData: text.trim(),
        mood: mood,
        imageLocations: finalImages,
        voiceMemoLocations: finalVoiceMemos,
      );
      savedToDatabase = true;

      final removedLocations = <String>[
        ...original.imageLocations.where(
          (location) => !retainedImageLocations.contains(location),
        ),
        ...original.voiceMemoLocations.where(
          (location) => !retainedVoiceMemoLocations.contains(location),
        ),
      ];
      for (final location in removedLocations) {
        await _deleteFileIfPresent(location);
      }
      await _reloadEntry(current.dateKey);
    } catch (_) {
      if (!savedToDatabase) {
        for (final location in [...copiedImages, ...newVoiceMemoLocations]) {
          await _deleteFileIfPresent(location);
        }
      }
      final latest = state.value;
      if (latest != null) {
        state = AsyncData(latest.copyWith(isAddingSnippet: false));
      }
      rethrow;
    }
  }

  Future<void> deleteSnippet(TimelineItem item) async {
    final current = state.requireValue;
    await _database.deleteTimelineItem(item.id, current.dateKey);
    for (final location in [
      ...item.imageLocations,
      ...item.voiceMemoLocations,
    ]) {
      await _deleteFileIfPresent(location);
    }
    await _reloadEntry(current.dateKey);
  }

  Future<void> setMood(String mood) async {
    final current = state.requireValue;
    await _database.changeMood(current.dateKey, mood);
    state = AsyncData(state.requireValue.copyWith(mood: mood));
  }

  Future<void> setAutomaticMode(bool isAutomatic) async {
    final settings = ref.read(settingsDatabaseProvider);
    final value = isAutomatic ? 'auto' : 'manual';
    if (await settings.getSetting(_diaryModeSetting) == null) {
      await settings.addSetting(_diaryModeSetting, value);
    } else {
      await settings.changeSetting(_diaryModeSetting, value);
    }
    state = AsyncData(
      state.requireValue.copyWith(isAutomaticMode: isAutomatic),
    );
  }

  Future<void> pickImages() async {
    final current = state.requireValue;
    if (current.isPickingImages) return;

    state = AsyncData(current.copyWith(isPickingImages: true));
    try {
      final images = await _imagePicker.pickMultiImage(
        limit: 10,
        requestFullMetadata: false,
      );
      if (images.isNotEmpty) {
        await _storePickedImages(current.dateKey, images);
      }
    } finally {
      await _reloadEntry(current.dateKey);
    }
  }

  Future<void> deleteImage(String imageLocation) async {
    final current = state.requireValue;
    await _database.deleteImage(current.dateKey, imageLocation);
    await _deleteFileIfPresent(imageLocation);
    await _reloadEntry(current.dateKey);
  }

  Future<void> deleteVoiceMemo(String audioLocation) async {
    final current = state.requireValue;
    await _database.deleteVoiceMemo(current.dateKey, audioLocation);
    await _deleteFileIfPresent(audioLocation);
    await _reloadEntry(current.dateKey);
  }

  Future<void> addVoiceMemo(String audioLocation) async {
    final current = state.requireValue;
    try {
      await _mediaEncryption.encryptFile(audioLocation);
      await _database.addVoiceMemo(current.dateKey, audioLocation);
    } catch (_) {
      await _deleteFileIfPresent(audioLocation);
      rethrow;
    }
    await _reloadEntry(current.dateKey);
  }

  void refresh() => ref.invalidateSelf();

  Future<void> _encryptLegacyMedia(SettingsDatabase settingsDatabase) async {
    if (await settingsDatabase.getSetting(_mediaEncryptionMigrationSetting) ==
        'true') {
      return;
    }
    await _mediaEncryption.encryptFiles(await _database.getAllMediaLocations());
    if (await settingsDatabase.getSetting(_mediaEncryptionMigrationSetting) ==
        null) {
      await settingsDatabase.addSetting(
        _mediaEncryptionMigrationSetting,
        'true',
      );
    } else {
      await settingsDatabase.changeSetting(
        _mediaEncryptionMigrationSetting,
        'true',
      );
    }
  }

  Future<void> _reloadEntry(String dateKey) async {
    final current = state.requireValue;
    final refreshed = await _loadToday(dateKey, DateTime.now());
    state = AsyncData(
      refreshed.copyWith(
        locationLabel: current.locationLabel,
        weatherLabel: current.weatherLabel,
        latitude: current.latitude,
        longitude: current.longitude,
        isAutomaticMode: current.isAutomaticMode,
        isSavingText: current.isSavingText,
      ),
    );
  }

  Future<TodayState> _loadToday(String dateKey, DateTime date) async {
    final entry = await _database.getEntry(dateKey, readOnly: true);
    final timelineRows = await _database.getTimelineItems(dateKey);
    final images = (entry?['images_loc'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final voiceMemos = (entry?['voice_memos_loc'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final timelineMedia = timelineRows.expand<String>((row) sync* {
      yield* (row['image_locations'] as List<Object?>).whereType<String>();
      yield* (row['voice_memo_locations'] as List<Object?>).whereType<String>();
    });
    await _mediaEncryption.encryptFiles([
      ...images,
      ...voiceMemos,
      ...timelineMedia,
    ]);

    return TodayState(
      dateKey: dateKey,
      dateLabel: _formatDate(date),
      title: entry?['title'] as String? ?? '',
      text: entry?['text_data'] as String? ?? '',
      mood: entry?['mood'] as String? ?? '',
      imageLocations: images,
      voiceMemoLocations: voiceMemos,
      timelineItems: timelineRows
          .map(
            (row) => TimelineItem(
              id: row['id']! as int,
              occurredAt:
                  DateTime.tryParse(row['occurred_at']! as String)?.toLocal() ??
                  date,
              text: row['text_data'] as String? ?? '',
              mood: row['mood'] as String? ?? '',
              imageLocations: (row['image_locations'] as List<Object?>)
                  .whereType<String>()
                  .toList(growable: false),
              voiceMemoLocations: (row['voice_memo_locations'] as List<Object?>)
                  .whereType<String>()
                  .toList(growable: false),
              source: row['source'] as String? ?? 'snippet',
              locationLabel: row['location_label'] as String? ?? '',
              weatherLabel: row['weather_label'] as String? ?? '',
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _loadWeatherAfterBuild(
    String dateKey,
    TemperatureUnit temperatureUnit,
  ) async {
    await Future<void>.delayed(Duration.zero);
    final weatherLocation = await _weatherLocationService.loadCurrent(
      useFahrenheit: temperatureUnit == TemperatureUnit.fahrenheit,
    );
    final current = state.value;
    if (current == null || current.dateKey != dateKey) return;
    state = AsyncData(
      current.copyWith(
        locationLabel: weatherLocation.location,
        weatherLabel: weatherLocation.weather,
        latitude: weatherLocation.latitude,
        longitude: weatherLocation.longitude,
      ),
    );
  }

  Future<void> _recoverLostImages(String dateKey) async {
    if (!Platform.isAndroid) return;

    final lostData = await _imagePicker.retrieveLostData();
    final images = lostData.files;
    if (!lostData.isEmpty && images != null && images.isNotEmpty) {
      await _storePickedImages(dateKey, images);
    }
  }

  Future<void> _deleteFileIfPresent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The database reference is already removed, so an orphan is harmless.
    }
  }

  Future<void> _storePickedImages(String dateKey, List<XFile> images) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(
      path.join(documentsDirectory.path, 'diary_images', dateKey),
    );
    await imageDirectory.create(recursive: true);

    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final extension = path.extension(image.path).toLowerCase();
      final safeExtension = extension.isEmpty ? '.jpg' : extension;
      final fileName =
          '${DateTime.now().microsecondsSinceEpoch}_$index$safeExtension';
      final destination = path.join(imageDirectory.path, fileName);

      try {
        await image.saveTo(destination);
        await _mediaEncryption.encryptFile(destination);
        await _database.addImage(dateKey, destination);
      } catch (_) {
        final copiedFile = File(destination);
        if (await copiedFile.exists()) await copiedFile.delete();
        rethrow;
      }
    }
  }

  Future<List<String>> _copySnippetImages(
    String dateKey,
    List<XFile> images,
  ) async {
    if (images.isEmpty) return const [];

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(
      path.join(documentsDirectory.path, 'diary_images', dateKey, 'snippets'),
    );
    await imageDirectory.create(recursive: true);

    final storedLocations = <String>[];
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final extension = path.extension(image.path).toLowerCase();
      final safeExtension = extension.isEmpty ? '.jpg' : extension;
      final destination = path.join(
        imageDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}_$index$safeExtension',
      );
      try {
        await image.saveTo(destination);
        await _mediaEncryption.encryptFile(destination);
        storedLocations.add(destination);
      } catch (_) {
        await _deleteFileIfPresent(destination);
        rethrow;
      }
    }
    return storedLocations;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day}${_ordinalSuffix(date.day)} '
        '${months[date.month - 1]} ${date.year}';
  }

  String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    return switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }

  String _usableContextLabel(String label) {
    const unavailable = {
      'Finding your location...',
      'Loading weather...',
      'Location unavailable',
      'Weather unavailable',
      'Location permission needed',
      'Location is turned off',
    };
    return unavailable.contains(label) ? '' : label;
  }
}
