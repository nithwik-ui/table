import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/sru/sru_timetable_parser.dart';
import 'package:mobile/core/timetable_normalizer.dart';
import 'package:mobile/core/sru/sru_profile_parser.dart';

void main() {
  test('Test SRU Parser against authenticated HTML dump', () {
    final file = File('../authenticated_timetable.html');
    if (!file.existsSync()) {
      return; // Skip if offline HTML dump is not present
    }
    final htmlContent = file.readAsStringSync();
    
    final profile = SruProfileParser.parseProfile(htmlContent, 'student');
    final rawEntries = SruTimetableParser.parseTimetable(htmlContent);
    final normalized = TimetableNormalizer.normalize(rawEntries);
    
    expect(profile['name'], isNotNull);
    expect(rawEntries.length, greaterThan(0));
    expect(normalized.length, greaterThan(0));
  });
}
