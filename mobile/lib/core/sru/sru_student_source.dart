import 'package:flutter/foundation.dart';
import 'sru_auth_client.dart';
import 'sru_timetable_parser.dart';
import 'sru_profile_parser.dart';
import '../timetable_normalizer.dart';
import '../storage.dart';

class SruStudentSource {
  static final SruStudentSource instance = SruStudentSource._();
  SruStudentSource._();

  Future<Map<String, dynamic>> fetchProfile() async {
    // 1. Try /student/details
    try {
      final detailsRes = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/student/details');
      if (detailsRes.statusCode == 200 && !detailsRes.body.toLowerCase().contains('login')) {
        final profile = SruProfileParser.parseProfile(detailsRes.body, 'student');
        if (profile['name'] != null && profile['name'] != 'Student' && profile['name'] != 'User') {
          return profile;
        }
      }
    } catch (e) {
      debugPrint('Student details fetch non-fatal: $e');
    }

    // 2. Try /student/timetable (contains Welcome: <Name> and My Timetable - <Batch>)
    try {
      final ttRes = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/student/timetable');
      if (ttRes.statusCode == 200 && !ttRes.body.toLowerCase().contains('login')) {
        final profile = SruProfileParser.parseProfile(ttRes.body, 'student');
        return profile;
      }
    } catch (e) {
      debugPrint('Student timetable profile fetch non-fatal: $e');
    }

    // 3. Fallback to existing or default profile
    return SruProfileParser.parseProfile('', 'student');
  }

  Future<List<dynamic>> fetchTimetable() async {
    final response = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/student/timetable');
    if (response.statusCode == 200) {
      if (response.body.toLowerCase().contains('login') && response.body.toLowerCase().contains('password')) {
        throw Exception('SRU session expired');
      }

      // Auto-extract and save profile from timetable HTML
      try {
        final profile = SruProfileParser.parseProfile(response.body, 'student');
        if (profile.isNotEmpty) {
          await StorageService.saveProfile(profile);
          if (profile['name'] != null && profile['name'] != 'Student') {
            await StorageService.saveUserName(profile['name']);
          }
          if (profile['id'] != null && profile['id'] != 'Unknown') {
            await StorageService.saveStudentRollNumber(profile['id']);
          }
        }
      } catch (e) {
        debugPrint('Auto-extract profile non-fatal error: $e');
      }

      final rawEntries = SruTimetableParser.parseTimetable(response.body, source: 'sru_authenticated_student');
      return TimetableNormalizer.normalize(rawEntries);
    }
    throw Exception('Failed to load timetable: status ${response.statusCode}');
  }
}

