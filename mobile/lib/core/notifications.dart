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

  static Future<void> reconcileReminders() async {
    print('========== DIAGNOSTIC: BEGIN RECONCILE REMINDERS ==========');
    final userMode = StorageService.getUserMode();
    
    if (userMode == null || userMode.isEmpty) {
      // Clear all pending if no mode
      final pendingRequests = await _notificationsPlugin.pendingNotificationRequests();
      for (final request in pendingRequests) {
        await _notificationsPlugin.cancel(request.id);
      }
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
    
    // Cancel previously scheduled class reminders. 
    // We cancel all pending requests to clear old 15-minute reminders and prevent duplicates.
    final pendingRequests = await _notificationsPlugin.pendingNotificationRequests();
    for (final request in pendingRequests) {
      await _notificationsPlugin.cancel(request.id);
    }

    if (!StorageService.isClassRemindersEnabled()) {
      print('Diagnostic: Class reminders are disabled in StorageService.');
      return;
    }

    final nowLocal = DateTime.now();
    bool anyScheduled = false;

    for (final cls in weekTimetable) {
      final dayName = cls['day'] as String;

      int targetWeekday = _getWeekdayNumber(dayName);
      if (targetWeekday == 0) continue;
      
      // ONLY schedule if the class actually exists TODAY
      if (targetWeekday != nowLocal.weekday) continue;

      final startTimeStr = cls['start_time'] as String;
      final endTimeStr = cls['end_time'] as String? ?? '';
      final subject = cls['subject'] as String? ?? 'Class';
      final room = cls['room'] as String? ?? '';
      final faculty = cls['faculty'] as String? ?? '';
      
      final parts = startTimeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      final classStartLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, hour, minute);
      final reminderTimeLocal = classStartLocal.subtract(const Duration(minutes: 5));

      print('Diagnostic: [ClassReminder] Today: $dayName');
      print('Diagnostic: [ClassReminder] Class: $subject');
      print('Diagnostic: [ClassReminder] Start: $startTimeStr');

      // Past class protection / starting in less than 5 minutes
      if (!reminderTimeLocal.isAfter(nowLocal)) {
        print('Diagnostic: [ClassReminder] Skipped $subject $startTimeStr');
        print('Diagnostic: [ClassReminder] Reason: reminder time already passed');
        continue;
      }

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

      final userMode = StorageService.getUserMode() ?? 'student';

      // Duplicate notification protection using deterministic ID with namespace isolation
      final notifId = Object.hash(
        userMode,
        subject, 
        startTimeStr, 
        nowLocal.year, 
        nowLocal.month, 
        nowLocal.day
      ).abs() % 2147483647;

      print('Diagnostic: [ClassReminder] Reminder: $reminderTimeLocal');
      print('Diagnostic: [ClassReminder] Scheduling notification ID: $notifId');

      // Check for calendar overrides
      final overrides = userMode == 'faculty' 
          ? StorageService.getFacultyCalendarOverridesCache() 
          : StorageService.getStudentCalendarOverridesCache();
      bool isCancelledByHoliday = false;
      final formattedDate = "${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}";
      for (final override in overrides) {
        if (override['override_date'] == formattedDate) {
          final targetMode = override['target_mode'];
          if (targetMode == 'both' || targetMode == userMode) {
            // If there's a time window, check if class falls in it
            final oStart = override['start_time'];
            final oEnd = override['end_time'];
            if (oStart != null && oStart.toString().isNotEmpty && oEnd != null && oEnd.toString().isNotEmpty) {
               // Check if class start time is within holiday window
               final cStart = startTimeStr; // e.g. "09:00"
               if (cStart.compareTo(oStart) >= 0 && cStart.compareTo(oEnd) <= 0) {
                 isCancelledByHoliday = true;
                 break;
               }
            } else {
              // Full day holiday
              isCancelledByHoliday = true;
              break;
            }
          }
        }
      }

      if (isCancelledByHoliday) {
        print('Diagnostic: [ClassReminder] Skipped $subject $startTimeStr due to calendar override/holiday');
        continue;
      }

      final reminderTimeTz = tz.TZDateTime.from(reminderTimeLocal, tz.local);

      try {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          'Class Reminder',
          '$subject starts in 5 minutes\n$body',
          reminderTimeTz,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'class_reminders',
              'Class Reminders',
              channelDescription: 'Notifications before a class starts.',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@drawable/ic_notification',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: userMode, // IMPORTANT: Used for mode-specific cancellation
        );
        anyScheduled = true;
        print('Diagnostic: [ClassReminder] Scheduled successfully');
      } catch (e) {
        print('Diagnostic: [ClassReminder] FAILED to schedule reminder: $e');
      }
    }
    
    if (!anyScheduled) {
      print('Diagnostic: [ClassReminder] No classes today or all classes passed');
      print('Diagnostic: [ClassReminder] No reminders scheduled');
    }
    
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
