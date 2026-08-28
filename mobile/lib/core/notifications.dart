import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'storage.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    // Assuming SRU is in India time zone
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showForegroundNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'fcm_foreground_channel',
      'Important Updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _notificationsPlugin.show(
      DateTime.now().millisecond, // random id
      title ?? 'SRU Update',
      body,
      platformChannelSpecifics,
    );
  }

  static Future<void> scheduleClassReminders(List<dynamic> weekTimetable) async {
    // 1. Cancel all existing notifications first
    await _notificationsPlugin.cancelAll();

    if (!StorageService.isClassRemindersEnabled()) return;

    // 2. Parse week timetable and schedule
    int idCounter = 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekday = today.weekday; // 1 (Mon) to 7 (Sun)

    for (final dayData in weekTimetable) {
      final dayName = dayData['day'] as String;
      final classes = dayData['classes'] as List<dynamic>? ?? [];

      int targetWeekday = _getWeekdayNumber(dayName);
      if (targetWeekday == 0) continue;

      int daysDifference = targetWeekday - currentWeekday;
      DateTime targetDate = today.add(Duration(days: daysDifference));

      if (daysDifference < 0) {
        targetDate = targetDate.add(const Duration(days: 7));
      }

      for (final cls in classes) {
        final startTimeStr = cls['start_time'] as String;
        final subject = cls['subject'] as String? ?? 'Class';
        final room = cls['room'] as String? ?? 'TBA';
        final type = cls['type'] as String? ?? 'Class';

        final parts = startTimeStr.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;

        DateTime classTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );

        // 15 minute reminder
        DateTime reminderTime = classTime.subtract(const Duration(minutes: 15));

        // Ensure we only schedule future notifications
        if (reminderTime.isAfter(DateTime.now())) {
          final tz.TZDateTime scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

          await _notificationsPlugin.zonedSchedule(
            idCounter++,
            subject,
            '$type • $room',
            scheduledDate,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'class_reminders',
                'Class Reminders',
                channelDescription: 'Notifications for upcoming classes',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@drawable/ic_notification',
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    }
  }

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  static int _getWeekdayNumber(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday': return 1;
      case 'tuesday': return 2;
      case 'wednesday': return 3;
      case 'thursday': return 4;
      case 'friday': return 5;
      case 'saturday': return 6;
      case 'sunday': return 7;
      default: return 0;
    }
  }
}
