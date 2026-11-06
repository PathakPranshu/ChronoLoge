import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';

const _diaryFontSettingKey = 'diary_font';

enum DiaryFont {
  fraunces,
  literata,
}

extension DiaryFontDetails on DiaryFont {
  String get label {
    switch (this) {
      case DiaryFont.fraunces:
        return 'Default';
      case DiaryFont.literata:
        return 'Fancy';
    }
  }

  String get description {
    switch (this) {
      case DiaryFont.fraunces:
        return 'Fraunces';
      case DiaryFont.literata:
        return 'Literata';
    }
  }

  String get storageValue => name;

  static DiaryFont fromStorage(String? value) {
    return DiaryFont.values.firstWhere(
      (font) => font.name == value,
      orElse: () => DiaryFont.fraunces,
    );
  }
}

final diaryFontProvider =
    NotifierProvider<DiaryFontController, DiaryFont>(
  DiaryFontController.new,
);

class DiaryFontController extends Notifier<DiaryFont> {
  @override
  DiaryFont build() {
    _loadSavedFont();
    return DiaryFont.fraunces;
  }

  Future<void> _loadSavedFont() async {
    try {
      final database = ref.read(settingsDatabaseProvider);
      final savedValue = await database.getSetting(_diaryFontSettingKey);

      if (!ref.mounted) return;

      state = DiaryFontDetails.fromStorage(savedValue);
    } catch (_) {
      // Keep Fraunces as the default if loading fails.
    }
  }

  Future<void> setFont(DiaryFont font) async {
    final database = ref.read(settingsDatabaseProvider);
    final previousFont = state;

    state = font;

    try {
      final existingValue = await database.getSetting(
        _diaryFontSettingKey,
      );

      if (existingValue == null) {
        await database.addSetting(
          _diaryFontSettingKey,
          font.storageValue,
        );
      } else {
        await database.changeSetting(
          _diaryFontSettingKey,
          font.storageValue,
        );
      }
    } catch (_) {
      state = previousFont;
      rethrow;
    }
  }
}
