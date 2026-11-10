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
import 'package:mobile/core/auth/auth_repository.dart';
import 'package:mobile/core/auth/secure_session_store.dart';
import 'package:mobile/core/sraap/sraap_parser.dart';
import 'package:mobile/core/sync.dart';
import 'package:mobile/widgets/timetable_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureStorageValues = <String, String>{};

  setUpAll(() async {
    AppConstants.useSystemFontInTests = true;
    final path = Directory.systemTemp.createTempSync().path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => path,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          secureStorageValues[methodCall.arguments['key'] as String] =
              methodCall.arguments['value'] as String;
          return null;
        } else if (methodCall.method == 'read') {
          return secureStorageValues[methodCall.arguments['key'] as String];
        } else if (methodCall.method == 'delete') {
          secureStorageValues.remove(methodCall.arguments['key'] as String);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          secureStorageValues.clear();
          return null;
        } else if (methodCall.method == 'readAll') {
          return Map<String, String>.from(secureStorageValues);
        }
        return null;
      },
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

  group('7. Duplicate Countdown Badge Safety in TimetableCard & Repository', () {
    testWidgets('TimetableCard suppresses duplicate countdown when status already contains countdown', (WidgetTester tester) async {
      final mockClass = {
        'id': '101',
        'subject': 'Network Security',
        'faculty': 'Prof. Varma',
        'room': 'A-201',
        'start_time': '10:00',
        'end_time': '11:00',
        'ltp': 'Lecture',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimetableCard(
              classEvent: mockClass,
              status: 'Starts in 43 min',
              countdownText: 'Starts in 43 min',
              isToday: true,
            ),
          ),
        ),
      );

      // Verify "Starts in 43 min" appears EXACTLY ONCE (never duplicated!)
      expect(find.text('Starts in 43 min'), findsOneWidget);
    });
  });

  group('8. 1-Step OTP Session Renewal & Cooldown Engine', () {
    test('Credentials persistence and cooldown guards work cleanly', () async {
      await SecureSessionStore.saveSession({
        'identifier': '24BTCAICYB02',
        'password': 'test_password_123',
        'cookie': 'session=abc',
      }, role: 'student');

      final hasCreds = await AuthRepository.instance.hasSavedCredentials(role: 'student');
      expect(hasCreds, isTrue);

      expect(AuthRepository.instance.otpCooldownSecondsRemaining, equals(0));

      // Test clearing stale password on credential change
      await AuthRepository.instance.clearSavedPassword(role: 'student');
      final credsAfterClear = await AuthRepository.instance.hasSavedCredentials(role: 'student');
      expect(credsAfterClear, isFalse);
    });
  });

  group('9. Safe Browser HTML Import & Hourly Auto-Sync', () {
    test('importTimetableFromHtml parses .stt-slot HTML and updates cache & repository without hitting sruniv.com', () async {
      await StorageService.setUserMode('student');
      const sampleHtml = '''
      <ul>
        <li class="stt-slot" data-day="1" data-from="570" data-to="630">
          <div class="stt-class">
            <div class="stt-subject">Cloud Security</div>
            <div class="stt-type">Lecture</div>
            <div class="stt-room">Room 402</div>
            <div class="stt-person">Faculty Dr. Kumar</div>
          </div>
        </li>
      </ul>
      ''';

      final count = await SyncService.instance.importTimetableFromHtml(sampleHtml);
      expect(count, equals(1));
      expect(TimetableRepository.instance.classes.length, equals(1));
      expect(TimetableRepository.instance.classes.first['subject'], equals('Cloud Security'));
    });
  });

  group('10. SRAAP Internal Marks (CIE / ETE) & Detailed Subject Breakdown Parser', () {
    test('parseInternalMarks and parseCourseMarksDetail parse Examination Marks View and component breakdown accurately', () {
      const mid1Html = '''
      <html>
        <body>
          <h3>Examination Marks View</h3>
          <table class="table">
            <tr>
              <th>S.No</th>
              <th>Year-Sem</th>
              <th>Course</th>
              <th>CIE</th>
              <th>ETE</th>
              <th>View</th>
            </tr>
            <tr>
              <td>1</td>
              <td>3-1</td>
              <td>24CS301PC311-SOFTWARE ENGINEERING AND SYSTEM DESIGN</td>
              <td>17</td>
              <td>0</td>
              <td><a href="student_mid1.php?course_code=24CS301PC311"><img src="view.png"/></a></td>
            </tr>
            <tr>
              <td>2</td>
              <td>3-1</td>
              <td>24CS312ES301-ALGORITHMS</td>
              <td>18</td>
              <td>0</td>
              <td><a href="student_mid1.php?course_code=24CS312ES301"><img src="view.png"/></a></td>
            </tr>
          </table>
        </body>
      </html>
      ''';

      final courses = SraapParser.parseInternalMarks(mid1Html);
      expect(courses.length, equals(2));
      expect(courses[0].sNo, equals(1));
      expect(courses[0].yearSem, equals('3-1'));
      expect(courses[0].courseCode, equals('24CS301PC311'));
      expect(courses[0].courseName, equals('SOFTWARE ENGINEERING AND SYSTEM DESIGN'));
      expect(courses[0].cie, equals('17'));
      expect(courses[0].ete, equals('0'));
      expect(courses[0].detailHref, equals('/student/student_mid1.php?course_code=24CS301PC311'));

      const detailHtml = '''
      <html>
        <body>
          <h4>Course :SOFTWARE ENGINEERING AND SYSTEM DESIGN(24CS301PC311)</h4>
          <table border="1">
            <tr>
              <th>Mid Term Examination (20)</th>
              <th>Lab Exam (10)</th>
              <th>End Lab Exam (20)</th>
              <th>Project (10)</th>
              <th>Re Mid Marks</th>
              <th>End Term Examination (40)</th>
            </tr>
            <tr>
              <td>17</td>
              <td></td>
              <td></td>
              <td></td>
              <td></td>
              <td>0</td>
            </tr>
          </table>
        </body>
      </html>
      ''';

      final details = SraapParser.parseCourseMarksDetail(
        detailHtml,
        courseCode: '24CS301PC311',
      );
      expect(details.length, equals(6));
      expect(details[0].label, equals('Mid Term Examination (20)'));
      expect(details[0].value, equals('17'));
      expect(details[0].maxMarks, equals(20.0));
      expect(details[0].scoredMarks, equals(17.0));
      expect(details[1].label, equals('Lab Exam (10)'));
      expect(details[1].isEntered, isFalse);
      expect(details[5].label, equals('End Term Examination (40)'));
      expect(details[5].value, equals('0'));
      expect(details[5].isEndTerm, isTrue);
    });
  });
}
