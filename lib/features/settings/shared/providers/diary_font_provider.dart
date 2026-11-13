import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/diary_font_style.dart';
import '../../shared/providers/settings_provider.dart';

const _diaryFontSettingKey = 'diary_font';

final preferencesViewModelProvider =
    AsyncNotifierProvider<PreferencesViewModel, DiaryFontStyle>(
      PreferencesViewModel.new,
    );

class PreferencesViewModel extends AsyncNotifier<DiaryFontStyle> {
  @override
  Future<DiaryFontStyle> build() async {
    try {
      final savedValue = await ref
          .read(settingsRepositoryProvider)
          .getSetting(_diaryFontSettingKey);

      return DiaryFontStyleDetails.fromStorage(savedValue);
    } catch (_) {
      return DiaryFontStyle.fraunces;
    }
  }

  Future<void> setDiaryFont(DiaryFontStyle font) async {
    final previousFont = state.asData?.value ?? DiaryFontStyle.fraunces;

    state = AsyncData(font);

    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveSetting(_diaryFontSettingKey, font.storageValue);
    } catch (_) {
      state = AsyncData(previousFont);
      rethrow;
    }
  }
}
