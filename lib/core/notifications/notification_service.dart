import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Handles local notifications for both Android and iOS.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _dailyReminderId = 100;
  static const _newPlaceIdStart = 100000;
  static const _reminderChannel = AndroidNotificationChannel(
    'chronologe_reminders',
    'Diary reminders',
    description: 'Reminders to review and finish diary entries.',
    importance: Importance.defaultImportance,
  );
  static const _memoryChannel = AndroidNotificationChannel(
    'chronologe_memories',
    'Memory prompts',
    description: 'Prompts to capture memories at newly visited places.',
    importance: Importance.defaultImportance,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  Future<void>? _initialization;
  String? _pendingPayload;

  Stream<String> get payloads => _payloadController.stream;

  bool get _isSupported => Platform.isAndroid || Platform.isIOS;

  // Initializes the plugin without asking the user for permission.
  Future<void> initialize() {
    if (!_isSupported) return Future.value();
    return _initialization ??= _initializePlugin();
  }

  // Requests permission only after the user enables notifications.
  Future<bool> requestPermission() async {
    if (!_isSupported) return false;
    await initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  // Schedules one repeating reminder at the user's chosen local time.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_isSupported) return;
    await initialize();
    await cancelDailyReminder();

    final now = tz.TZDateTime.now(tz.local);
    var firstReminder = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!firstReminder.isAfter(now)) {
      firstReminder = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Your diary is ready',
      'Want to add the finishing touches to today\'s entry?',
      firstReminder,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chronologe_reminders',
          'Diary reminders',
          channelDescription: 'Reminders to review and finish diary entries.',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'today',
    );
  }

  // Cancels the repeating diary reminder without touching other prompts.
  Future<void> cancelDailyReminder() async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.cancel(_dailyReminderId);
  }

  // Shows one deduplicated prompt for a newly recognized visit.
  Future<void> showNewPlacePrompt({
    required int visitId,
    required String placeLabel,
  }) async {
    if (!_isSupported) return;
    await initialize();
    final notificationId = _newPlaceIdStart + (visitId % 1000000);
    await _plugin.show(
      notificationId,
      'New place visited',
      'Add a photo from $placeLabel?',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chronologe_memories',
          'Memory prompts',
          channelDescription:
              'Prompts to capture memories at newly visited places.',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'today',
    );
  }

  // Returns a tap payload that arrived before the signed-in app was ready.
  String? takePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  Future<void> _initializePlugin() async {
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // UTC is a safe fallback if a device reports an unknown time-zone name.
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _receivePayload(response.payload);
      },
    );

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_reminderChannel);
      await android?.createNotificationChannel(_memoryChannel);
    }

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _receivePayload(launchDetails?.notificationResponse?.payload);
    }
  }

  void _receivePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    _pendingPayload = payload;
    _payloadController.add(payload);
  }
}
