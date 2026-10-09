import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationFunction {
  NotificationFunction._();

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chronologe_reminders',
    'ChronoLoge Reminders',
    description: 'Diary reminders and reflection prompts.',
    importance: Importance.defaultImportance,
  );

  static const AndroidNotificationChannel demoChannel =
      AndroidNotificationChannel(
        'chronologe_demo_alerts',
        'ChronoLoge Demo Alerts',
        description: 'High-priority notification demonstrations.',
        importance: Importance.high,
      );

  static const NotificationDetails notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'chronologe_reminders',
      'ChronoLoge Reminders',
      icon: 'ic_stat_chronologe',
      largeIcon: DrawableResourceAndroidBitmap('notification_large_icon'),
      channelDescription: 'Diary reminders and reflection prompts.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const NotificationDetails demoNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chronologe_demo_alerts',
          'ChronoLoge Demo Alerts',
          icon: 'ic_stat_chronologe',
          largeIcon: DrawableResourceAndroidBitmap('notification_large_icon'),
          channelDescription: 'High-priority notification demonstrations.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  static Future<void> pushNotification(String content) async {
    await plugin.show(1000, 'ChronoLoge', content, notificationDetails);
  }

  static Future<void> pushLocationPrompt() async {
    await plugin.show(
      1001,
      'New Location Visited',
      'Add a photo?',
      notificationDetails,
    );
  }
}
