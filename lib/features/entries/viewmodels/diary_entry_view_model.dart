import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_providers.dart';

final diaryEntryViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<DiaryEntryViewModel, DiaryEntryState, String>(
      DiaryEntryViewModel.new,
    );

class DiaryEntryState {
  const DiaryEntryState({
    required this.dateKey,
    required this.dateLabel,
    required this.title,
    required this.text,
    required this.mood,
    required this.imageLocations,
    required this.voiceMemoLocations,
    required this.exists,
    this.isAddingMedia = false,
    this.isSaving = false,
  });

  final String dateKey;
  final String dateLabel;
  final String title;
  final String text;
  final String mood;
  final List<String> imageLocations;
  final List<String> voiceMemoLocations;
  final bool exists;
  final bool isAddingMedia;
  final bool isSaving;

  DiaryEntryState copyWith({
    String? title,
    String? text,
    String? mood,
    List<String>? imageLocations,
    List<String>? voiceMemoLocations,
    bool? exists,
    bool? isAddingMedia,
    bool? isSaving,
  }) {
    return DiaryEntryState(
      dateKey: dateKey,
      dateLabel: dateLabel,
      title: title ?? this.title,
      text: text ?? this.text,
      mood: mood ?? this.mood,
      imageLocations: imageLocations ?? this.imageLocations,
      voiceMemoLocations: voiceMemoLocations ?? this.voiceMemoLocations,
      exists: exists ?? this.exists,
      isAddingMedia: isAddingMedia ?? this.isAddingMedia,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class DiaryEntryViewModel extends AsyncNotifier<DiaryEntryState> {
  DiaryEntryViewModel(this.dateKey);

  final String dateKey;
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _pendingImages = [];
  final List<String> _pendingVoiceMemos = [];

  @override
  Future<DiaryEntryState> build() async {
    ref.onDispose(() => unawaited(_discardPendingMedia()));
    final entry = await ref
        .watch(diaryDatabaseProvider)
        .getEntry(dateKey, readOnly: true);
    final date = DateTime.parse(dateKey);

    return DiaryEntryState(
      dateKey: dateKey,
      dateLabel: _formatDate(date),
      title: entry?['title'] as String? ?? '',
      text: entry?['text_data'] as String? ?? '',
      mood: entry?['mood'] as String? ?? '',
      imageLocations: (entry?['images_loc'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      voiceMemoLocations:
          (entry?['voice_memos_loc'] as List<Object?>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      exists: entry != null,
    );
  }

  void setMood(String mood) {
    state = AsyncData(state.requireValue.copyWith(mood: mood));
  }

  Future<void> pickImages() async {
    final current = state.requireValue;
    if (current.isAddingMedia) return;
    state = AsyncData(current.copyWith(isAddingMedia: true));

    try {
      final images = await _imagePicker.pickMultiImage(
        limit: 10,
        requestFullMetadata: false,
      );
      if (images.isEmpty) return;

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final imageDirectory = Directory(
        path.join(documentsDirectory.path, 'diary_images', dateKey),
      );
      await imageDirectory.create(recursive: true);
      for (var index = 0; index < images.length; index++) {
        final image = images[index];
        final extension = path.extension(image.path).toLowerCase();
        final destination = path.join(
          imageDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}_$index'
          '${extension.isEmpty ? '.jpg' : extension}',
        );
        await image.saveTo(destination);
        _pendingImages.add(destination);
      }
    } finally {
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          imageLocations: [
            ...latest.imageLocations,
            ..._newItems(latest.imageLocations, _pendingImages),
          ],
          isAddingMedia: false,
        ),
      );
    }
  }

  void addVoiceMemoDraft(String audioLocation) {
    _pendingVoiceMemos.add(audioLocation);
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        voiceMemoLocations: [...current.voiceMemoLocations, audioLocation],
      ),
    );
  }

  Future<void> save({required String title, required String text}) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));
    final database = ref.read(diaryDatabaseProvider);

    try {
      await database.changeTitle(dateKey, title.trim());
      await database.changeText(dateKey, text.trim());
      await database.changeMood(dateKey, current.mood);

      while (_pendingImages.isNotEmpty) {
        final image = _pendingImages.first;
        await database.addImage(dateKey, image);
        _pendingImages.removeAt(0);
      }
      while (_pendingVoiceMemos.isNotEmpty) {
        final memo = _pendingVoiceMemos.first;
        await database.addVoiceMemo(dateKey, memo);
        _pendingVoiceMemos.removeAt(0);
      }

      state = AsyncData(
        state.requireValue.copyWith(
          title: title.trim(),
          text: text.trim(),
          exists: true,
          isSaving: false,
        ),
      );
    } catch (_) {
      state = AsyncData(state.requireValue.copyWith(isSaving: false));
      rethrow;
    }
  }

  Iterable<String> _newItems(List<String> current, List<String> pending) {
    final existing = current.toSet();
    return pending.where((item) => !existing.contains(item));
  }

  Future<void> _discardPendingMedia() async {
    for (final filePath in [..._pendingImages, ..._pendingVoiceMemos]) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // A stale draft file is harmless and can be cleaned up later.
      }
    }
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
}
