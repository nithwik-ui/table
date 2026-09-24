import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class ReminderManager {
  static final ReminderManager instance = ReminderManager._internal();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;

  ReminderManager._internal();

  void init(FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
    _initialized = true;
  }

  // Parses HH:MM to int minutes
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool isReminderEligible(dynamic event, List<dynamic> overrides, DateTime targetDate) {
    if (event == null) return false;
    if (event['is_struck_off'] == true || event['is_cancelled'] == true) return false;

    final dateString = _formatDate(targetDate);
    
    try {
      final dayOverride = overrides.firstWhere((ov) => ov['override_date'] == dateString, orElse: () => null);
      if (dayOverride != null) return false;
    } catch (_) {}

    final startTimeStr = event['start_time']?.toString();
    if (startTimeStr == null || startTimeStr.isEmpty) return false;

    final timeParts = startTimeStr.split(':');
    if (timeParts.length != 2) return false;

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return false;

    final classStartTime = DateTime(
      targetDate.year, targetDate.month, targetDate.day, hour, minute,
    );

    final reminderTime = classStartTime.subtract(const Duration(minutes: 9));
    if (reminderTime.isBefore(DateTime.now())) return false;

    return true;
  }

  Future<void> reconcile({
    required List<dynamic> timetable,
    required List<dynamic> overrides,
    required String mode,
  }) async {
    if (!_initialized) return;
    debugPrint('[ReminderManager] reconcile started for mode: $mode');

    // 1. Generate canonical events
    final now = DateTime.now();
    final Map<int, Map<String, dynamic>> expectedReminders = {};

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final dayName = _getDayName(targetDate.weekday);
      final dateString = _formatDate(targetDate);

      // Get classes for day and sort by start time
      List<dynamic> dayClasses = timetable.where((c) => c['day']?.toString() == dayName).toList();
      dayClasses.sort((a, b) => _timeToMinutes(a['start_time'] ?? '00:00').compareTo(_timeToMinutes(b['start_time'] ?? '00:00')));

      // Merge continuous classes
      List<dynamic> mergedClasses = [];
      for (var cls in dayClasses) {
        if (mergedClasses.isEmpty) {
          mergedClasses.add(Map<String, dynamic>.from(cls));
        } else {
          var last = mergedClasses.last;
          bool canMerge = last['subject'] == cls['subject'] && 
                          last['faculty'] == cls['faculty'] && 
                          last['room'] == cls['room'] &&
                          last['group'] == cls['group'] &&
                          last['end_time'] == cls['start_time'] &&
                          last['is_cancelled'] == cls['is_cancelled'] &&
                          last['is_struck_off'] == cls['is_struck_off'];
          if (canMerge) {
            last['end_time'] = cls['end_time'];
          } else {
            mergedClasses.add(Map<String, dynamic>.from(cls));
          }
        }
      }

      for (final event in mergedClasses) {
        if (!isReminderEligible(event, overrides, targetDate)) continue;

        final subject = event['subject']?.toString() ?? 'Class';
        final room = event['room']?.toString() ?? 'TBD';
        final startTimeStr = event['start_time']?.toString() ?? '';
        final eventId = event['id']?.toString() ?? 'merged';
        final faculty = event['faculty']?.toString() ?? '';
        
        final eventKey = '$mode|$dateString|$startTimeStr|$subject|$faculty|$room';
        final notificationId = eventKey.hashCode.abs() % 100000;

        final timeParts = startTimeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final classStartTime = DateTime(
          targetDate.year, targetDate.month, targetDate.day, hour, minute
        );
        final reminderTime = classStartTime.subtract(const Duration(minutes: 9));

        expectedReminders[notificationId] = {
          'id': notificationId,
          'title': 'Class in 9 minutes',
          'body': '$subject • $room',
          'reminderTime': reminderTime,
          'payload': jsonEncode({
            'type': 'class_reminder',
            'mode': mode,
            'classId': eventId,
            'date': dateString,
            'eventKey': eventKey,
          }),
        };
      }
    }

    // 2. Fetch pending from platform
    final pendingRequests = await _notificationsPlugin.pendingNotificationRequests();
    
    int scheduledCount = 0;
    int cancelledCount = 0;
    
    // 3. Cancel stale
    for (var pending in pendingRequests) {
      bool isClassReminder = false;
      try {
        if (pending.payload != null) {
          final pMap = jsonDecode(pending.payload!);
          if (pMap['type'] == 'class_reminder') {
            isClassReminder = true;
          }
        }
      } catch (_) {}

      if (isClassReminder) {
        if (!expectedReminders.containsKey(pending.id)) {
          await _notificationsPlugin.cancel(pending.id);
          cancelledCount++;
          debugPrint('[ReminderManager] cancelled stale id=${pending.id}');
        } else {
          // Already scheduled, remove from expected list
          expectedReminders.remove(pending.id);
        }
      }
    }

    // 4. Schedule missing
    for (var entry in expectedReminders.values) {
      final id = entry['id'] as int;
      final reminderTime = entry['reminderTime'] as DateTime;
      
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          entry['title'] as String,
          entry['body'] as String,
          tz.TZDateTime.from(reminderTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'class_reminders',
              'Class Reminders',
              channelDescription: 'Reminders 9 minutes before class starts',
              importance: Importance.max,
              priority: Priority.high,
              autoCancel: true,
              playSound: true,
              enableVibration: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: entry['payload'] as String,
        );
        scheduledCount++;
        debugPrint('[ReminderManager] scheduled id=$id time=$reminderTime');
      } catch (e) {
        debugPrint('[ReminderManager] failed to schedule: $e');
      }
    }

    debugPrint('[ReminderManager] reconcile completed scheduled=$scheduledCount cancelled=$cancelledCount');
  }

  Future<void> clearAllForMode(String mode) async {
    if (!_initialized) return;
    final pendingRequests = await _notificationsPlugin.pendingNotificationRequests();
    for (var pending in pendingRequests) {
      try {
        if (pending.payload != null) {
          final pMap = jsonDecode(pending.payload!);
          if (pMap['type'] == 'class_reminder' && pMap['mode'] == mode) {
            await _notificationsPlugin.cancel(pending.id);
          }
        }
      } catch (_) {}
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
}
