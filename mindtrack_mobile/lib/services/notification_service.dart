import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint(
        'NotificationService: Failed to detect local timezone, falling back to UTC. Error: $e',
      );
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _plugin.initialize(initializationSettings);

    // Explicitly create the high-importance channel on Android
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mindtrack_daily',
      'Daily Check-in',
      description: 'Daily check-in reminders to log your mood',
      importance: Importance.high,
      playSound: true,
    );

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
    }
  }

  Future<void> scheduleDaily(TimeOfDay time, bool enabled) async {
    if (enabled) {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      // Construct the scheduled time for today
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If scheduled time has already passed today, add a day to schedule it for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        0,
        'Time for your MindTrack check-in',
        'How are you feeling today? Log your mood and keep your streak alive.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'mindtrack_daily',
            'Daily Check-in',
            channelDescription: 'Daily check-in reminders to log your mood',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint(
        'NotificationService: Scheduled daily notification at ${time.hour}:${time.minute}',
      );
    } else {
      await _plugin.cancelAll();
      debugPrint('NotificationService: Cancelled all notifications.');
    }
  }
}
