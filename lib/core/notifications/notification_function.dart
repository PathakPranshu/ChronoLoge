import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationFunction {
  NotificationFunction._();

  static final AwesomeNotifications plugin = AwesomeNotifications();

  static const String channelKey = 'chronologe_reminders';

  static Future<void> initialize() async {
    await plugin.initialize(
      null,
      [
        NotificationChannel(
          channelKey: channelKey,
          channelName: 'ChronoLoge Reminders',
          channelDescription: 'Diary reminders and reflection prompts.',
          importance: NotificationImportance.Default,
          playSound: true,
        ),
      ],
    );
  }

  static Future<void> pushNotification(String content) async {
    await plugin.createNotification(
      content: NotificationContent(
        id: 1000,
        channelKey: channelKey,
        title: 'ChronoLoge',
        body: content,
      ),
    );
  }

  static Future<void> pushLocationPrompt() async {
    await plugin.createNotification(
      content: NotificationContent(
        id: 1001,
        channelKey: channelKey,
        title: 'New Location Visited',
        body: 'Add a photo?',
      ),
    );
  }
}