import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:mobile/core/reminder_manager.dart';
import 'package:mobile/core/storage.dart';

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
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return scheduledIds
        .map((id) => PendingNotificationRequest(id, 'Class in 9 minutes', 'Class info', '{"type":"class_reminder","mode":"student"}'))
        .toList();
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
    TestWidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    final path = Directory.systemTemp.createTempSync().path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => path,
    );
    Hive.init(path);
    await StorageService.init();
    await StorageService.setUserMode('student');

    mockPlugin = FakeFlutterLocalNotificationsPlugin();
    ReminderManager.instance.init(mockPlugin);
  });

  tearDown(() async {
    await Hive.close();
  });

  String getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }

  String formatDate(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  test('Holiday Test: Scheduling then applying holiday cancels notification', () async {
    final targetDate = DateTime.now().add(const Duration(days: 1));
    final tomorrowDate = formatDate(targetDate);
    final dayName = getDayName(targetDate.weekday);
    const startTimeStr = '10:00';

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

    expect(mockPlugin.scheduledIds.length, 1, reason: 'Should schedule 1 reminder');
    final scheduledId = mockPlugin.scheduledIds.first;

    // Update to holiday
    final overrides = [
      {
        'override_date': tomorrowDate,
      }
    ];

    mockPlugin.cancelledIds.clear();
    await ReminderManager.instance.reconcile(
      timetable: initialTimetable,
      overrides: overrides,
      mode: 'student',
    );

    expect(mockPlugin.cancelledIds.contains(scheduledId), true, reason: 'Should cancel the reminder on holiday');
  });

  test('Removed Class Test: Removing class cancels old reminder', () async {
    final targetDate = DateTime.now().add(const Duration(days: 1));
    final dayName = getDayName(targetDate.weekday);
    const startTimeStr = '10:00';

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
  });

  test('Time Change Test', () async {
    final targetDate = DateTime.now().add(const Duration(days: 1));
    final dayName = getDayName(targetDate.weekday);
    const startTimeStr1 = '10:00';

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
    const startTimeStr2 = '14:00';

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
    final targetDate = DateTime.now().add(const Duration(days: 1));
    final tomorrowDate = formatDate(targetDate);
    final dayName = getDayName(targetDate.weekday);
    const startTimeStr = '10:00';

    final initialTimetable = [
      {
        'id': '101',
        'subject': 'Algorithms',
        'room': '8003',
        'day': dayName,
        'start_time': startTimeStr,
      }
    ];
    final overrides = [{'override_date': tomorrowDate}];

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
    final targetDate = DateTime.now().add(const Duration(days: 1));
    final dayName = getDayName(targetDate.weekday);
    const startTimeStr = '10:00';

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

    // Switch to faculty (simulate via clearAllForMode on student)
    await ReminderManager.instance.clearAllForMode('student');
    expect(mockPlugin.scheduledIds.length, 0);
  });

  test('Past Event Safety', () async {
    final dayName = getDayName(DateTime.now().weekday);
    // 01:00 AM today is always in the past by 11:00 PM
    const startTimeStr = '01:00';

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
