import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_function.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyNotificationId = 100;
  static const int _dailyNotificationDemoId = 101;
  static const int _delayedNotificationDemoId = 102;
  static const String _dailyNotificationTitle = 'Your Diary Is Ready';
  static const String _dailyNotificationBody =
      'Want to add finishing touches to today\'s entry?';
  static const Map<String, String> _timeZoneAliases = {
    'Asia/Calcutta': 'Asia/Kolkata',
  };

  Future<void> initialize() async {
    tz.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final timeZoneIdentifier =
        _timeZoneAliases[timezoneInfo.identifier] ?? timezoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneIdentifier));

    const androidSettings = AndroidInitializationSettings('ic_stat_chronologe');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await NotificationFunction.plugin.initialize(initializationSettings);

    await NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(NotificationFunction.channel);

    await NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(NotificationFunction.demoChannel);

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleDailyPrompt({int? hour, int? minute}) async {
    await NotificationFunction.plugin.cancel(_dailyNotificationId);

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
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await NotificationFunction.plugin.zonedSchedule(
      _dailyNotificationId,
      _dailyNotificationTitle,
      _dailyNotificationBody,
      scheduledDate,
      NotificationFunction.notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showDailyPromptNow() async {
    await NotificationFunction.plugin.show(
      _dailyNotificationDemoId,
      _dailyNotificationTitle,
      _dailyNotificationBody,
      NotificationFunction.demoNotificationDetails,
    );
  }

  Future<void> scheduleDailyPromptIn30Seconds() async {
    final androidPlugin = NotificationFunction.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      var canScheduleExact =
          await androidPlugin.canScheduleExactNotifications() ?? false;

      if (!canScheduleExact) {
        await androidPlugin.requestExactAlarmsPermission();
        canScheduleExact =
            await androidPlugin.canScheduleExactNotifications() ?? false;
      }

      if (!canScheduleExact) {
        throw StateError(
          'Exact alarm access is required for the 30-second test.',
        );
      }
    }

    await NotificationFunction.plugin.cancel(_delayedNotificationDemoId);

    final scheduledDate = tz.TZDateTime.now(tz.local)
        .add(const Duration(seconds: 30));

    await NotificationFunction.plugin.zonedSchedule(
      _delayedNotificationDemoId,
      _dailyNotificationTitle,
      _dailyNotificationBody,
      scheduledDate,
      NotificationFunction.demoNotificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelDailyPrompt() async {
    await NotificationFunction.plugin.cancel(_dailyNotificationId);
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return NotificationFunction.plugin.pendingNotificationRequests();
  }
}
