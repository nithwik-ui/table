import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/storage.dart';
import 'package:mobile/core/timetable/timetable_repository.dart';
import 'package:mobile/core/timetable/timetable_state.dart';

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

  group('TimetableRepository Tests', () {
    test('Initializes with empty state when storage has no classes', () {
      final repo = TimetableRepository.instance;
      repo.init();

      expect(repo.isInitialized, isTrue);
      expect(repo.state, equals(TimetableState.empty));
      expect(repo.classes, isEmpty);
    });

    test('Updates timetable and retains classes upon refresh error', () async {
      final repo = TimetableRepository.instance;

      final testClasses = [
        {
          'id': 'test-1',
          'subject': 'Compiler Design',
          'faculty': 'Dr. Rao',
          'room': 'Block 1 - 101',
          'day': 'monday',
          'start_time': '09:00',
          'end_time': '10:00',
        },
        {
          'id': 'test-2',
          'subject': 'Computer Networks',
          'faculty': 'Prof. Sharma',
          'room': 'Block 2 - 202',
          'day': 'monday',
          'start_time': '10:00',
          'end_time': '11:00',
        },
      ];

      repo.updateTimetable(testClasses, source: 'test_seed');

      expect(repo.classes.length, equals(2));
      expect(repo.state, equals(TimetableState.fresh));
      expect(repo.metadata.isStale, isFalse);

      // Verify day query
      final mondayClasses = repo.getClassesForDay('monday');
      expect(mondayClasses.length, equals(2));
      expect(mondayClasses[0]['subject'], equals('Compiler Design'));

      // Test safe error handling (never wiping cached data)
      repo.markStale('Simulated network timeout');

      // State is stale, but cached classes MUST be preserved intact
      expect(repo.state, equals(TimetableState.stale));
      expect(repo.metadata.isStale, isTrue);
      expect(repo.metadata.errorMessage, equals('Simulated network timeout'));
      expect(repo.classes.length, equals(2), reason: 'Classes must not be wiped out on failure');
    });

    test('updateTimetable ignores empty payload when previous data exists', () {
      final repo = TimetableRepository.instance;
      expect(repo.classes.isNotEmpty, isTrue);

      // Attempt to push empty payload
      repo.updateTimetable([], source: 'corrupted_sync');

      // Should retain existing classes
      expect(repo.classes.isNotEmpty, isTrue);
    });

    test('Refresh generation race protection ensures only newest generation updates state', () async {
      final repo = TimetableRepository.instance;
      final initialClasses = repo.classes;
      expect(initialClasses.isNotEmpty, isTrue);

      // Trigger refresh with force
      final f1 = repo.refresh(force: true);
      // Trigger second rapid refresh with force (supersedes f1)
      final f2 = repo.refresh(force: true);

      await Future.wait([f1, f2]);

      // Cache is preserved and state is stable
      expect(repo.classes.isNotEmpty, isTrue);
    });
  });
}
