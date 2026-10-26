import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/themes/theme_controller.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/notification_settings_controller.dart';
import 'core/routing/router.dart';
import 'core/themes/theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.instance.initialize();

  runApp(ProviderScope(child: const MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.watch(dailyRemindersEnabledProvider);

    return MaterialApp.router(
      theme: CustomTheme.lightThemeData(context),
      darkTheme: CustomTheme.darkThemeData(context),
      themeMode: themeMode,
      routerConfig: goRouter,
    );
  }
}

// JJSHH
// ChronoLoge Main App Dev : 30-09-2026
