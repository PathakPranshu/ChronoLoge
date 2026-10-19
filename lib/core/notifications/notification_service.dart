
import 'package:awesome_notifications/awesome_notifications.dart';

import 'notification_function.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _dailyNotificationId = 100;

  Future<void> initialize() async {
    await NotificationFunction.initialize();
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    bool isAllowed =
        await NotificationFunction.plugin.isNotificationAllowed();

    if (!isAllowed) {
      await NotificationFunction.plugin.requestPermissionToSendNotifications();
    }
  }

  Future<void> scheduleDailyPrompt({
    int? hour,
    int? minute,
  }) async {
    await NotificationFunction.plugin.cancel(_dailyNotificationId);

    final now = DateTime.now();
    final notificationHour = hour ?? 20;
    final notificationMinute = minute ?? 0;

    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      notificationHour,
      notificationMinute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final timeZone =
        await NotificationFunction.plugin.getLocalTimeZoneIdentifier();

    await NotificationFunction.plugin.createNotification(
      content: NotificationContent(
        id: _dailyNotificationId,
        channelKey: NotificationFunction.channelKey,
        title: 'Your Diary Is Ready',
        body: "Want to add finishing touches to today's entry?",
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

  Future<void> cancelDailyPrompt() async {
    await NotificationFunction.plugin.cancel(_dailyNotificationId);
  }

  Future<List<NotificationModel>> getPendingNotifications() async {
    return NotificationFunction.plugin.listScheduledNotifications();
  }
}
