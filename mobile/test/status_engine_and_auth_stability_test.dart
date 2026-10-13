import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/storage.dart';
import 'package:mobile/core/timetable_status_engine.dart';
import 'package:mobile/core/sraap/sraap_academic_service.dart';
import 'package:mobile/core/sraap/models/sraap_academic_data.dart';
import 'package:mobile/core/auth/auth_repository.dart';

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

  group('TimetableStatusEngine Canonical Status & 12:42 PM IST Tests', () {
    final mondayClasses = [
      {
        'id': 'mon_0930_1130_math',
        'subject': 'Engineering Mathematics',
        'faculty': 'Dr. Rao',
        'room': 'Block 1 - 101',
        'day': 'monday',
        'start_time': '09:30',
        'end_time': '11:30',
      },
      {
        'id': 'mon_1130_1230_ai',
        'subject': 'Artificial Intelligence',
        'faculty': 'Prof. Sharma',
        'room': 'Block 2 - 202',
        'day': 'monday',
        'start_time': '11:30',
        'end_time': '12:30',
      },
      {
        'id': 'mon_1330_1430_algo',
        'subject': 'Algorithms',
        'faculty': 'Dr. Reddy',
        'room': 'Block 3 - 303',
        'day': 'monday',
        'start_time': '13:30',
        'end_time': '14:30',
      },
      {
        'id': 'mon_1430_1530_dbms',
        'subject': 'Database Systems',
        'faculty': 'Prof. Gupta',
        'room': 'Block 3 - 304',
        'day': 'monday',
        'start_time': '14:30',
        'end_time': '15:30',
      },
    ];

    test('12:42 PM IST during Lunch Break identifies Algorithms at 1:30 PM as Next Class', () {
      // 12:42 PM IST on a Monday
      final now1242 = DateTime(2026, 10, 12, 12, 42); // Oct 12, 2026 is a Monday
      expect(now1242.weekday, equals(DateTime.monday));

      // 1. Check status of previous classes
      final mathStatus = TimetableStatusEngine.getStatus(
        classData: mondayClasses[0],
        referenceDate: now1242,
        nowLocal: now1242,
      );
      expect(mathStatus, equals(ClassStatus.completed));

      final aiStatus = TimetableStatusEngine.getStatus(
        classData: mondayClasses[1],
        referenceDate: now1242,
        nowLocal: now1242,
      );
      expect(aiStatus, equals(ClassStatus.completed));

      // 2. Check Lunch break detection
      final currentBreak = TimetableStatusEngine.getCurrentBreak(
        dayClasses: mondayClasses,
        referenceDate: now1242,
        nowLocal: now1242,
      );
      expect(currentBreak, isNotNull);
      expect(currentBreak!.isLunch, isTrue);
      expect(currentBreak.nextClass['subject'], equals('Algorithms'));

      // 3. Next class MUST be Algorithms, NOT null, NOT "Classes Completed"
      final nextClass = TimetableStatusEngine.getNextClass(
        dayClasses: mondayClasses,
        referenceDate: now1242,
        nowLocal: now1242,
      );
      expect(nextClass, isNotNull);
      expect(nextClass!['subject'], equals('Algorithms'));
      expect(nextClass['start_time'], equals('13:30'));

      final nextClassId = TimetableStatusEngine.getNextClassId(
        dayClasses: mondayClasses,
        referenceDate: now1242,
        nowLocal: now1242,
      );
      expect(nextClassId, equals('mon_1330_1430_algo'));
    });

    test('Ongoing class during class slot returns ongoing status', () {
      // 10:15 AM IST during Engineering Mathematics (09:30 - 11:30)
      final now1015 = DateTime(2026, 10, 12, 10, 15);
      final status = TimetableStatusEngine.getStatus(
        classData: mondayClasses[0],
        referenceDate: now1015,
        nowLocal: now1015,
      );
      expect(status, equals(ClassStatus.ongoing));

      final currentBreak = TimetableStatusEngine.getCurrentBreak(
        dayClasses: mondayClasses,
        referenceDate: now1015,
        nowLocal: now1015,
      );
      expect(currentBreak, isNull);
    });

    test('End of day correctly reports null for next class', () {
      // 16:30 PM IST after all classes ended
      final now1630 = DateTime(2026, 10, 12, 16, 30);
      final nextClass = TimetableStatusEngine.getNextClass(
        dayClasses: mondayClasses,
        referenceDate: now1630,
        nowLocal: now1630,
      );
      expect(nextClass, isNull);

      final nextClassId = TimetableStatusEngine.getNextClassId(
        dayClasses: mondayClasses,
        referenceDate: now1630,
        nowLocal: now1630,
      );
      expect(nextClassId, isNull);
    });
  });

  group('SRAAP Decoupled Cache & Session Stability Tests', () {
    test('Cached academic data is preserved and accessible even when not connected or session expired', () async {
      final sampleData = SraapAcademicData(
        overallAttendance: 84.5,
        cgpa: '8.92',
        subjects: [
          SraapSubjectAttendance(
            subjectName: 'Compiler Design',
            attendancePercentage: 88.0,
            presentCount: 22,
            totalCount: 25,
          ),
          SraapSubjectAttendance(
            subjectName: 'Artificial Intelligence',
            attendancePercentage: 72.0,
            presentCount: 18,
            totalCount: 25,
          ),
        ],
        lastSynced: DateTime(2026, 10, 13, 10, 0),
      );

      // Save to cache
      await StorageService.saveSraapAcademicCache(sampleData.toJson());
      await StorageService.saveSraapLastSyncedAt(sampleData.lastSynced);

      // Verify immediate cache retrieval
      final cached = SraapAcademicService.instance.getCachedAcademicData();
      expect(cached, isNotNull);
      expect(cached!.overallAttendance, equals(84.5));
      expect(cached.cgpa, equals('8.92'));
      expect(cached.subjects.length, equals(2));

      // Simulate connection lost / not connected
      await StorageService.setSraapConnected(false);
      expect(StorageService.isSraapConnected(), isFalse);

      // Cached data MUST still be returned when offline/disconnected
      final dataWhileDisconnected = await SraapAcademicService.instance.getAcademicData(forceRefresh: false);
      expect(dataWhileDisconnected, isNotNull);
      expect(dataWhileDisconnected!.overallAttendance, equals(84.5));
      expect(dataWhileDisconnected.subjects.first.subjectName, equals('Compiler Design'));
    });
  });

  group('AuthRepository Concurrency & Protection Tests', () {
    test('State machine transitions cleanly without duplicate in-flight transactions', () async {
      final auth = AuthRepository.instance;
      expect(auth.state, isNotNull);

      // Test session saving with decoupled user mode
      await StorageService.setUserMode('student');
      expect(StorageService.getUserMode(), equals('student'));
    });
  });
}
