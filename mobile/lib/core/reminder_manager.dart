import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey;
import 'storage.dart';
import 'web_notifications.dart';

class ReminderManager {
  static final ReminderManager instance = ReminderManager._internal();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;

  Timer? _webReminderTimer;
  final Map<int, Map<String, dynamic>> _webExpectedReminders = {};
  final Set<String> _firedReminderKeysToday = {};
  String _lastFiredDateStr = '';

  ReminderManager._internal();

  void init(FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
    _initialized = true;
  }

  /// Active reminder lead time in minutes (0 = OFF, 15 = 15m before, 30 = 30m before).
  int get leadMinutes => StorageService.getClassReminderMinutes();

  // Parses HH:MM to int minutes
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool isReminderEligible(
    dynamic event,
    List<dynamic> overrides,
    DateTime targetDate, {
    int? overrideLeadMinutes,
  }) {
    if (event == null) return false;
    final mins = overrideLeadMinutes ?? leadMinutes;
    if (mins <= 0) return false;
    if (event['is_struck_off'] == true ||
        event['is_cancelled'] == true ||
        event['isCancelled'] == true) {
      return false;
    }

    final dateString = _formatDate(targetDate);

    try {
      final matchingHolidays = overrides.where(
        (ov) => ov['override_date'] == dateString && ov['is_holiday'] != false,
      );
      if (matchingHolidays.isNotEmpty) return false;
    } catch (_) {}

    final startTimeStr = event['start_time']?.toString();
    if (startTimeStr == null || startTimeStr.isEmpty) return false;

    final timeParts = startTimeStr.split(':');
    if (timeParts.length != 2) return false;

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return false;

    final classStartTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );

    final reminderTime = classStartTime.subtract(Duration(minutes: mins));
    if (reminderTime.isBefore(DateTime.now())) return false;

    return true;
  }

  Future<void> reconcile({
    required List<dynamic> timetable,
    required List<dynamic> overrides,
    required String mode,
  }) async {
    final mins = leadMinutes;
    if (mins <= 0) {
      await clearAllForMode(mode);
      return;
    }

    if (kIsWeb) {
      _reconcileWebReminders(
        timetable: timetable,
        overrides: overrides,
        mode: mode,
        leadMins: mins,
      );
      return;
    }

    if (!_initialized) return;
    debugPrint('[ReminderManager] reconcile started for mode: $mode (lead=${mins}m)');

    // 1. Generate canonical events
    final now = DateTime.now();
    final Map<int, Map<String, dynamic>> expectedReminders = {};

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final dayName = _getDayName(targetDate.weekday);
      final dateString = _formatDate(targetDate);

      // Get classes for day and sort by start time (case-insensitive day comparison)
      List<dynamic> dayClasses = timetable.where((c) {
        final cDay = c['day']?.toString().toLowerCase().trim() ?? '';
        return cDay == dayName.toLowerCase().trim();
      }).toList();
      dayClasses.sort((a, b) =>
          _timeToMinutes(a['start_time'] ?? '00:00')
              .compareTo(_timeToMinutes(b['start_time'] ?? '00:00')));

      // Merge continuous classes
      List<dynamic> mergedClasses = [];
      for (var cls in dayClasses) {
        if (mergedClasses.isEmpty) {
          mergedClasses.add(Map<String, dynamic>.from(cls as Map));
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
            mergedClasses.add(Map<String, dynamic>.from(cls as Map));
          }
        }
      }

      for (final event in mergedClasses) {
        if (!isReminderEligible(event, overrides, targetDate, overrideLeadMinutes: mins)) {
          continue;
        }

        final subject = event['subject']?.toString() ?? 'Class';
        final room = event['room']?.toString() ?? 'TBD';
        final startTimeStr = event['start_time']?.toString() ?? '';
        final eventId = event['id']?.toString() ?? 'merged';
        final faculty = event['faculty']?.toString() ?? '';

        final eventKey = '$mode|$dateString|$startTimeStr|$subject|$faculty|$room|$mins';
        final notificationId = eventKey.hashCode.abs() % 100000;

        final timeParts = startTimeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final classStartTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );
        final reminderTime = classStartTime.subtract(Duration(minutes: mins));

        expectedReminders[notificationId] = {
          'id': notificationId,
          'title': 'Class in $mins minutes',
          'body': '$subject • $room',
          'reminderTime': reminderTime,
          'payload': jsonEncode({
            'type': 'class_reminder',
            'mode': mode,
            'classId': eventId,
            'date': dateString,
            'eventKey': eventKey,
            'leadMinutes': mins,
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
          NotificationDetails(
            android: AndroidNotificationDetails(
              'class_reminders',
              'Class Reminders',
              channelDescription: 'Reminders before class starts',
              importance: Importance.max,
              priority: Priority.high,
              autoCancel: true,
              playSound: true,
              enableVibration: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: entry['payload'] as String,
        );
        scheduledCount++;
        debugPrint('[ReminderManager] scheduled exact id=$id time=$reminderTime');
      } catch (e) {
        debugPrint('[ReminderManager] exact alarm failed ($e), falling back to inexact...');
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            entry['title'] as String,
            entry['body'] as String,
            tz.TZDateTime.from(reminderTime, tz.local),
            NotificationDetails(
              android: AndroidNotificationDetails(
                'class_reminders',
                'Class Reminders',
                channelDescription: 'Reminders before class starts',
                importance: Importance.max,
                priority: Priority.high,
                autoCancel: true,
                playSound: true,
                enableVibration: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: entry['payload'] as String,
          );
          scheduledCount++;
          debugPrint('[ReminderManager] scheduled inexact fallback id=$id time=$reminderTime');
        } catch (e2) {
          debugPrint('[ReminderManager] failed to schedule fallback: $e2');
        }
      }
    }

    debugPrint(
        '[ReminderManager] reconcile completed scheduled=$scheduledCount cancelled=$cancelledCount');
  }

  void _reconcileWebReminders({
    required List<dynamic> timetable,
    required List<dynamic> overrides,
    required String mode,
    required int leadMins,
  }) {
    _webExpectedReminders.clear();
    final now = DateTime.now();

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final dayName = _getDayName(targetDate.weekday);
      final dateString = _formatDate(targetDate);

      List<dynamic> dayClasses = timetable.where((c) {
        final cDay = c['day']?.toString().toLowerCase().trim() ?? '';
        return cDay == dayName.toLowerCase().trim();
      }).toList();
      dayClasses.sort((a, b) =>
          _timeToMinutes(a['start_time'] ?? '00:00')
              .compareTo(_timeToMinutes(b['start_time'] ?? '00:00')));

      List<dynamic> mergedClasses = [];
      for (var cls in dayClasses) {
        if (mergedClasses.isEmpty) {
          mergedClasses.add(Map<String, dynamic>.from(cls as Map));
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
            mergedClasses.add(Map<String, dynamic>.from(cls as Map));
          }
        }
      }

      for (final event in mergedClasses) {
        final startTimeStr = event['start_time']?.toString() ?? '';
        if (startTimeStr.isEmpty) continue;
        final timeParts = startTimeStr.split(':');
        if (timeParts.length != 2) continue;
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (hour == null || minute == null) continue;

        final classStartTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );
        final reminderTime = classStartTime.subtract(Duration(minutes: leadMins));

        final subject = event['subject']?.toString() ?? 'Class';
        final room = event['room']?.toString() ?? 'TBD';
        final faculty = event['faculty']?.toString() ?? '';
        final eventKey = '$mode|$dateString|$startTimeStr|$subject|$faculty|$room|$leadMins';
        final notificationId = eventKey.hashCode.abs() % 100000;

        _webExpectedReminders[notificationId] = {
          'id': notificationId,
          'title': 'Class in $leadMins minutes',
          'body': '$subject • $room',
          'reminderTime': reminderTime,
          'classStartTime': classStartTime,
          'eventKey': eventKey,
        };
      }
    }

    _webReminderTimer?.cancel();
    _checkAndFireWebReminders();
    _webReminderTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkAndFireWebReminders();
    });
    debugPrint(
        '[ReminderManager] Web reminder engine reconciled (${_webExpectedReminders.length} scheduled, lead=${leadMins}m)');
  }

  void _checkAndFireWebReminders() {
    if (_webExpectedReminders.isEmpty) return;
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    if (_lastFiredDateStr != todayStr) {
      _firedReminderKeysToday.clear();
      _lastFiredDateStr = todayStr;
    }

    for (final entry in _webExpectedReminders.values) {
      final reminderTime = entry['reminderTime'] as DateTime;
      final classStartTime = entry['classStartTime'] as DateTime;
      final eventKey = entry['eventKey'] as String;

      if (now.isAfter(reminderTime) && now.isBefore(classStartTime)) {
        if (!_firedReminderKeysToday.contains(eventKey)) {
          _firedReminderKeysToday.add(eventKey);
          final title = entry['title'] as String;
          final body = entry['body'] as String;
          debugPrint('[ReminderManager] Firing Web class reminder: $title - $body');

          WebNotifications.show(
            title: title,
            body: body,
            tag: eventKey,
          );
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              duration: const Duration(seconds: 8),
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      }
    }
  }

  Future<void> clearAllForMode(String mode) async {
    if (kIsWeb) {
      _webReminderTimer?.cancel();
      _webExpectedReminders.clear();
      return;
    }
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
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
