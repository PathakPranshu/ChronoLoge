import 'package:flutter/material.dart';

import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();

  runApp(const NotificationDemoApp());
}

class NotificationDemoApp extends StatelessWidget {
  const NotificationDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notification Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const NotificationDemoPage(),
    );
  }
}

class NotificationDemoPage extends StatefulWidget {
  const NotificationDemoPage({super.key});

  @override
  State<NotificationDemoPage> createState() => _NotificationDemoPageState();
}

class _NotificationDemoPageState extends State<NotificationDemoPage> {
  bool _isSending = false;

  Future<void> _sendNotification() async {
    setState(() => _isSending = true);

    try {
      await NotificationService.instance.showDailyPromptNow();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Daily notification sent.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send notification: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _scheduleNotification() async {
    setState(() => _isSending = true);

    try {
      await NotificationService.instance.scheduleDailyPromptIn30Seconds();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled. Close the app and wait 30 seconds.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule notification: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: _isSending ? null : _sendNotification,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                _isSending ? 'Please wait...' : 'Send daily notification',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSending ? null : _scheduleNotification,
              icon: const Icon(Icons.alarm_add_outlined),
              label: const Text('Send in 30 sec'),
            ),
          ],
        ),
      ),
    );
  }
}
