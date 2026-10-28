import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import 'sraap_session_manager.dart';
import 'sraap_parser.dart';
import 'models/sraap_academic_data.dart';

class SraapSessionExpiredException implements Exception {
  final String message;
  const SraapSessionExpiredException([this.message = 'SRAAP session has expired. Please re-authenticate.']);
  @override
  String toString() => message;
}

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
        return _getCachedData();
      }

      // Fetch fresh data from network
      return await _fetchFreshData();
    } catch (e) {
      debugPrint('SRAAP Fetch Error: $e');
      if (e is SraapSessionExpiredException) {
        SraapSessionManager.instance.isSessionExpired = true;
        if (forceRefresh) {
          rethrow;
        }
      }
      final cached = _getCachedData();
      if (cached != null) {
        return cached;
      }
      if (forceRefresh) {
        rethrow;
      }
      return null;
    }
  }

  Timer? _keepAliveTimer;

  /// Starts the active session keep-alive loop.
  /// Pings SRAAP dashboard every 10 minutes to touch the session and prevent PHP inactivity timeout.
  void startKeepAlive() {
    _keepAliveTimer?.cancel();
    if (!StorageService.isSraapConnected()) return;

    _keepAliveTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      if (StorageService.isSraapConnected()) {
        try {
          await pingKeepAlive();
        } catch (_) {}
      }
    });
  }

  /// Sends a background heartbeat to keep the session alive and refresh attendance.
  Future<SraapAcademicData?> pingKeepAlive() async {
    try {
      if (!StorageService.isSraapConnected()) return null;
      return await fetchFreshDataSilently();
    } catch (_) {
      return null;
    }
  }

  /// Attempts to fetch fresh live data in the background silently.
  /// Returns the newly fetched data on success, or null if network fails.
  /// Never throws exceptions, never wipes cached data, and preserves session keep-alive.
  Future<SraapAcademicData?> fetchFreshDataSilently() async {
    try {
      if (!StorageService.isSraapConnected()) return null;
      return await _fetchFreshData();
    } catch (e) {
      debugPrint('[SRAAP] Silent live sync: $e');
      return null;
    }
  }

  Future<SraapAcademicData> _fetchFreshData() async {
    // Ensure session cookies are loaded from storage
    if (SraapSessionManager.instance.cookieHeader.isEmpty) {
      await SraapSessionManager.instance.restoreSession();
    }

    // Fetch Dashboard Page (contains Overall Attendance, CGPA, Mentor, and Subject Attendance)
    final dashboardRes = await SraapSessionManager.instance.get('/student/dash_board.php');
    final body = dashboardRes.body;

    final isLoginPage = body.contains('student_login') ||
        body.contains('Enter Enrolment No') ||
        body.contains('user_password') ||
        dashboardRes.statusCode == 302 ||
        dashboardRes.statusCode == 301;

    final isDashboardHtml = body.contains('Attendance') ||
        body.toLowerCase().contains('logout') ||
        body.contains('attendanceTable') ||
        body.contains('Welcome to');

    if (isLoginPage || (!isDashboardHtml && dashboardRes.bodyBytes.length < 5000)) {
      SraapSessionManager.instance.isSessionExpired = true;
      throw const SraapSessionExpiredException();
    }

    SraapSessionManager.instance.isSessionExpired = false;
    
    // Parse Dashboard
    SraapAcademicData data = SraapParser.parseDashboard(dashboardRes.body);

    // Merge subject data into the parsed object (dash_board.php also contains Course Wise Attendance)
    data = SraapParser.parseSubjects(dashboardRes.body, data);

    // Check for attendance updates
    final oldData = _getCachedData();
    if (oldData != null) {
      _checkForAttendanceChanges(oldData, data);
    }

    // Cache the new data
    await StorageService.saveSraapAcademicCache(data.toJson());
    await StorageService.saveSraapLastSyncedAt(data.lastSynced);

    return data;
  }

  Future<void> _checkForAttendanceChanges(SraapAcademicData oldData, SraapAcademicData newData) async {
    final rollNumber = StorageService.getStudentRollNumber();
    if (rollNumber == null || rollNumber.isEmpty) return;

    for (final newSub in newData.subjects) {
      final oldSub = oldData.subjects.where((s) => s.subjectName == newSub.subjectName).firstOrNull;
      if (oldSub != null) {
        final newTotal = newSub.totalCount ?? 0;
        final oldTotal = oldSub.totalCount ?? 0;
        final newPresent = newSub.presentCount ?? 0;
        final oldPresent = oldSub.presentCount ?? 0;

        if (newTotal > oldTotal && newPresent > oldPresent) {
          // Present count increased! Send notification via backend.
          try {
            await ApiService.sendAttendanceNotification(rollNumber, newSub.subjectName);
          } catch (e) {
            debugPrint('Failed to send attendance notification: $e');
          }
        }
      }
    }
  }

  SraapAcademicData? getCachedAcademicData() => _getCachedData();

  /// Returns locally cached placement/training attendance percentage if present.
  double? getCachedPlacementAttendance() {
    return StorageService.getPlacementAttendance() ?? _getCachedData()?.placementAttendance;
  }

  /// Fetches placement/training attendance from https://sraap.in/student/std_training_atten_view.php
  /// Uses existing authenticated SRAAP session without prompting or bypassing security.
  Future<double?> fetchPlacementAttendance() async {
    try {
      if (!StorageService.isSraapConnected()) return null;

      if (SraapSessionManager.instance.cookieHeader.isEmpty) {
        await SraapSessionManager.instance.restoreSession();
      }

      final res = await SraapSessionManager.instance.get('/student/std_training_atten_view.php');
      final body = res.body;

      final isLoginPage = body.contains('slogin.php') ||
          body.contains('student_login') ||
          body.contains('In Valid Login') ||
          body.contains('Enter Enrolment No') ||
          body.contains('user_password') ||
          res.statusCode == 302 ||
          res.statusCode == 301;

      if (isLoginPage) {
        SraapSessionManager.instance.isSessionExpired = true;
        throw const SraapSessionExpiredException();
      }

      final pct = SraapParser.parsePlacementAttendance(body);
      if (pct != null) {
        await StorageService.savePlacementAttendance(pct);

        // Also atomically merge into cached SraapAcademicData if cached
        final cached = _getCachedData();
        if (cached != null) {
          final merged = SraapAcademicData(
            overallAttendance: cached.overallAttendance,
            placementAttendance: pct,
            subjects: cached.subjects,
            cgpa: cached.cgpa,
            mentor: cached.mentor,
            lastSynced: cached.lastSynced,
          );
          await StorageService.saveSraapAcademicCache(merged.toJson());
        }
      }
      return pct;
    } catch (e) {
      debugPrint('[SRAAP] Placement attendance fetch error: $e');
      if (e is SraapSessionExpiredException) {
        rethrow;
      }
      return null;
    }
  }

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
