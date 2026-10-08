import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'storage.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../features/dashboard/dashboard_screen.dart';

import 'reminder_manager.dart';
import 'analytics_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    if (kIsWeb) {
      ReminderManager.instance.init(_notificationsPlugin);
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        bool isReminder = false;
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final map = jsonDecode(response.payload!);
            if (map['type'] == 'class_reminder') isReminder = true;
          } catch (_) {
            if (response.payload == 'class_reminder') isReminder = true;
          }
        }
        if (isReminder) {
          AnalyticsService.instance.logClassReminderOpened();
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen(initialTab: 0)),
            (route) => false,
          );
        }
      },
    );

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
        description: 'Reminders 9 minutes before class starts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
    }
    
    ReminderManager.instance.init(_notificationsPlugin);
  }

  static Future<void> showForegroundNotification(String? title, String? body, Map<String, dynamic> data) async {
    if (kIsWeb) return;
    if (!StorageService.isNotificationsEnabled()) return;

    final type = data['type']?.toString();
    if (type == 'timetable_change' && !StorageService.isTimetableChangesEnabled()) return;
    if (type == 'room_change' && !StorageService.isRoomChangesEnabled()) return;
    if (type == 'faculty_change' && !StorageService.isFacultyChangesEnabled()) return;
    if (type == 'class_cancelled' && !StorageService.isCancelledClassesEnabled()) return;
    if (type == 'general_announcement' && !StorageService.isGeneralAnnouncementsEnabled()) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'fcm_default_channel',
      'Timetable Updates',
      channelDescription: 'Important Updates',
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
      payload: jsonEncode(data),
    );
  }

  static Future<int> getPendingCount() async {
    if (kIsWeb) return 0;
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    return pending.length;
  }

  static Future<void> clearModeReminders(String mode) async {
    await ReminderManager.instance.clearAllForMode(mode);
  }

  static Future<void> reconcileReminders() async {
    final userMode = StorageService.getUserMode();
    
    if (userMode == null || userMode.isEmpty) {
      // Complete teardown if no mode is selected
      await ReminderManager.instance.clearAllForMode('student');
      await ReminderManager.instance.clearAllForMode('faculty');
      return;
    }

    // Always clear the inactive mode
    final inactiveMode = userMode == 'student' ? 'faculty' : 'student';
    await ReminderManager.instance.clearAllForMode(inactiveMode);

    List<dynamic> timetable = [];
    List<dynamic> overrides = [];
    if (userMode == 'faculty') {
      timetable = StorageService.getFacultyTimetableCache();
    } else {
      timetable = StorageService.getTimetableCache();
      overrides = StorageService.getStudentCalendarOverridesCache();
    }

    if (timetable.isNotEmpty) {
      await ReminderManager.instance.reconcile(
        timetable: timetable,
        overrides: overrides,
        mode: userMode,
      );
    }
  }
}
