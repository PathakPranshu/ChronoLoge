import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

const _themeSettingKey = 'theme_mode';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  bool _hasUserChanged = false;

  @override
  ThemeMode build() {
    _loadSavedTheme();
    return ThemeMode.system;
  }

  Future<void> _loadSavedTheme() async {
    try {
      final repository = ref.read(settingsRepositoryProvider);
      final savedValue = await repository.getSetting(_themeSettingKey);

      if (!ref.mounted || _hasUserChanged) return;

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
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    _hasUserChanged = true;

    final previousMode = state;
    state = mode;

    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveSetting(_themeSettingKey, value);
    } catch (_) {
      state = previousMode;
      rethrow;
    }
  }
}
