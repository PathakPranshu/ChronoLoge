import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';

import 'notification_function.dart';

/// Handles local notifications for diary reminders and memory prompts.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 100;
  static const int _newPlaceIdStart = 100000;

  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();

  Future<void>? _initialization;
  String? _pendingPayload;

  Stream<String> get payloads => _payloadController.stream;

  /// Initializes notifications and registers notification-tap handling.
  ///
  /// Permission is deliberately not requested here. It is requested only
  /// when the user enables notifications.
  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await NotificationFunction.initialize();

    await NotificationFunction.plugin.setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );

    final initialAction = await NotificationFunction.plugin
        .getInitialNotificationAction(removeFromActionEvents: true);

    if (initialAction != null) {
      _receivePayload(initialAction.payload);
    }
  }

  /// Requests notification permission when the user enables notifications.
  Future<bool> requestPermission() async {
    await initialize();

    final plugin = NotificationFunction.plugin;

    if (await plugin.isNotificationAllowed()) {
      return true;
    }

    return plugin.requestPermissionToSendNotifications(
      channelKey: NotificationFunction.channelKey,
    );
  }

  /// Schedules a repeating daily reminder at the selected local time.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();
    await cancelDailyReminder();

    final now = DateTime.now();

    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final timeZone = await NotificationFunction.plugin
        .getLocalTimeZoneIdentifier();

    await NotificationFunction.plugin.createNotification(
      content: NotificationContent(
        id: _dailyReminderId,
        channelKey: NotificationFunction.channelKey,
        title: 'Your diary is ready',
        body: "Want to add the finishing touches to today's entry?",
        payload: {'route': 'today'},
      ),
      schedule: NotificationCalendar(
        hour: scheduledDate.hour,
        minute: scheduledDate.minute,
        second: 0,
        timeZone: timeZone,
        repeats: true,
      ),
    );
  }

  /// Cancels the daily reminder without affecting memory prompts.
  Future<void> cancelDailyReminder() async {
    await initialize();
    await NotificationFunction.plugin.cancel(_dailyReminderId);
  }

  /// Shows a memory prompt for a newly recognized visit.
  Future<void> showNewPlacePrompt({
    required int visitId,
    required String placeLabel,
  }) async {
    await initialize();

    final notificationId = _newPlaceIdStart + (visitId % 1000000);

    await NotificationFunction.plugin.createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: NotificationFunction.channelKey,
        title: 'New place visited',
        body: 'Add a photo from $placeLabel?',
        payload: {'route': 'today'},
      ),
    );
  }

  /// Returns a notification tap payload that arrived before the app was ready.
  String? takePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  /// Compatibility method for the older notification settings controller.
  Future<void> scheduleDailyPrompt({int? hour, int? minute}) {
    return scheduleDailyReminder(hour: hour ?? 20, minute: minute ?? 0);
  }

  /// Compatibility method for the older notification settings controller.
  Future<void> cancelDailyPrompt() {
    return cancelDailyReminder();
  }

  /// Returns currently scheduled notifications.
  Future<List<NotificationModel>> getPendingNotifications() async {
    await initialize();
    return NotificationFunction.plugin.listScheduledNotifications();
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    instance._receivePayload(receivedAction.payload);
  }

  void _receivePayload(Map<String, String?>? payload) {
    if (payload == null) return;

    final route = payload['route'];
    if (route == null || route.isEmpty) return;

    _pendingPayload = route;
    _payloadController.add(route);
  }
}
