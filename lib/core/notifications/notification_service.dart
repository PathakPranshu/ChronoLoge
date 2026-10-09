import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_function.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyNotificationId = 100;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await NotificationFunction.plugin.initialize(
      initializationSettings,
    );

    await NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          NotificationFunction.channel,
        );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> scheduleDailyPrompt({
    int? hour,
    int? minute,
  }) async {
    await NotificationFunction.plugin.cancel(
      _dailyNotificationId,
    );

    final now = tz.TZDateTime.now(tz.local);

    final notificationHour = hour ?? 20;
    final notificationMinute = minute ?? 0;

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      notificationHour,
      notificationMinute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(
        const Duration(days: 1),
      );
    }

    await NotificationFunction.plugin.zonedSchedule(
      _dailyNotificationId,
      'Your Diary Is Ready',
      'Want to add finishing touches to today\'s entry?',
      scheduledDate,
      NotificationFunction.notificationDetails,
      androidScheduleMode:
          AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyPrompt() async {
    await NotificationFunction.plugin.cancel(
      _dailyNotificationId,
    );
  }

  Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return NotificationFunction.plugin.pendingNotificationRequests();
  }
}