import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'storage.dart';
import 'dart:math';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'fcm_default_channel',
        'Timetable Updates',
        description: 'Updates about your classes and timetable changes.',
        importance: Importance.max,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'fcm_foreground_channel',
        'Important Updates',
        importance: Importance.max,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'class_reminders',
        'Class Reminders',
        description: 'Notifications before a class starts.',
        importance: Importance.max,
      ));
    }
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
      DateTime.now().millisecond,
      title ?? 'SRU Update',
      body,
      platformChannelSpecifics,
    );
  }

  static Future<void> scheduleClassReminders(List<dynamic> weekTimetable) async {
    print('========== DIAGNOSTIC: BEGIN SCHEDULE CLASS REMINDERS ==========');
    await _notificationsPlugin.cancelAll();

    if (!StorageService.isClassRemindersEnabled()) {
      print('Diagnostic: Class reminders are disabled in StorageService.');
      return;
    }

    int idCounter = 0;
    final nowLocal = DateTime.now();
    final nowTz = tz.TZDateTime.now(tz.local);
    print('Diagnostic: current DateTime (device local) = ${nowLocal}');
    print('Diagnostic: current Asia/Kolkata time = ${nowTz}');
    print('Diagnostic: configured reminder minutes = 15');



    for (final dayData in weekTimetable) {
      final dayName = dayData['day'] as String;
      final classes = dayData['classes'] as List<dynamic>? ?? [];

      int targetWeekday = _getWeekdayNumber(dayName);
      if (targetWeekday == 0) continue;

      for (final cls in classes) {
        final startTimeStr = cls['start_time'] as String;
        final subject = cls['subject'] as String? ?? 'Class';
        final room = cls['room'] as String? ?? 'TBA';
        final type = cls['type'] as String? ?? 'Class';

        final parts = startTimeStr.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;

        // Determine next instance of this weekday/time in Asia/Kolkata
        var targetDate = tz.TZDateTime(tz.local, nowTz.year, nowTz.month, nowTz.day, hour, minute);
        
        while (targetDate.weekday != targetWeekday) {
          targetDate = targetDate.add(const Duration(days: 1));
        }

        var reminderTime = targetDate.subtract(const Duration(minutes: 15));
        
        // If the reminder time is already passed for this week, schedule for next week
        if (reminderTime.isBefore(nowTz)) {
          targetDate = targetDate.add(const Duration(days: 7));
          reminderTime = targetDate.subtract(const Duration(minutes: 15));
        }

        print('Diagnostic: Parsed class [${subject}] on [${dayName}] at [${startTimeStr}]');
        print('Diagnostic: -> Class start tz.TZDateTime = ${targetDate}');
        print('Diagnostic: -> Calculated reminder tz.TZDateTime = ${reminderTime}');

        try {
          int notifId = idCounter++;
          await _notificationsPlugin.zonedSchedule(
            notifId,
            subject,
            '${type} • ${room}',
            reminderTime,
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
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
          print('Diagnostic: -> SUCCESS! Scheduled recurring reminder with notification ID: ${notifId}');
        } catch (e) {
          print('Diagnostic: -> FAILED to schedule reminder: ${e}');
        }
      }
    }
    print('========== DIAGNOSTIC: END SCHEDULE CLASS REMINDERS ==========');
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
