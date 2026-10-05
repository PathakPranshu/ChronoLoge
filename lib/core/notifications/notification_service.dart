import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyNotificationId = 100;
  static const int _weeklyNotificationId = 200;
  static const int _monthlyNotificationId = 300;
  static const int _yearlyNotificationId = 400;

  static const String locationPrompt =
      'New Location Visited Add a Photo?';

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'chronologe_reminders',
    'ChronoLoge Reminders',
    description: 'Diary reminders and reflection prompts.',
    importance: Importance.defaultImportance,
  );

  static const NotificationDetails _notificationDetails =
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

    await _plugin.initialize(initializationSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> scheduleAllNotifications() async {
    await cancelAllNotifications();

    await _scheduleDailyNotification();
    await _scheduleWeeklyNotification();
    await _scheduleMonthlyNotification();
    await _scheduleYearlyNotification();
  }

  Future<void> _scheduleDailyNotification() async {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      10,
      30,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyNotificationId,
      'Your Diary Is Ready',
      'Want to Add Finishing Touches?',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeeklyNotification() async {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      18,
      0,
    );

    while (scheduledDate.weekday != DateTime.sunday ||
        !scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _weeklyNotificationId,
      'Your Weekly Summary Is Here',
      null,
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _scheduleMonthlyNotification() async {
    final now = tz.TZDateTime.now(tz.local);

    var year = now.year;
    var month = now.month;

    var scheduledDate = tz.TZDateTime(
      tz.local,
      year,
      month,
      1,
      10,
      0,
    );

    if (!scheduledDate.isAfter(now)) {
      if (month == 12) {
        year++;
        month = 1;
      } else {
        month++;
      }

      scheduledDate = tz.TZDateTime(
        tz.local,
        year,
        month,
        1,
        10,
        0,
      );
    }

    await _plugin.zonedSchedule(
      _monthlyNotificationId,
      'Look Back on How Your Month Went',
      null,
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> _scheduleYearlyNotification() async {
    final now = tz.TZDateTime.now(tz.local);

    var year = now.year + 1;

    var scheduledDate = tz.TZDateTime(
      tz.local,
      year,
      1,
      1,
      10,
      0,
    );

    if (!scheduledDate.isAfter(now)) {
      year++;
      scheduledDate = tz.TZDateTime(
        tz.local,
        year,
        1,
        1,
        10,
        0,
      );
    }

    await _plugin.zonedSchedule(
      _yearlyNotificationId,
      'Look Back on Your Year',
      null,
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }
}
