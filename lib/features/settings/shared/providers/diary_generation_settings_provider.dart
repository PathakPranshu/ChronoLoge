import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diary_generation_mode.dart';
import 'settings_provider.dart';

final diaryGenerationProvider =
    AsyncNotifierProvider<DiaryGenerationNotifier, DiaryGenerationMode>(
  DiaryGenerationNotifier.new,
);

class DiaryGenerationNotifier extends AsyncNotifier<DiaryGenerationMode> {
  static const String _modeKey = 'diary_generation_mode';

  @override
  FutureOr<DiaryGenerationMode> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    final raw = await repo.getSetting(_modeKey);
    return DiaryGenerationMode.fromStorageKey(raw);
  }

  Future<void> setMode(DiaryGenerationMode newMode) async {
    final current = state.value ?? DiaryGenerationMode.automatic;
    if (current == newMode) return;

    // Update UI 
    state = AsyncData(newMode);

    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.saveSetting(_modeKey, newMode.storageKey);
    } catch (e, st) {
      state = AsyncData(current);
      Error.throwWithStackTrace(e, st);
    }
  }
}