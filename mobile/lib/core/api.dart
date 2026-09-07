import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 15);

  static Future<List<dynamic>> fetchDegrees() async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/degrees'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load degrees (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchYears(String degreeCode) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/degrees/${Uri.encodeComponent(degreeCode)}/years'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load years (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchBatches(String degreeCode, String yearName) async {
    final response = await http
        .get(Uri.parse(
            '${AppConstants.apiBaseUrl}/api/degrees/${Uri.encodeComponent(degreeCode)}/years/${Uri.encodeComponent(yearName)}/batches'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load batches (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchTimetable(String batchId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/batches/$batchId/timetable'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load timetable (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchTodayClasses(String batchId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/batches/$batchId/today'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load today\'s classes (HTTP ${response.statusCode})');
    }
  }

  static Future<Map<String, dynamic>?> fetchNextClass(String batchId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/batches/$batchId/next-class'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      final body = response.body;
      if (body == 'null') return null;
      return json.decode(body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load next class (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchChanges(String batchId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/batches/$batchId/changes'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      final now = DateTime.now();
      return list.where((change) {
        try {
          final dt = DateTime.parse(change['detected_at'] as String).toLocal();
          return now.difference(dt).inDays <= 7;
        } catch (_) {
          return true;
        }
      }).toList();
    } else {
      throw Exception('Failed to load changes (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchFacultyChanges(String facultyId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/faculty/${Uri.encodeComponent(facultyId)}/changes'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      final now = DateTime.now();
      return list.where((change) {
        try {
          final dt = DateTime.parse(change['detected_at'] as String).toLocal();
          return now.difference(dt).inDays <= 7;
        } catch (_) {
          return true;
        }
      }).toList();
    } else {
      throw Exception('Failed to load faculty changes (HTTP ${response.statusCode})');
    }
  }

  static Future<bool> registerDevice(String fcmToken, String batchId, {String userMode = 'student', String? facultyId}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fcm_token': fcmToken,
          'batch_id': batchId,
          'user_mode': userMode,
          'faculty_id': facultyId,
        }),
      ).timeout(timeoutDuration);
      
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updatePreferences(String fcmToken, bool notificationsEnabled) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/devices/preferences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': fcmToken, 'notifications_enabled': notificationsEnabled}),
      ).timeout(timeoutDuration);
      
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> fetchFacultyList() async {
    final response = await http.get(Uri.parse('${AppConstants.apiBaseUrl}/api/faculty/list')).timeout(timeoutDuration);
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load faculty list');
  }

  static Future<List<dynamic>> fetchFacultyTimetable(String facultyId) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/faculty/timetable?faculty=${Uri.encodeComponent(facultyId)}'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load faculty timetable');
    }
  }

  // --- CALENDAR OVERRIDES ---
  static Future<List<dynamic>> fetchCalendarOverrides(String date, String mode) async {
    final response = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}/api/calendar-overrides?date=$date&mode=$mode')
    ).timeout(timeoutDuration);
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    return [];
  }

  // FREE ROOMS ENDPOINTS
  static Future<List<dynamic>> fetchFreeRooms(String day, String time) async {
    final response = await http
        .get(Uri.parse('${AppConstants.apiBaseUrl}/api/rooms/free?day=${Uri.encodeComponent(day)}&time=${Uri.encodeComponent(time)}'))
        .timeout(timeoutDuration);

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['rooms'] as List<dynamic>;
    } else {
      throw Exception('Failed to load free rooms (HTTP ${response.statusCode})');
    }
  }

  static Future<Map<String, dynamic>> fetchLatestGithubRelease() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        data['status'] = 'success';
        return data;
      } else if (response.statusCode == 404) {
        return {'status': 'no_release'};
      } else {
        return {'status': 'error', 'message': 'GitHub API error: ${response.statusCode}'};
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return {'status': 'timeout'};
      } else if (e.toString().contains('SocketException')) {
        return {'status': 'no_internet'};
      }
      return {'status': 'error', 'message': 'Unable to check for updates right now.'};
    }
  }
}
