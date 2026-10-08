import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/timetable_normalizer.dart';

void main() {
  group('TimetableNormalizer', () {
    test('removes exact duplicates', () {
      final raw = [
        {
          "day": "Monday",
          "start_time": "09:30",
          "end_time": "10:30",
          "subject": "Math",
          "faculty": "Mr. X",
          "room": "BL1-10",
          "ltp": "L"
        },
        {
          "day": "Monday",
          "start_time": "09:30",
          "end_time": "10:30",
          "subject": "Math",
          "faculty": "Mr. X",
          "room": "BL1-10",
          "ltp": "L"
        }
      ];

      final normalized = TimetableNormalizer.normalize(raw);
      expect(normalized.length, 1);
      expect(normalized[0]['subject'], 'Math');
    });

    test('merges contiguous blocks of the same class', () {
      final raw = [
        {
          "day": "Monday",
          "start_time": "13:30",
          "end_time": "14:30",
          "subject": "Physics Lab",
          "faculty": "Dr. Y",
          "room": "Lab 2",
          "ltp": "P"
        },
        {
          "day": "Monday",
          "start_time": "14:30",
          "end_time": "15:30",
          "subject": "Physics Lab",
          "faculty": "Dr. Y",
          "room": "Lab 2",
          "ltp": "P"
        }
      ];

      final normalized = TimetableNormalizer.normalize(raw);
      expect(normalized.length, 1);
      expect(normalized[0]['start_time'], '13:30');
      expect(normalized[0]['end_time'], '15:30');
    });

    test('groups simultaneous options into a single entry with options array', () {
      final raw = [
        {
          "day": "Tuesday",
          "start_time": "10:30",
          "end_time": "11:30",
          "subject": "Elective A",
          "faculty": "Prof A",
          "room": "R1",
          "ltp": "L"
        },
        {
          "day": "Tuesday",
          "start_time": "10:30",
          "end_time": "11:30",
          "subject": "Elective B",
          "faculty": "Prof B",
          "room": "R2",
          "ltp": "L"
        }
      ];

      final normalized = TimetableNormalizer.normalize(raw);
      expect(normalized.length, 1);
      expect(normalized[0]['is_choice'], true);
      expect(normalized[0]['options'], isNotNull);
      expect(normalized[0]['options'].length, 2);
      expect(normalized[0]['options'][0]['subject'], 'Elective A');
      expect(normalized[0]['options'][1]['subject'], 'Elective B');
    });
  });
}
