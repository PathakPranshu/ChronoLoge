import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';

const _themeSettingKey = 'theme_mode';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadSavedTheme();
    return ThemeMode.system;
  }

  Future<void> _loadSavedTheme() async {
    try {
      final database = ref.read(settingsDatabaseProvider);
      final savedValue = await database.getSetting(_themeSettingKey);

      if (!ref.mounted) return;

      state = switch (savedValue) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' || null => ThemeMode.system,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Keep the system theme if loading the saved preference fails.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final database = ref.read(settingsDatabaseProvider);
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    final previousMode = state;
    state = mode;

    try {
      final existingValue = await database.getSetting(_themeSettingKey);

      if (existingValue == null) {
        await database.addSetting(_themeSettingKey, value);
      } else {
        await database.changeSetting(_themeSettingKey, value);
      }
    } catch (_) {
      state = previousMode;
      rethrow;
    }
  }
}
