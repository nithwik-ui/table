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
    print('========== DIAGNOSTIC: FCM HANDLES REMINDERS REMOTELY ==========');
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
