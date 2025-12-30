import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

    // Simple daily reminder (approx interval; exact 9AM scheduling can be added later if needed)
    await _plugin.periodicallyShow(
      1,
      'Jesus New',
      'Are you ready to have another conversation with God?',
      RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel', 'Daily Messages',
          importance: Importance.max, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    // Daily Echo reminder
    await _plugin.periodicallyShow(
      2,
      'Daily Echo',
      'Give 5 min a day, in a month we win.',
      RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'echo_channel', 'Echo Reminders',
          importance: Importance.max, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
