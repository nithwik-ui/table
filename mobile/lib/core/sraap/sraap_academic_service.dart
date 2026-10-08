import 'package:flutter/foundation.dart';
import '../../core/storage.dart';
import 'sraap_session_manager.dart';
import 'sraap_parser.dart';
import 'models/sraap_academic_data.dart';

class SraapAcademicService {
  // Singleton
  static final SraapAcademicService instance = SraapAcademicService._internal();
  SraapAcademicService._internal();

  /// Fetches the academic data.
  /// If [forceRefresh] is true, it skips the cache and fetches from SRAAP.
  /// Returns cached data if available and network fails.
  Future<SraapAcademicData?> getAcademicData({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = _getCachedData();
        if (cached != null) return cached;
      }

      if (!StorageService.isSraapConnected()) {
        return null; // Must authenticate first
      }

      // Fetch fresh data from network
      return await _fetchFreshData();
    } catch (e) {
      debugPrint('SRAAP Fetch Error: $e');
      if (forceRefresh) {
        rethrow;
      }
      // On normal load, fallback to cache
      return _getCachedData();
    }
  }

  Future<SraapAcademicData> _fetchFreshData() async {
    // Ensure session cookies are loaded from storage
    if (SraapSessionManager.instance.cookieHeader.isEmpty) {
      await SraapSessionManager.instance.restoreSession();
    }

    // Fetch Dashboard Page (contains Overall Attendance, CGPA, Mentor, and Subject Attendance)
    final dashboardRes = await SraapSessionManager.instance.get('/student/dash_board.php');
    if (dashboardRes.statusCode != 200 || (!dashboardRes.body.toLowerCase().contains('logout') && dashboardRes.bodyBytes.length < 10000)) {
      throw Exception('Session expired or access denied.');
    }
    
    // Parse Dashboard
    SraapAcademicData data = SraapParser.parseDashboard(dashboardRes.body);

    // Merge subject data into the parsed object (dash_board.php also contains Course Wise Attendance)
    data = SraapParser.parseSubjects(dashboardRes.body, data);

    // Cache the new data
    await StorageService.saveSraapAcademicCache(data.toJson());
    await StorageService.saveSraapLastSyncedAt(data.lastSynced);

    return data;
  }

  SraapAcademicData? getCachedAcademicData() => _getCachedData();

  SraapAcademicData? _getCachedData() {
    final raw = StorageService.getSraapAcademicCache();
    if (raw != null) {
      try {
        return SraapAcademicData.fromJson(raw);
      } catch (e) {
        debugPrint('Cache parsing error: $e');
        return null;
      }
    }
    return null;
  }

  /// Disconnects the SRAAP account, securely clearing session and cache.
  Future<void> disconnect() async {
    await SraapSessionManager.instance.clearSession();
    await StorageService.setSraapConnected(false);
    await StorageService.clearSraapAcademicCache();
  }
}
