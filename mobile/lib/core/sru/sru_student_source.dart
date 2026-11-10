import 'package:flutter/foundation.dart';
import 'sru_auth_client.dart';
import 'sru_timetable_parser.dart';
import 'sru_profile_parser.dart';
import '../timetable_normalizer.dart';
import '../storage.dart';
import '../api.dart';

class SruStudentSource {
  static final SruStudentSource instance = SruStudentSource._();
  SruStudentSource._();

  String? _resolveConfiguredBatch() {
    final profile = StorageService.getProfile();
    final batchId = profile?['batch_id']?.toString().trim();
    if (batchId != null && batchId.isNotEmpty) return batchId;
    final batchCode = (profile?['batch'] ?? profile?['batch_name'])?.toString().trim();
    if (batchCode != null && batchCode.isNotEmpty) return batchCode;
    return null;
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final existing = StorageService.getProfile();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    return SruProfileParser.parseProfile('', 'student');
  }

  Future<List<dynamic>> fetchTimetable() async {
    final batchTarget = _resolveConfiguredBatch();
    if (batchTarget != null && batchTarget.isNotEmpty) {
      // Safe Cloudflare Backend Batch Sync (Never touches sruniv.com)
      final entries = await ApiService.fetchTimetable(batchTarget);
      try {
        final backendChanges = await ApiService.fetchChanges(batchTarget);
        if (backendChanges.isNotEmpty) {
          await StorageService.saveChangesCache(backendChanges);
        }
      } catch (e) {
        debugPrint('[SYNC] Backend batch changes fetch non-fatal: $e');
      }
      return entries;
    }

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
          if (profile['roll_number'] != null && RegExp(r'\b2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6}\b').hasMatch(profile['roll_number'])) {
            await StorageService.saveStudentRollNumber(profile['roll_number']);
          } else if (profile['id'] != null && RegExp(r'\b2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6}\b').hasMatch(profile['id'])) {
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

