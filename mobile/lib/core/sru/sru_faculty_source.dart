import 'package:flutter/foundation.dart';
import 'sru_auth_client.dart';
import 'sru_timetable_parser.dart';
import 'sru_profile_parser.dart';
import '../timetable_normalizer.dart';
import '../storage.dart';
import '../api.dart';

class SruFacultySource {
  static final SruFacultySource instance = SruFacultySource._();
  SruFacultySource._();

  String? _resolveConfiguredFacultyId() {
    final profile = StorageService.getProfile();
    final facId = (profile?['faculty_id'] ?? profile?['id'])?.toString().trim();
    if (facId != null && facId.isNotEmpty) return facId;
    final ident = StorageService.getUserIdentifier()?.trim();
    if (ident != null && ident.isNotEmpty) return ident;
    return null;
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final existing = StorageService.getProfile();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final response = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/faculty/profile');
    if (response.statusCode == 200) {
      return SruProfileParser.parseProfile(response.body, 'faculty');
    }
    throw Exception('Failed to load profile');
  }

  Future<List<dynamic>> fetchTimetable() async {
    final facultyId = _resolveConfiguredFacultyId();
    if (facultyId != null && facultyId.isNotEmpty) {
      // Safe Cloudflare Backend Faculty Sync (Never touches sruniv.com)
      final entries = await ApiService.fetchFacultyTimetable(facultyId);
      try {
        final backendChanges = await ApiService.fetchFacultyChanges(facultyId);
        if (backendChanges.isNotEmpty) {
          await StorageService.saveFacultyChangesCache(backendChanges);
        }
      } catch (e) {
        debugPrint('[SYNC] Backend faculty changes fetch non-fatal: $e');
      }
      return entries;
    }

    final response = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/faculty/timetable');
    if (response.statusCode == 200) {
      final rawEntries = SruTimetableParser.parseTimetable(response.body, source: 'sru_authenticated_faculty');
      return TimetableNormalizer.normalize(rawEntries);
    }
    throw Exception('Failed to load timetable');
  }
}
