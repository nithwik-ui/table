import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static Box? _prefsBox;
  static Box? _cacheBox;

  // Initialize Hive and open boxes
  static Future<void> init() async {
    await Hive.initFlutter();
    _prefsBox = await Hive.openBox('sru_timetable_prefs');
    _cacheBox = await Hive.openBox('sru_timetable_cache');

    // Migration: Remove old format FACULTY_CHANGED records safely
    final cachedChanges = getChangesCache();
    if (cachedChanges.isNotEmpty) {
      final validChanges = cachedChanges.where((change) {
        if (change['change_type'] == 'FACULTY_CHANGED') {
          final oldVal = change['old_value'] as String? ?? '';
          if (oldVal.length > 40 || oldVal.contains('will be taken by') || oldVal.contains('->')) {
            return false;
          }
        }
        return true;
      }).toList();
      
      if (validChanges.length != cachedChanges.length) {
        await saveChangesCache(validChanges);
      }
    }

    // Migration: If no user mode but has student selection, default to student
    if (getUserMode() == null && hasSelection()) {
      await setUserMode('student');
    }
  }

  static Future<void> setUserMode(String mode) async {
    await _prefsBox?.put('user_mode', mode);
  }

  static String? getUserMode() {
    return _prefsBox?.get('user_mode') as String?;
  }

  static Future<void> saveUserName(String? name) async {
    if (name == null || name.isEmpty) {
      await _prefsBox?.delete('user_name');
    } else {
      await _prefsBox?.put('user_name', name);
    }
  }

  static String? getUserName() {
    return _prefsBox?.get('user_name') as String?;
  }

  static Future<void> saveSelection({
    required String degree,
    required String year,
    required String batchId,
    required String batchCode,
  }) async {
    await _prefsBox?.put('degree_code', degree);
    await _prefsBox?.put('year_name', year);
    await _prefsBox?.put('batch_id', batchId);
    await _prefsBox?.put('batch_code', batchCode);
  }

  static Map<String, String>? getSelection() {
    final degree = _prefsBox?.get('degree_code') as String?;
    final year = _prefsBox?.get('year_name') as String?;
    final batchId = _prefsBox?.get('batch_id') as String?;
    final batchCode = _prefsBox?.get('batch_code') as String?;

    if (degree == null || year == null || batchId == null || batchCode == null) {
      return null;
    }

    return {
      'degree': degree,
      'year': year,
      'batchId': batchId,
      'batchCode': batchCode,
    };
  }

  static Future<void> clearSelection() async {
    await _prefsBox?.delete('degree_code');
    await _prefsBox?.delete('year_name');
    await _prefsBox?.delete('batch_id');
    await _prefsBox?.delete('batch_code');
    await _prefsBox?.delete('last_synced_at');
    
    // Clear caches
    await _cacheBox?.delete('timetable');
    await _cacheBox?.delete('changes');
    await _cacheBox?.delete('student_calendar_overrides');
  }

  static bool hasSelection() {
    return getSelection() != null;
  }

  // FACULTY SELECTION
  static Future<void> saveFacultySelection({
    required String facultyId,
    required String facultyName,
  }) async {
    await _prefsBox?.put('faculty_id', facultyId);
    await _prefsBox?.put('faculty_name', facultyName);
  }

  static Map<String, String>? getFacultySelection() {
    final facultyId = _prefsBox?.get('faculty_id') as String?;
    final facultyName = _prefsBox?.get('faculty_name') as String?;

    if (facultyId == null || facultyName == null) {
      return null;
    }

    return {
      'facultyId': facultyId,
      'facultyName': facultyName,
    };
  }

  static Future<void> clearFacultySelection() async {
    await _prefsBox?.delete('faculty_id');
    await _prefsBox?.delete('faculty_name');
    await _prefsBox?.delete('faculty_last_synced_at');
    
    // Clear caches
    await _cacheBox?.delete('faculty_timetable');
    await _cacheBox?.delete('faculty_changes');
    await _cacheBox?.delete('faculty_calendar_overrides');
    await _prefsBox?.delete('faculty_token');
  }

  static Future<void> setFacultyToken(String token) async {
    await _prefsBox?.put('faculty_token', token);
  }

  static String? getFacultyToken() {
    return _prefsBox?.get('faculty_token') as String?;
  }

  static Future<void> fullLogout() async {
    await setUserMode('');
    await _prefsBox?.delete('user_mode');
    await clearSelection();
    await clearFacultySelection();
  }

  static bool hasFacultySelection() {
    return getFacultySelection() != null;
  }

  static List<int> getScheduledReminderIds(String mode) {
    final ids = _prefsBox?.get('${mode}_scheduled_reminders') as List<dynamic>?;
    return ids?.cast<int>() ?? [];
  }

  static Future<void> saveScheduledReminderIds(String mode, List<int> ids) async {
    await _prefsBox?.put('${mode}_scheduled_reminders', ids);
  }

  static Future<void> clearScheduledReminderIds(String mode) async {
    await _prefsBox?.delete('${mode}_scheduled_reminders');
  }

  // NOTIFICATION SETTINGS
  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefsBox?.put('notifications_enabled', enabled);
  }

  static bool isNotificationsEnabled() {
    return _prefsBox?.get('notifications_enabled', defaultValue: true) as bool? ?? true;
  }

  static Future<void> setClassRemindersEnabled(bool enabled) async {
    await _prefsBox?.put('class_reminders_enabled', enabled);
  }

  static bool isClassRemindersEnabled() {
    return _prefsBox?.get('class_reminders_enabled', defaultValue: true) as bool? ?? true;
  }

  // DATA FRESHNESS
  static Future<void> saveLastSyncedAt(DateTime dateTime) async {
    await _prefsBox?.put('last_synced_at', dateTime.toIso8601String());
  }

  static DateTime? getLastSyncedAt() {
    final str = _prefsBox?.get('last_synced_at') as String?;
    if (str == null) return null;
    return DateTime.parse(str);
  }

  static Future<void> saveFacultyLastSyncedAt(DateTime dateTime) async {
    await _prefsBox?.put('faculty_last_synced_at', dateTime.toIso8601String());
  }

  static DateTime? getFacultyLastSyncedAt() {
    final str = _prefsBox?.get('faculty_last_synced_at') as String?;
    if (str == null) return null;
    return DateTime.parse(str);
  }

  // TIMETABLE CACHE
  static Future<void> saveTimetableCache(List<dynamic> entries) async {
    await _cacheBox?.put('timetable', entries);
  }

  static List<dynamic> getTimetableCache() {
    return _cacheBox?.get('timetable', defaultValue: []) as List<dynamic>? ?? [];
  }

  static Future<void> saveFacultyTimetableCache(List<dynamic> entries) async {
    await _cacheBox?.put('faculty_timetable', entries);
  }

  static List<dynamic> getFacultyTimetableCache() {
    return _cacheBox?.get('faculty_timetable', defaultValue: []) as List<dynamic>? ?? [];
  }

  // TIMETABLE CHANGES CACHE
  static Future<void> saveChangesCache(List<dynamic> changes) async {
    await _cacheBox?.put('changes', changes);
  }

  static List<dynamic> getChangesCache() {
    return _cacheBox?.get('changes', defaultValue: []) as List<dynamic>? ?? [];
  }

  // FACULTY TIMETABLE CHANGES CACHE
  static Future<void> saveFacultyChangesCache(List<dynamic> changes) async {
    await _cacheBox?.put('faculty_changes', changes);
  }

  static List<dynamic> getFacultyChangesCache() {
    return _cacheBox?.get('faculty_changes', defaultValue: []) as List<dynamic>? ?? [];
  }

  // CALENDAR OVERRIDES CACHE (STUDENT)
  static Future<void> saveStudentCalendarOverridesCache(List<dynamic> overrides) async {
    await _cacheBox?.put('student_calendar_overrides', overrides);
  }

  static List<dynamic> getStudentCalendarOverridesCache() {
    return _cacheBox?.get('student_calendar_overrides', defaultValue: []) as List<dynamic>? ?? [];
  }

  // CALENDAR OVERRIDES CACHE (FACULTY)
  static Future<void> saveFacultyCalendarOverridesCache(List<dynamic> overrides) async {
    await _cacheBox?.put('faculty_calendar_overrides', overrides);
  }

  static List<dynamic> getFacultyCalendarOverridesCache() {
    return _cacheBox?.get('faculty_calendar_overrides', defaultValue: []) as List<dynamic>? ?? [];
  }

  // METADATA DISCOVERY CACHE (offline onboarding recovery)
  static Future<void> saveDegreesCache(List<dynamic> degrees) async {
    await _cacheBox?.put('degrees', degrees);
  }

  static List<dynamic>? getDegreesCache() {
    return _cacheBox?.get('degrees') as List<dynamic>?;
  }

  static Future<void> saveYearsCache(String degree, List<dynamic> years) async {
    await _cacheBox?.put('years_$degree', years);
  }

  static List<dynamic>? getYearsCache(String degree) {
    return _cacheBox?.get('years_$degree') as List<dynamic>?;
  }

  static Future<void> saveBatchesCache(String degree, String year, List<dynamic> batches) async {
    await _cacheBox?.put('batches_${degree}_$year', batches);
  }

  static List<dynamic>? getBatchesCache(String degree, String year) {
    return _cacheBox?.get('batches_${degree}_$year') as List<dynamic>?;
  }
}
