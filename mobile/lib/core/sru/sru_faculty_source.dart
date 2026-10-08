import 'sru_auth_client.dart';
import 'sru_timetable_parser.dart';
import 'sru_profile_parser.dart';
import '../timetable_normalizer.dart';

class SruFacultySource {
  static final SruFacultySource instance = SruFacultySource._();
  SruFacultySource._();

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/faculty/profile');
    if (response.statusCode == 200) {
      return SruProfileParser.parseProfile(response.body, 'faculty');
    }
    throw Exception('Failed to load profile');
  }

  Future<List<dynamic>> fetchTimetable() async {
    final response = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/faculty/timetable');
    if (response.statusCode == 200) {
      final rawEntries = SruTimetableParser.parseTimetable(response.body, source: 'sru_authenticated_faculty');
      return TimetableNormalizer.normalize(rawEntries);
    }
    throw Exception('Failed to load timetable');
  }
}
