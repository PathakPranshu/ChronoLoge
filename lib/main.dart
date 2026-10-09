import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/notifications/notification_service.dart';
import 'firebase_options.dart';
import 'notification_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.instance.initialize();
  await NotificationService.instance.scheduleDailyPrompt();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hello World!'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationDemoPage(),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Open notification demo'),
            ),
          ],
        ),
      ),
    );
  }
}

// JJSHH
// ChronoLoge Main App Dev : 30-09-2026
