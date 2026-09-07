import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'storage.dart';
import 'utils.dart';
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
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
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
      Random().nextInt(100000),
      title ?? 'SRU Update',
      body,
      platformChannelSpecifics,
    );
  }

  static Future<void> clearModeReminders(String mode) async {
    final oldIds = StorageService.getScheduledReminderIds(mode);
    for (final id in oldIds) {
      await _notificationsPlugin.cancel(id);
    }
    await StorageService.clearScheduledReminderIds(mode);
  }

  static Future<void> reconcileReminders() async {
    print('========== DIAGNOSTIC: BEGIN RECONCILE REMINDERS ==========');
    final userMode = StorageService.getUserMode();
    
    if (userMode == null || userMode.isEmpty) {
      // Clear all state for both modes if no mode is selected
      await clearModeReminders('student');
      await clearModeReminders('faculty');
      return;
    }

    List<dynamic> timetable = [];
    if (userMode == 'faculty') {
      timetable = StorageService.getFacultyTimetableCache();
    } else {
      timetable = StorageService.getTimetableCache();
    }

    if (timetable.isNotEmpty) {
      await scheduleClassReminders(timetable);
    }
  }

  static Future<void> scheduleClassReminders(List<dynamic> weekTimetable) async {
    print('========== DIAGNOSTIC: BEGIN SCHEDULE CLASS REMINDERS ==========');
    
    final userMode = StorageService.getUserMode() ?? 'student';

    if (!StorageService.isClassRemindersEnabled()) {
      print('Diagnostic: Class reminders are disabled in StorageService.');
      await clearModeReminders(userMode);
      return;
    }

    final nowLocal = DateTime.now();
    
    final overrides = userMode == 'faculty' 
        ? StorageService.getFacultyCalendarOverridesCache() 
        : StorageService.getStudentCalendarOverridesCache();

    Map<int, Map<String, dynamic>> validReminderMap = {};

    for (int dayOffset = 0; dayOffset <= 6; dayOffset++) {
      final targetDate = nowLocal.add(Duration(days: dayOffset));
      final targetWeekday = targetDate.weekday;
      final formattedDate = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

      for (final cls in weekTimetable) {
        final dayName = cls['day'] as String;
        final classWeekday = _getWeekdayNumber(dayName);
        
        if (classWeekday != targetWeekday) continue;

        final startTimeStr = cls['start_time'] as String;
        final endTimeStr = cls['end_time'] as String? ?? '';
        final subject = cls['subject'] as String? ?? 'Class';
        final room = cls['room'] as String? ?? '';
        final faculty = cls['faculty'] as String? ?? '';
        
        final parts = startTimeStr.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;

        final classStartLocal = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
        final reminderTimeLocal = classStartLocal.subtract(const Duration(minutes: 5));

        if (!reminderTimeLocal.isAfter(nowLocal)) {
          continue;
        }

        bool isCancelledByHoliday = false;
        for (final override in overrides) {
          if (override['override_date'] == formattedDate) {
            final targetMode = override['target_mode'];
            if (targetMode == 'both' || targetMode == userMode) {
              final oStart = override['start_time'];
              final oEnd = override['end_time'];
              if (oStart != null && oStart.toString().isNotEmpty && oEnd != null && oEnd.toString().isNotEmpty) {
                 final cStart = startTimeStr;
                 if (cStart.compareTo(oStart) >= 0 && cStart.compareTo(oEnd) <= 0) {
                   isCancelledByHoliday = true;
                   break;
                 }
              } else {
                isCancelledByHoliday = true;
                break;
              }
            }
          }
        }

        if (isCancelledByHoliday) continue;

        String timeDisplay = TimeUtils.format12Hour(startTimeStr);
        if (endTimeStr.isNotEmpty) {
          timeDisplay += ' – ${TimeUtils.format12Hour(endTimeStr)}';
        }
        
        String body = timeDisplay;
        if (room.isNotEmpty && room != 'TBA') {
          body += ' • ${room.split('_')[0]}';
        }
        if (faculty.isNotEmpty) {
          body += '\n$faculty';
        }

        final notifId = Object.hash(
          userMode,
          subject, 
          startTimeStr, 
          targetDate.year, 
          targetDate.month, 
          targetDate.day
        ).abs() % 2147483647;

        validReminderMap[notifId] = {
          'id': notifId,
          'title': 'Class Reminder',
          'body': '$subject starts in 5 minutes\n$body',
          'reminderTimeTz': tz.TZDateTime.from(reminderTimeLocal, tz.local),
        };
      }
    }

    final oldScheduledIds = StorageService.getScheduledReminderIds(userMode);
    
    for (final oldId in oldScheduledIds) {
      if (!validReminderMap.containsKey(oldId)) {
        print('Diagnostic: [ClassReminder] Cancelling obsolete ID: $oldId');
        await _notificationsPlugin.cancel(oldId);
      }
    }

    for (final newId in validReminderMap.keys) {
      if (!oldScheduledIds.contains(newId)) {
        final reminder = validReminderMap[newId]!;
        print('Diagnostic: [ClassReminder] Scheduling new reminder for ${reminder['reminderTimeTz']} ID: $newId');
        
        try {
          await _notificationsPlugin.zonedSchedule(
            reminder['id'] as int,
            reminder['title'] as String,
            reminder['body'] as String,
            reminder['reminderTimeTz'] as tz.TZDateTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'class_reminders',
                'Class Reminders',
                channelDescription: 'Notifications before a class starts.',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@drawable/ic_notification',
              ),
              iOS: DarwinNotificationDetails(
                sound: 'default',
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          print('Diagnostic: Error scheduling reminder $newId: $e');
        }
      }
    }

    // 3. Persist new state
    await StorageService.saveScheduledReminderIds(userMode, validReminderMap.keys.toList());
    
    print('========== DIAGNOSTIC: END SCHEDULE CLASS REMINDERS ==========');
  }

  static Future<void> cancelStudentClassReminders() async {
    final pendingRequests = await _notificationsPlugin.pendingNotificationRequests();
    for (final request in pendingRequests) {
      if (request.payload == 'student') {
        await _notificationsPlugin.cancel(request.id);
      }
    }
  }

  static Future<void> cancelFacultyClassReminders() async {
    final pendingRequests = await _notificationsPlugin.pendingNotificationRequests();
    for (final request in pendingRequests) {
      if (request.payload == 'faculty') {
        await _notificationsPlugin.cancel(request.id);
      }
    }
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
