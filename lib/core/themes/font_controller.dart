import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';

const _fontSettingKey = 'app_font';

enum AppFont { geist, roboto, lato }

extension AppFontDetails on AppFont {
  String get label {
    switch (this) {
      case AppFont.geist:
        return 'Geist';
      case AppFont.roboto:
        return 'Roboto';
      case AppFont.lato:
        return 'Lato';
    }
  }

  String get fontFamily {
    switch (this) {
      case AppFont.geist:
        return 'Geist';
      case AppFont.roboto:
        return 'Roboto';
      case AppFont.lato:
        return 'Lato';
    }
  }

  String get storageValue => name;

  static AppFont fromStorage(String? value) {
    return AppFont.values.firstWhere(
      (font) => font.name == value,
      orElse: () => AppFont.geist,
    );
  }
}

final appFontProvider = NotifierProvider<AppFontController, AppFont>(
  AppFontController.new,
);

class AppFontController extends Notifier<AppFont> {
  @override
  AppFont build() {
    _loadSavedFont();
    return AppFont.geist;
  }

  Future<void> _loadSavedFont() async {
    try {
      final database = ref.read(settingsDatabaseProvider);
      final savedValue = await database.getSetting(_fontSettingKey);

      if (!ref.mounted) return;

      state = AppFontDetails.fromStorage(savedValue);
    } catch (_) {
      // Keep Geist as the default if loading fails.
    }
  }

  Future<void> setFont(AppFont font) async {
    final database = ref.read(settingsDatabaseProvider);
    final previousFont = state;

    // Update the UI immediately.
    state = font;

    try {
      final existingValue = await database.getSetting(_fontSettingKey);

      if (existingValue == null) {
        await database.addSetting(_fontSettingKey, font.storageValue);
      } else {
        await database.changeSetting(_fontSettingKey, font.storageValue);
      }
    } catch (_) {
      state = previousFont;
      rethrow;
    }
  }
}
