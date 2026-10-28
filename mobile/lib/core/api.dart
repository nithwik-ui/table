import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'timetable_normalizer.dart';
import 'backend_router.dart';

abstract class FreeRoomsException implements Exception {
  final String message;
  const FreeRoomsException(this.message);
  @override
  String toString() => message;
}

class FreeRoomsNetworkException extends FreeRoomsException {
  const FreeRoomsNetworkException([super.message = "Couldn't load free classrooms. Check your connection and try again."]);
}

class FreeRoomsServerException extends FreeRoomsException {
  const FreeRoomsServerException([super.message = "Couldn't load free classrooms. Check your connection and try again."]);
}

class FreeRoomsMalformedException extends FreeRoomsException {
  const FreeRoomsMalformedException([super.message = "Received invalid data from server. Please try again."]);
}

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 12);

  static Future<http.Response> _get(String url, {Map<String, String>? headers}) =>
      BackendRouter.instance.get(url, headers: headers);

  static Future<http.Response> _post(String url, {Map<String, String>? headers, Object? body}) =>
      BackendRouter.instance.post(url, headers: headers, body: body);

  static Future<List<dynamic>> fetchDegrees() async {
    final response = await _get('${AppConstants.apiBaseUrl}/api/degrees');

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load degrees (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchYears(String degreeCode) async {
    final response = await _get('${AppConstants.apiBaseUrl}/api/degrees/${Uri.encodeComponent(degreeCode)}/years');

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load years (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchBatches(String degreeCode, String yearName) async {
    final response = await _get(
      '${AppConstants.apiBaseUrl}/api/degrees/${Uri.encodeComponent(degreeCode)}/years/${Uri.encodeComponent(yearName)}/batches',
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load batches (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchTimetable(String batchId) async {
    final response = await _get('${AppConstants.apiBaseUrl}/api/batches/$batchId/timetable');

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return TimetableNormalizer.normalize(list);
    } else {
      throw Exception('Failed to load timetable (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchTodayClasses(String batchId) async {
    final response = await _get('${AppConstants.apiBaseUrl}/api/batches/$batchId/today');

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return TimetableNormalizer.normalize(list);
    } else {
      throw Exception('Failed to load today\'s classes (HTTP ${response.statusCode})');
    }
  }

  static Future<Map<String, dynamic>?> fetchNextClass(String batchId) async {
    final response = await _get('${AppConstants.apiBaseUrl}/api/batches/$batchId/next-class');

    if (response.statusCode == 200) {
      final body = response.body;
      if (body == 'null') return null;
      return json.decode(body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load next class (HTTP ${response.statusCode})');
    }
  }

  static Future<List<dynamic>> fetchChanges(String batchId) async {
    final response = await _get('${AppConstants.apiBaseUrl}/api/batches/$batchId/changes');

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
    final response = await _get('${AppConstants.apiBaseUrl}/api/faculty/${Uri.encodeComponent(facultyId)}/changes');

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

  static Future<bool> registerDevice(
    String fcmToken, 
    String batchId, {
    String userMode = 'student', 
    String? facultyId,
    String? platform,
  }) async {
    try {
      final response = await _post(
        '${AppConstants.apiBaseUrl}/api/devices/register',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fcm_token': fcmToken,
          'batch_id': batchId,
          'user_mode': userMode,
          'faculty_id': facultyId,
          'platform': platform ?? (kIsWeb ? 'web' : 'android'),
        }),
      );
      
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unregisterDevice(String fcmToken) async {
    try {
      final response = await _post(
        '${AppConstants.apiBaseUrl}/api/devices/unregister',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': fcmToken}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendTestNotification(String fcmToken) async {
    try {
      final response = await _post(
        '${AppConstants.apiBaseUrl}/api/devices/test-notification',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': fcmToken}),
      );
      if (response.statusCode != 200) {
        String detail = 'Server returned ${response.statusCode}';
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            final code = decoded['code'] != null ? '[${decoded['code']}] ' : '';
            detail = '$code${decoded['message']}';
          }
        } catch (_) {}
        throw Exception(detail);
      }
      return true;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  static Future<bool> sendAttendanceNotification(String rollNumber, String subject) async {
    try {
      final response = await _post(
        '${AppConstants.apiBaseUrl}/api/devices/attendance',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'rollNumber': rollNumber, 'subject': subject}),
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      return true;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<bool> updatePreferences(String fcmToken, bool notificationsEnabled) async {
    try {
      final response = await _post(
        '${AppConstants.apiBaseUrl}/api/devices/preferences',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': fcmToken, 'notifications_enabled': notificationsEnabled}),
      );
      
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> fetchFacultyList() async {
    final response = await _get('${AppConstants.apiBaseUrl}/api/faculty/list');
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load faculty list');
  }

  static Future<List<dynamic>> fetchFacultyTimetable(String facultyId) async {
    final response = await _get(
      '${AppConstants.apiBaseUrl}/api/faculty/timetable?faculty=${Uri.encodeComponent(facultyId)}',
    );

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return TimetableNormalizer.normalize(list);
    } else {
      throw Exception('Failed to load faculty timetable');
    }
  }

  // --- CALENDAR OVERRIDES ---
  static Future<List<dynamic>> fetchCalendarOverrides(String date, String mode) async {
    final response = await _get(
      '${AppConstants.apiBaseUrl}/api/calendar-overrides?date=$date&mode=$mode',
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    return [];
  }

  // FREE ROOMS ENDPOINTS
  static Future<List<Map<String, dynamic>>> fetchFreeRooms(String day, String time) async {
    http.Response response;
    try {
      response = await _get(
        '${AppConstants.apiBaseUrl}/api/rooms/free?day=${Uri.encodeComponent(day)}&time=${Uri.encodeComponent(time)}',
      );
    } catch (e) {
      if (e is TimeoutException) {
        throw const FreeRoomsNetworkException();
      }
      final eStr = e.toString().toLowerCase();
      if (eStr.contains('socketexception') || eStr.contains('clientexception') || eStr.contains('xmlhttprequest')) {
        throw const FreeRoomsNetworkException();
      }
      if (e is FreeRoomsException) rethrow;
      throw const FreeRoomsNetworkException();
    }

    if (response.statusCode != 200) {
      throw FreeRoomsServerException(
        "Couldn't load free classrooms. Check your connection and try again. (HTTP ${response.statusCode})",
      );
    }

    dynamic decoded;
    try {
      decoded = json.decode(response.body);
    } catch (_) {
      throw const FreeRoomsMalformedException();
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FreeRoomsMalformedException();
    }

    final rawRooms = decoded['rooms'];
    if (rawRooms is! List) {
      throw const FreeRoomsMalformedException();
    }

    final List<Map<String, dynamic>> validRooms = [];
    for (final item in rawRooms) {
      if (item is Map) {
        final name = item['name']?.toString().trim();
        final type = item['type']?.toString().trim() ?? 'Classroom';
        if (name != null && name.isNotEmpty) {
          validRooms.add({
            'name': name,
            'type': type.isEmpty ? 'Classroom' : type,
          });
        }
      }
    }

    return validRooms;
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
