import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/ad_service.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/core/storage.dart';
import 'package:mobile/core/theme_controller.dart';
import 'package:mobile/core/timetable_status_engine.dart';
import 'package:mobile/core/timetable/timetable_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final path = Directory.systemTemp.createTempSync().path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => path,
    );
    Hive.init(path);
    await StorageService.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('1. Data Freshness & Offline Timetable Preservation', () {
    test('lastSyncedAt is preserved from storage on loadFromCache and not overwritten on app launch', () async {
      await StorageService.setUserMode('student');
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      await StorageService.saveLastSyncedAt(twoHoursAgo);
      await StorageService.saveTimetableCache([
        {
          'id': 'c1',
          'subject': 'Operating Systems',
          'faculty': 'Dr. Sharma',
          'room': 'A-101',
          'day': 'Monday',
          'start_time': '09:30',
          'end_time': '10:30',
        }
      ]);

      TimetableRepository.instance.loadFromCache();

      expect(TimetableRepository.instance.classes.length, equals(1));
      expect(TimetableRepository.instance.metadata.lastUpdated, isNotNull);
      expect(
        TimetableRepository.instance.metadata.lastUpdated!.difference(twoHoursAgo).inSeconds.abs(),
        lessThan(2),
      );
    });
  });

  group('2. Class Status Engine & Countdown Tests', () {
    final sampleClass = {
      'id': 'cls_1',
      'subject': 'Compiler Design',
      'faculty': 'Prof. Rao',
      'room': 'B-202',
      'day': 'Monday',
      'start_time': '09:30',
      'end_time': '10:30',
    };

    test('Yesterday, Today before/during/after, Tomorrow, and Future date statuses', () {
      final now = DateTime(2026, 11, 3, 10, 0); // Today 10:00 AM
      final yesterday = DateTime(2026, 11, 2);
      final today = DateTime(2026, 11, 3);
      final tomorrow = DateTime(2026, 11, 4);
      final futureDate = DateTime(2026, 11, 10);

      // Yesterday -> Completed
      expect(
        TimetableStatusEngine.getStatus(
          classData: sampleClass,
          referenceDate: yesterday,
          nowLocal: now,
        ),
        equals(ClassStatus.completed),
      );

      // Today before class (09:12 AM) -> Upcoming + "Starts in 18 min"
      final beforeClass = DateTime(2026, 11, 3, 9, 12);
      expect(
        TimetableStatusEngine.getStatus(
          classData: sampleClass,
          referenceDate: today,
          nowLocal: beforeClass,
        ),
        equals(ClassStatus.upcoming),
      );
      expect(
        TimetableStatusEngine.getCountdownText(
          classData: sampleClass,
          referenceDate: today,
          nowLocal: beforeClass,
        ),
        equals('Starts in 18 min'),
      );

      // Today during class (09:58 AM) -> Ongoing + "Ends in 32 min"
      final duringClass = DateTime(2026, 11, 3, 9, 58);
      expect(
        TimetableStatusEngine.getStatus(
          classData: sampleClass,
          referenceDate: today,
          nowLocal: duringClass,
        ),
        equals(ClassStatus.ongoing),
      );
      expect(
        TimetableStatusEngine.getCountdownText(
          classData: sampleClass,
          referenceDate: today,
          nowLocal: duringClass,
        ),
        equals('Ends in 32 min'),
      );

      // Today after class (11:00 AM) -> Completed
      final afterClass = DateTime(2026, 11, 3, 11, 0);
      expect(
        TimetableStatusEngine.getStatus(
          classData: sampleClass,
          referenceDate: today,
          nowLocal: afterClass,
        ),
        equals(ClassStatus.completed),
      );

      // Tomorrow (evaluated at 11:00 PM tonight) -> ALWAYS Upcoming
      expect(
        TimetableStatusEngine.getStatus(
          classData: sampleClass,
          referenceDate: tomorrow,
          nowLocal: DateTime(2026, 11, 3, 23, 0),
        ),
        equals(ClassStatus.upcoming),
      );

      // Future date -> ALWAYS Upcoming
      expect(
        TimetableStatusEngine.getStatus(
          classData: sampleClass,
          referenceDate: futureDate,
          nowLocal: DateTime(2026, 11, 3, 23, 0),
        ),
        equals(ClassStatus.upcoming),
      );
    });
  });

  group('3. Dark Mode, Light Mode, System Theme & Persistence', () {
    test('ThemeController switches Light, Dark, and System and persists to StorageService', () async {
      ThemeController.instance.init();

      // Default or explicit System
      await ThemeController.instance.setThemeMode(ThemeMode.system);
      expect(StorageService.getThemeMode(), equals('system'));
      expect(ThemeController.instance.themeMode, equals(ThemeMode.system));

      // System with Dark platform brightness
      ThemeController.instance.setTestPlatformBrightness(Brightness.dark);
      expect(ThemeController.instance.isDark, isTrue);
      expect(AppConstants.isDark, isTrue);
      expect(AppConstants.background, equals(const Color(0xFF0B1120)));
      expect(AppConstants.surface, equals(const Color(0xFF131C31)));

      // Switch to Light mode explicitly
      await ThemeController.instance.setThemeMode(ThemeMode.light);
      expect(StorageService.getThemeMode(), equals('light'));
      expect(ThemeController.instance.isDark, isFalse);
      expect(AppConstants.isDark, isFalse);
      expect(AppConstants.background, equals(const Color(0xFFF8FAFC)));
      expect(AppConstants.surface, equals(const Color(0xFFFFFFFF)));

      // Switch to Dark mode explicitly
      await ThemeController.instance.setThemeMode(ThemeMode.dark);
      expect(StorageService.getThemeMode(), equals('dark'));
      expect(ThemeController.instance.isDark, isTrue);
      expect(AppConstants.isDark, isTrue);

      // Reset test brightness override
      ThemeController.instance.setTestPlatformBrightness(null);
      await ThemeController.instance.setThemeMode(ThemeMode.system);
    });
  });

  group('4. AdService Central InMobi Isolation & Failure Resilience', () {
    test('AdService handles unavailable SDK gracefully without crashing', () async {
      AdService.instance.resetDiagnosticsForTest();
      AdService.instance.simulateUnavailable = true;

      await AdService.instance.initialize();
      final loaded = await AdService.instance.loadBanner();

      expect(loaded.isSuccess, isFalse);
      expect(AdService.instance.isBannerReady, isFalse);
      expect(AdService.instance.diagnostics['network'], equals('InMobi'));
      expect(AdService.instance.diagnostics['format'], equals('Banner'));

      AdService.instance.simulateUnavailable = false;
    });
  });

  group('5. Notification Reminder Preferences (OFF, 9m)', () {
    test('Persists 0 (OFF) and 9 min reminder preferences cleanly', () async {
      await StorageService.setClassReminderMinutes(0);
      expect(StorageService.getClassReminderMinutes(), equals(0));
      expect(StorageService.isClassRemindersEnabled(), isFalse);

      await StorageService.setClassReminderMinutes(9);
      expect(StorageService.getClassReminderMinutes(), equals(9));
      expect(StorageService.isClassRemindersEnabled(), isTrue);

      // Legacy 15 and 30 min migration cleanly migrates to 9
      await StorageService.setClassReminderMinutes(15);
      expect(StorageService.getClassReminderMinutes(), equals(9));

      await StorageService.setClassReminderMinutes(30);
      expect(StorageService.getClassReminderMinutes(), equals(9));
    });
  });

  group('6. Timetable Search & Weekly Statistics', () {
    final weekClasses = [
      {
        'id': '1',
        'subject': 'Operating Systems',
        'faculty': 'Dr. Sharma',
        'room': 'A-101',
        'day': 'Monday',
        'type': 'LEC',
        'start_time': '09:30',
        'end_time': '10:30',
      },
      {
        'id': '2',
        'subject': 'Operating Systems Lab',
        'faculty': 'Dr. Sharma',
        'room': 'Lab-302',
        'day': 'Monday',
        'type': 'LAB',
        'start_time': '11:30',
        'end_time': '12:30',
      },
      {
        'id': '3',
        'subject': 'Artificial Intelligence',
        'faculty': 'Prof. Reddy',
        'room': 'B-204',
        'day': 'Tuesday',
        'type': 'LEC',
        'start_time': '09:30',
        'end_time': '10:30',
      },
      {
        'id': '4',
        'subject': 'Algorithms',
        'faculty': 'Prof. Gupta',
        'room': 'B-204',
        'day': 'Tuesday',
        'type': 'LEC',
        'start_time': '10:30',
        'end_time': '11:30',
      },
      {
        'id': '5',
        'subject': 'Database Systems',
        'faculty': 'Dr. Rao',
        'room': 'C-105',
        'day': 'Tuesday',
        'type': 'LEC',
        'start_time': '11:30',
        'end_time': '12:30',
      },
    ];

    test('Instant local search matches Subject, Faculty, and Room', () {
      final bySubject = TimetableRepository.searchClasses(weekClasses, 'Operating');
      expect(bySubject.length, equals(2));

      final byFaculty = TimetableRepository.searchClasses(weekClasses, 'Reddy');
      expect(byFaculty.length, equals(1));
      expect(byFaculty.first['subject'], equals('Artificial Intelligence'));

      final byRoom = TimetableRepository.searchClasses(weekClasses, 'B-204');
      expect(byRoom.length, equals(2));
    });

    test('Weekly statistics accurately counts classes, labs, free periods, busiest and lightest day', () {
      final stats = TimetableStatusEngine.calculateWeeklyStats(weekClasses);
      expect(stats.totalClasses, equals(5));
      expect(stats.labsCount, equals(1));
      expect(stats.freePeriodsCount, equals(1)); // Monday 10:30-11:30 gap
      expect(stats.busiestDay, equals('Tuesday')); // 3 classes on Tuesday vs 2 on Monday
      expect(stats.lightestDay, equals('Monday'));
    });
  });
}
