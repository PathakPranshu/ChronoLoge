import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/settings_provider.dart';

const _diaryFontSettingKey = 'diary_font';

enum DiaryFontStyle {
  fraunces,
  literata,
}

extension DiaryFontStyleDetails on DiaryFontStyle {
  String get label {
    switch (this) {
      case DiaryFontStyle.fraunces:
        return 'Default';
      case DiaryFontStyle.literata:
        return 'Fancy';
    }
  }

  String get storageValue => name;

  static DiaryFontStyle fromStorage(String? value) {
    return DiaryFontStyle.values.firstWhere(
      (font) => font.storageValue == value,
      orElse: () => DiaryFontStyle.fraunces,
    );
  }
}

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
    final previousFont =
        state.asData?.value ?? DiaryFontStyle.fraunces;

    state = AsyncData(font);

    try {
      await ref.read(settingsRepositoryProvider).saveSetting(
            _diaryFontSettingKey,
            font.storageValue,
          );
    } catch (_) {
      state = AsyncData(previousFont);
      rethrow;
    }
  }
}
