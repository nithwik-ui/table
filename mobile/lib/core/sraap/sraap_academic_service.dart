import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/storage.dart';
import '../../core/api.dart';
import '../notifications.dart';
import 'sraap_session_manager.dart';
import 'sraap_parser.dart';
import 'models/sraap_academic_data.dart';

class SraapSessionExpiredException implements Exception {
  final String message;
  const SraapSessionExpiredException([
    this.message = 'SRAAP session has expired. Please re-authenticate.',
  ]);
  @override
  String toString() => message;
}

class SraapAcademicService extends ChangeNotifier {
  // Singleton
  static final SraapAcademicService instance = SraapAcademicService._internal();
  SraapAcademicService._internal();

  /// Fetches the academic data.
  /// If [forceRefresh] is true, it skips the cache and fetches from SRAAP.
  /// Returns cached data if available and network fails.
  Future<SraapAcademicData?> getAcademicData({
    bool forceRefresh = false,
  }) async {
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
      if (!StorageService.isSraapConnected() ||
          SraapSessionManager.instance.isLoginFlowActive) {
        return null;
      }
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
      if (!StorageService.isSraapConnected() ||
          SraapSessionManager.instance.isLoginFlowActive) {
        return null;
      }
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
    final dashboardRes = await SraapSessionManager.instance.get(
      '/student/dash_board.php',
    );
    final body = dashboardRes.body;

    final isLoginPage = body.contains('slogin.php') ||
        body.contains('In Valid Login') ||
        body.contains('student_login') ||
        body.contains('Enter Enrolment No') ||
        body.contains('user_password') ||
        dashboardRes.statusCode == 302 ||
        dashboardRes.statusCode == 301;

    final isDashboardHtml = body.contains('Attendance') ||
        body.toLowerCase().contains('logout') ||
        body.contains('attendanceTable') ||
        body.contains('Welcome to');

    if (isLoginPage ||
        (!isDashboardHtml && dashboardRes.bodyBytes.length < 5000)) {
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
    notifyListeners();

    return data;
  }

  Future<void> _checkForAttendanceChanges(
    SraapAcademicData oldData,
    SraapAcademicData newData,
  ) async {
    final rollNumber = StorageService.getStudentRollNumber();
    if (rollNumber == null || rollNumber.isEmpty) return;

    for (final newSub in newData.subjects) {
      final oldSub = oldData.subjects
          .where((s) => s.subjectName == newSub.subjectName)
          .firstOrNull;
      if (oldSub != null) {
        final newTotal = newSub.totalCount ?? 0;
        final oldTotal = oldSub.totalCount ?? 0;
        final newPresent = newSub.presentCount ?? 0;
        final oldPresent = oldSub.presentCount ?? 0;

        if (newTotal > oldTotal && newPresent > oldPresent) {
          // Present count increased! Send notification via backend.
          try {
            await ApiService.sendAttendanceNotification(
              rollNumber,
              newSub.subjectName,
            );
          } catch (e) {
            debugPrint('Failed to send attendance notification: $e');
          }
        }
      }
    }
  }

  Future<void> _checkForMarksChanges(
    SraapInternalMarksData oldData,
    SraapInternalMarksData newData,
  ) async {
    final rollNumber = StorageService.getStudentRollNumber();
    if (rollNumber == null || rollNumber.isEmpty) return;

    for (final newCourse in newData.courses) {
      final oldCourse = oldData.courses
          .where(
            (c) =>
                (c.courseCode.isNotEmpty &&
                    c.courseCode == newCourse.courseCode) ||
                c.courseName == newCourse.courseName,
          )
          .firstOrNull;

      bool marksAdded = false;
      String markDetail = 'CIE: ${newCourse.cie}';

      if (oldCourse == null) {
        if (newCourse.cieScore > 0) {
          marksAdded = true;
        }
      } else {
        if (newCourse.cieScore > oldCourse.cieScore) {
          marksAdded = true;
          markDetail = 'CIE updated to ${newCourse.cie} (was ${oldCourse.cie})';
        } else if (newCourse.components.length > oldCourse.components.length) {
          final newlyAdded = newCourse.components
              .where(
                (nc) => !oldCourse.components.any(
                  (oc) => oc.label == nc.label && oc.value == nc.value,
                ),
              )
              .firstOrNull;
          if (newlyAdded != null && newlyAdded.isEntered) {
            marksAdded = true;
            markDetail = '${newlyAdded.cleanTitle}: ${newlyAdded.value}';
          }
        }
      }

      if (marksAdded) {
        try {
          await NotificationService.showForegroundNotification(
            '📊 New Marks Uploaded',
            'New internal marks released for ${newCourse.courseName}: $markDetail',
            {
              'type': 'marks',
              'course': newCourse.courseName,
              'cie': newCourse.cie,
            },
          );
        } catch (e) {
          debugPrint('[NOTIFICATIONS] Local marks notification error: $e');
        }

        try {
          await ApiService.sendMarksNotification(
            rollNumber,
            newCourse.courseName,
            newCourse.cie,
            component: markDetail,
          );
        } catch (e) {
          debugPrint('[NOTIFICATIONS] Backend marks notification error: $e');
        }
      }
    }
  }

  SraapAcademicData? getCachedAcademicData() => _getCachedData();

  /// Returns locally cached placement/training attendance percentage if present.
  double? getCachedPlacementAttendance() {
    return StorageService.getPlacementAttendance() ??
        _getCachedData()?.placementAttendance;
  }

  /// Fetches placement/training attendance from https://sraap.in/student/std_training_atten_view.php
  /// Uses existing authenticated SRAAP session without prompting or bypassing security.
  Future<double?> fetchPlacementAttendance() async {
    try {
      if (!StorageService.isSraapConnected() ||
          SraapSessionManager.instance.isLoginFlowActive) {
        return null;
      }

      if (SraapSessionManager.instance.cookieHeader.isEmpty) {
        await SraapSessionManager.instance.restoreSession();
      }

      final res = await SraapSessionManager.instance.get(
        '/student/std_training_atten_view.php',
      );
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
            yearSem: cached.yearSem,
            batchNumber: cached.batchNumber,
            coursesCount: cached.coursesCount,
            backlogsCount: cached.backlogsCount,
            alphaCoins: cached.alphaCoins,
            sigmaCoins: cached.sigmaCoins,
            announcements: cached.announcements,
            recentDailyAttendance: cached.recentDailyAttendance,
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

  /// Returns locally cached internal marks & semester memos data if available.
  SraapInternalMarksData? getCachedInternalMarks() {
    final raw = StorageService.getSraapInternalMarksCache();
    if (raw != null) {
      try {
        return SraapInternalMarksData.fromJson(raw);
      } catch (e) {
        debugPrint('[SRAAP] Internal marks cache parse error: $e');
      }
    }
    return null;
  }

  /// Fetches Sem Wise CIE / ETE Marks (/student/student_mid1.php) and Semester Memos (/student/student_sem_wise_memo.php).
  Future<SraapInternalMarksData?> fetchInternalMarks({
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh) {
        final cached = getCachedInternalMarks();
        if (cached != null && cached.courses.isNotEmpty) {
          return cached;
        }
      }

      if (!StorageService.isSraapConnected() ||
          SraapSessionManager.instance.isLoginFlowActive) {
        return getCachedInternalMarks();
      }

      if (SraapSessionManager.instance.cookieHeader.isEmpty) {
        await SraapSessionManager.instance.restoreSession();
      }

      final midRes = await SraapSessionManager.instance.get(
        '/student/student_mid1.php',
      );
      final body = midRes.body;

      final isLoginPage = body.contains('slogin.php') ||
          body.contains('student_login') ||
          body.contains('In Valid Login') ||
          body.contains('Enter Enrolment No') ||
          body.contains('user_password') ||
          midRes.statusCode == 302 ||
          midRes.statusCode == 301;

      if (isLoginPage) {
        SraapSessionManager.instance.isSessionExpired = true;
        throw const SraapSessionExpiredException();
      }

      final parsedCourses = SraapParser.parseInternalMarks(body);
      final existingCache = getCachedInternalMarks();

      // Preserve any previously fetched detailed assessment components for courses
      final mergedCourses = parsedCourses.map((course) {
        if (course.components.isNotEmpty) return course;
        final prev = existingCache?.courses
            .where(
              (c) =>
                  (c.courseCode.isNotEmpty &&
                      c.courseCode == course.courseCode) ||
                  c.courseName == course.courseName,
            )
            .firstOrNull;
        if (prev != null && prev.components.isNotEmpty) {
          return course.copyWith(components: prev.components);
        }
        return course;
      }).toList();

      List<SraapSemesterMemoRow> memos = existingCache?.memos ?? const [];
      try {
        final memoRes = await SraapSessionManager.instance.get(
          '/student/student_sem_wise_memo.php',
        );
        if (memoRes.statusCode == 200 &&
            !memoRes.body.contains('student_login')) {
          final parsedMemos = SraapParser.parseSemesterMemos(memoRes.body);
          if (parsedMemos.isNotEmpty) {
            memos = parsedMemos;
          }
        }
      } catch (_) {}

      final data = SraapInternalMarksData(
        courses: mergedCourses,
        memos: memos,
        lastSynced: DateTime.now(),
      );

      // Check for newly uploaded or updated CIE/internal marks
      if (existingCache != null && existingCache.courses.isNotEmpty) {
        _checkForMarksChanges(existingCache, data);
      }

      await StorageService.saveSraapInternalMarksCache(data.toJson());
      notifyListeners();
      return data;
    } catch (e) {
      debugPrint('[SRAAP] Internal marks fetch error: $e');
      if (e is SraapSessionExpiredException && forceRefresh) {
        rethrow;
      }
      return getCachedInternalMarks();
    }
  }

  /// Fetches detailed component marks for a specific course (clicking the View icon in student_mid1.php).
  Future<List<SraapAssessmentComponent>> fetchCourseMarksDetail(
    SraapCourseMarks course,
  ) async {
    try {
      if (!StorageService.isSraapConnected() ||
          SraapSessionManager.instance.isLoginFlowActive) {
        return course.components;
      }

      if (SraapSessionManager.instance.cookieHeader.isEmpty) {
        await SraapSessionManager.instance.restoreSession();
      }

      String responseHtml = '';
      if (course.formAction != null && course.formAction!.isNotEmpty) {
        final method = (course.formMethod ?? 'POST').toUpperCase();
        final fields = course.formFields ?? const <String, String>{};
        if (method == 'GET') {
          final parsedUri = Uri.parse(course.formAction!);
          final uri = parsedUri.replace(
            queryParameters: {...parsedUri.queryParameters, ...fields},
          );
          final res = await SraapSessionManager.instance.get(uri.toString());
          responseHtml = res.body;
        } else {
          final res = await SraapSessionManager.instance.postForm(
            course.formAction!,
            fields,
          );
          responseHtml = res.body;
        }
      } else if (course.detailHref != null && course.detailHref!.isNotEmpty) {
        final res = await SraapSessionManager.instance.get(course.detailHref!);
        responseHtml = res.body;
      } else {
        return course.components;
      }

      if (responseHtml.contains('slogin.php') ||
          responseHtml.contains('student_login') ||
          responseHtml.contains('Enter Enrolment No')) {
        SraapSessionManager.instance.isSessionExpired = true;
        throw const SraapSessionExpiredException();
      }

      final components = SraapParser.parseCourseMarksDetail(
        responseHtml,
        courseCode: course.courseCode,
        courseName: course.courseName,
      );

      if (components.isNotEmpty) {
        // Persist in cache so subsequent views work offline immediately
        final cached = getCachedInternalMarks();
        if (cached != null) {
          final updatedCourses = cached.courses.map((c) {
            if ((c.courseCode.isNotEmpty &&
                    c.courseCode == course.courseCode) ||
                c.courseName == course.courseName) {
              return c.copyWith(components: components);
            }
            return c;
          }).toList();
          final updatedData = SraapInternalMarksData(
            courses: updatedCourses,
            memos: cached.memos,
            lastSynced: cached.lastSynced,
          );
          await StorageService.saveSraapInternalMarksCache(
            updatedData.toJson(),
          );
          notifyListeners();
        }
        return components;
      }
      return course.components;
    } catch (e) {
      debugPrint('[SRAAP] Course marks detail fetch error: $e');
      if (e is SraapSessionExpiredException) rethrow;
      return course.components;
    }
  }

  /// Fetches a generic drilldown table from SRAAP (e.g. day-wise or subject-wise attendance logs).
  Future<List<Map<String, String>>> fetchPortalDetailTable(String path) async {
    try {
      if (!StorageService.isSraapConnected() ||
          SraapSessionManager.instance.isLoginFlowActive) {
        return [];
      }
      if (SraapSessionManager.instance.cookieHeader.isEmpty) {
        await SraapSessionManager.instance.restoreSession();
      }
      final res = await SraapSessionManager.instance.get(path);
      if (res.statusCode == 200 && !res.body.contains('student_login')) {
        return SraapParser.parseGenericDetailTable(res.body);
      }
    } catch (e) {
      debugPrint('[SRAAP] Portal detail table fetch error: $e');
    }
    return [];
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
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    notifyListeners();
  }
}
