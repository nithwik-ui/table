import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/sru/sru_timetable_parser.dart';
import '../lib/core/timetable_normalizer.dart';
import '../lib/core/sru/sru_profile_parser.dart';

void main() {
  test('Test SRU Parser against authenticated HTML dump', () {
    final htmlContent = File('../authenticated_timetable.html').readAsStringSync();
    
    final profile = SruProfileParser.parseProfile(htmlContent, 'student');
    print("PROFILE DETECTED: \${profile['name']}");
    
    final rawEntries = SruTimetableParser.parseTimetable(htmlContent);
    print('TIMETABLE CELLS FOUND: \${rawEntries.length}');
    if (rawEntries.isNotEmpty) {
      print('FIRST CELL: \${rawEntries.first}');
    }
    
    final normalized = TimetableNormalizer.normalize(rawEntries);
    print('CLASSES NORMALIZED: \${normalized.length}');
    if (normalized.isNotEmpty) {
      print('FIRST NORMALIZED CLASS: \${normalized.first}');
    }
    
    expect(profile['name'], isNotNull);
    expect(rawEntries.length, greaterThan(0));
    expect(normalized.length, greaterThan(0));
  });
}
