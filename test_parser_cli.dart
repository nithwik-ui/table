import 'dart:io';
import 'mobile/lib/core/sru/sru_timetable_parser.dart';
import 'mobile/lib/core/timetable_normalizer.dart';
import 'mobile/lib/core/sru/sru_profile_parser.dart';

void main() {
  final htmlContent = File('authenticated_timetable.html').readAsStringSync();
  
  final profile = SruProfileParser.parseProfile(htmlContent, 'student');
  print('PROFILE DETECTED: ' + profile['name']);
  
  final rawEntries = SruTimetableParser.parseTimetable(htmlContent);
  print('TIMETABLE CELLS FOUND: ' + rawEntries.length.toString());
  
  final normalized = TimetableNormalizer.normalize(rawEntries);
  print('CLASSES NORMALIZED: ' + normalized.length.toString());
}
