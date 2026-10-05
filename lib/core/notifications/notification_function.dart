import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationFunction {
  NotificationFunction._();

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel =
      AndroidNotificationChannel(
    'chronologe_reminders',
    'ChronoLoge Reminders',
    description: 'Diary reminders and reflection prompts.',
    importance: Importance.defaultImportance,
  );

  static const NotificationDetails notificationDetails =
      NotificationDetails(
    android: AndroidNotificationDetails(
      'chronologe_reminders',
      'ChronoLoge Reminders',
      channelDescription: 'Diary reminders and reflection prompts.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> pushNotification(String content) async {
    await plugin.show(
      1000,
      'ChronoLoge',
      content,
      notificationDetails,
    );
  }
}