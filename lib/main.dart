import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/themes/theme.dart';
import 'features/navigation/views/app_shell.dart';
import 'features/settings/models/app_settings.dart';
import 'features/settings/viewmodels/settings_view_model.dart';
import 'features/tracking/viewmodels/background_tracking_controller.dart';

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(backgroundTrackingControllerProvider);
    final settings =
        ref.watch(settingsViewModelProvider).value ?? const AppSettings();
    final accentColor = Color(settings.accentColorValue);

    return MaterialApp(
      title: 'ChronoLoge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentColor),
      darkTheme: AppTheme.dark(accentColor),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const AppShell(),
    );
  }
}

// JJSHH
// ChronoLoge Main App Dev : 30-09-2026
