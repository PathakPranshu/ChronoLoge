import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/services/media_encryption_provider.dart';

final diaryViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<DiaryViewModel, DiaryViewState, String>(DiaryViewModel.new);

/// Everything needed to draw the read-only Timeline tab.
class DiaryViewState {
  const DiaryViewState({required this.timelineItems});

  final List<DiaryTimelineItem> timelineItems;
}

/// A database timeline row converted into values the UI can display.
class DiaryTimelineItem {
  const DiaryTimelineItem({
    required this.id,
    required this.occurredAt,
    required this.text,
    required this.mood,
    required this.imageLocations,
    required this.voiceMemoLocations,
    required this.locationLabel,
    required this.weatherLabel,
    required this.eventType,
  });

  final int id;
  final DateTime occurredAt;
  final String text;
  final String mood;
  final List<String> imageLocations;
  final List<String> voiceMemoLocations;
  final String locationLabel;
  final String weatherLabel;
  final String eventType;

  factory DiaryTimelineItem.fromMap(Map<String, Object?> map) {
    final media = (map['media'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>();
    return DiaryTimelineItem(
      id: map['id'] as int? ?? 0,
      occurredAt:
          DateTime.tryParse(map['occurred_at'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      text: map['text_data'] as String? ?? '',
      mood: map['mood'] as String? ?? '',
      imageLocations: media
          .where((item) => item['type'] == DiaryMediaTable.imageType)
          .map((item) => item['location'])
          .whereType<String>()
          .toList(growable: false),
      voiceMemoLocations: media
          .where((item) => item['type'] == DiaryMediaTable.voiceMemoType)
          .map((item) => item['location'])
          .whereType<String>()
          .toList(growable: false),
      locationLabel: map['location_label'] as String? ?? '',
      weatherLabel: map['weather_label'] as String? ?? '',
      eventType: map['event_type'] as String? ?? '',
    );
  }
}

/// Loads a single day's automatic timeline from SQLite.
class DiaryViewModel extends AsyncNotifier<DiaryViewState> {
  DiaryViewModel(this.dateKey);

  final String dateKey;

  @override
  Future<DiaryViewState> build() async {
    final rows = await ref
        .watch(diaryDatabaseProvider)
        .getTimelineItems(dateKey);
    final items = rows.map(DiaryTimelineItem.fromMap).toList(growable: false);
    await ref.read(mediaEncryptionServiceProvider).encryptFiles([
      for (final item in items) ...item.imageLocations,
      for (final item in items) ...item.voiceMemoLocations,
    ]);
    return DiaryViewState(timelineItems: items);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
