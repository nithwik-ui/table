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
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load changes (HTTP ${response.statusCode})');
    }
  }

  static Future<bool> registerDevice(String fcmToken, String batchId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': fcmToken, 'batch_id': batchId}),
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
}
