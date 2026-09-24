import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:mobile/core/reminder_manager.dart';
import 'package:mobile/core/storage.dart';
import 'dart:io';

class FakeFlutterLocalNotificationsPlugin implements FlutterLocalNotificationsPlugin {
  final List<int> cancelledIds = [];
  final List<int> scheduledIds = [];
  int count = 0;

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledIds.add(id);
    scheduledIds.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #zonedSchedule) {
      final id = invocation.positionalArguments[0] as int;
      scheduledIds.add(id);
      count++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late FakeFlutterLocalNotificationsPlugin mockPlugin;

  setUp(() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    
    // Setup Hive for testing
    final path = Directory.systemTemp.createTempSync().path;
    Hive.init(path);
    await StorageService.init(isTest: true);
    await StorageService.setUserMode('student');

    mockPlugin = FakeFlutterLocalNotificationsPlugin();
    ReminderManager.instance.init(mockPlugin);
    
    // Ensure registry is clear
    await StorageService.clearReminderRegistry('student');
    await StorageService.clearReminderRegistry('faculty');
  });

  tearDown(() async {
    await Hive.close();
  });

  String getTodayString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String getDayName(int weekday) {
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

  test('Cancellation Test: Holiday cancels future reminder', () async {
    final today = getTodayString();
    final dayName = getDayName(DateTime.now().weekday);
    final now = DateTime.now();
    // Schedule a class 1 hour from now
    final classTime = now.add(const Duration(hours: 1));
    final startTimeStr = '${classTime.hour.toString().padLeft(2, '0')}:${classTime.minute.toString().padLeft(2, '0')}';

    final initialTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr,
      }
    ];

    // 1. Initial reconcile
    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: [],
      mode: 'student',
    );

    expect(mockPlugin.scheduledIds.length, 1, reason: 'Should schedule 1 reminder');
    final scheduledId = mockPlugin.scheduledIds.first;
    final registry1 = StorageService.getReminderRegistry('student');
    expect(registry1.length, 1);

    // 2. Update to holiday
    final overrides = [
      {
        'override_date': today,
      }
    ];

    mockPlugin.cancelledIds.clear();
    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: overrides,
      mode: 'student',
    );

    expect(mockPlugin.cancelledIds.contains(scheduledId), true, reason: 'Should cancel the reminder on holiday');
    final registry2 = StorageService.getReminderRegistry('student');
    expect(registry2.length, 0, reason: 'Registry should be empty for that date');
  });

  test('Removed Class Test: Removing class cancels old reminder', () async {
    final dayName = getDayName(DateTime.now().weekday);
    final now = DateTime.now();
    final classTime = now.add(const Duration(hours: 1));
    final startTimeStr = '${classTime.hour.toString().padLeft(2, '0')}:${classTime.minute.toString().padLeft(2, '0')}';

    final initialTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr,
      }
    ];

    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: [],
      mode: 'student',
    );

    expect(mockPlugin.scheduledIds.length, 1);
    final scheduledId = mockPlugin.scheduledIds.first;

    // Remove class
    final updatedTimetable = <Map<String, dynamic>>[];

    await ReminderManager.instance.reconcile(
      timetable: updatedTimetable,
      overrides: [],
      mode: 'student',
    );

    expect(mockPlugin.cancelledIds.contains(scheduledId), true);
    final registry = StorageService.getReminderRegistry('student');
    expect(registry.length, 0);
  });

  test('Time Change Test', () async {
    final dayName = getDayName(DateTime.now().weekday);
    final now = DateTime.now();
    final classTime1 = now.add(const Duration(hours: 1));
    final startTimeStr1 = '${classTime1.hour.toString().padLeft(2, '0')}:${classTime1.minute.toString().padLeft(2, '0')}';

    final initialTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr1,
      }
    ];

    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: [],
      mode: 'student',
    );

    expect(mockPlugin.scheduledIds.length, 1);
    final oldScheduledId = mockPlugin.scheduledIds.first;

    // Reschedule class
    final classTime2 = now.add(const Duration(hours: 2));
    final startTimeStr2 = '${classTime2.hour.toString().padLeft(2, '0')}:${classTime2.minute.toString().padLeft(2, '0')}';

    final updatedTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr2,
      }
    ];

    await ReminderManager.instance.reconcile(
      timetable: updatedTimetable,
      overrides: [],
      mode: 'student',
    );

    expect(mockPlugin.cancelledIds.contains(oldScheduledId), true, reason: 'Old reminder must be cancelled');
    expect(mockPlugin.scheduledIds.length, 1, reason: 'New reminder must be scheduled');
    expect(mockPlugin.scheduledIds.first != oldScheduledId, true);
  });

  test('Restore Class Test', () async {
    final today = getTodayString();
    final dayName = getDayName(DateTime.now().weekday);
    final now = DateTime.now();
    final classTime = now.add(const Duration(hours: 1));
    final startTimeStr = '${classTime.hour.toString().padLeft(2, '0')}:${classTime.minute.toString().padLeft(2, '0')}';

    final initialTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr,
      }
    ];
    final overrides = [{'override_date': today}];

    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: overrides,
      mode: 'student',
    );
    expect(mockPlugin.scheduledIds.length, 0);

    // Remove holiday
    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: [],
      mode: 'student',
    );
    expect(mockPlugin.scheduledIds.length, 1);
  });

  test('Mode Switch Test', () async {
    final dayName = getDayName(DateTime.now().weekday);
    final now = DateTime.now();
    final classTime = now.add(const Duration(hours: 1));
    final startTimeStr = '${classTime.hour.toString().padLeft(2, '0')}:${classTime.minute.toString().padLeft(2, '0')}';

    final initialTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr,
      }
    ];

    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: [],
      mode: 'student',
    );

    expect(mockPlugin.scheduledIds.length, 1);
    final studentRegistry = StorageService.getReminderRegistry('student');
    expect(studentRegistry.length, 1);

    // Switch to faculty (simulate via clearAllForMode on student)
    await ReminderManager.instance.clearAllForMode('student');
    expect(mockPlugin.scheduledIds.length, 0);
    expect(StorageService.getReminderRegistry('student').length, 0);
  });

  test('Past Event Safety', () async {
    final dayName = getDayName(DateTime.now().weekday);
    final now = DateTime.now();
    // Class was 1 hour ago
    final classTime = now.subtract(const Duration(hours: 1));
    final startTimeStr = '${classTime.hour.toString().padLeft(2, '0')}:${classTime.minute.toString().padLeft(2, '0')}';

    final initialTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr,
      }
    ];

    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: [],
      mode: 'student',
    );

    expect(mockPlugin.scheduledIds.length, 0, reason: 'Should not schedule past events');
  });
}
