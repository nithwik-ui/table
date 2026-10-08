import 'dart:convert';
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

    // Migration removed - app now requires SRU authentication

  }

  static Future<void> setUserMode(String mode) async {
    await _prefsBox?.put('user_mode', mode);
  }

  static String? getUserMode() {
    return _prefsBox?.get('user_mode') as String?;
  }

  static bool isStudentMode() {
    return getUserMode() != 'faculty';
  }

  static Future<void> saveUserIdentifier(String identifier) async {
    await _prefsBox?.put('user_identifier', identifier);
  }

  static String? getUserIdentifier() {
    return _prefsBox?.get('user_identifier') as String?;
  }

  static Future<void> saveStudentRollNumber(String rollNumber) async {
    await _prefsBox?.put('student_roll_number', rollNumber);
  }

  static String? getStudentRollNumber() {
    return _prefsBox?.get('student_roll_number') as String?;
  }

  static String? getRollNumber() => getStudentRollNumber();
  static Future<void> saveRollNumber(String rollNumber) => saveStudentRollNumber(rollNumber);

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    await _prefsBox?.put('user_profile_json', jsonEncode(profile));
  }

  static Map<String, dynamic>? getProfile() {
    final str = _prefsBox?.get('user_profile_json') as String?;
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
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


  static Future<void> clearSelection() async {
    await _prefsBox?.delete('user_profile_json');
    await _prefsBox?.delete('last_synced_at');
    
    // Clear caches
    await _cacheBox?.delete('timetable');
    await _cacheBox?.delete('changes');
    await _cacheBox?.delete('student_calendar_overrides');
  }

  // FACULTY SELECTION
  static Future<void> clearFacultySelection() async {
    await _prefsBox?.delete('user_profile_json');
    await _prefsBox?.delete('faculty_last_synced_at');
    
    // Clear caches
    await _cacheBox?.delete('faculty_timetable');
    await _cacheBox?.delete('faculty_calendar_overrides');
  }

  static Future<void> clearFacultyToken() async {
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

  // FEATURE TOGGLES
  static Future<void> setTimetableChangesEnabled(bool enabled) async => await _prefsBox?.put('timetable_changes_enabled', enabled);
  static bool isTimetableChangesEnabled() => _prefsBox?.get('timetable_changes_enabled', defaultValue: true) as bool? ?? true;

  static Future<void> setRoomChangesEnabled(bool enabled) async => await _prefsBox?.put('room_changes_enabled', enabled);
  static bool isRoomChangesEnabled() => _prefsBox?.get('room_changes_enabled', defaultValue: true) as bool? ?? true;

  static Future<void> setFacultyChangesEnabled(bool enabled) async => await _prefsBox?.put('faculty_changes_enabled', enabled);
  static bool isFacultyChangesEnabled() => _prefsBox?.get('faculty_changes_enabled', defaultValue: true) as bool? ?? true;

  static Future<void> setCancelledClassesEnabled(bool enabled) async => await _prefsBox?.put('cancelled_classes_enabled', enabled);
  static bool isCancelledClassesEnabled() => _prefsBox?.get('cancelled_classes_enabled', defaultValue: true) as bool? ?? true;

  static Future<void> setGeneralAnnouncementsEnabled(bool enabled) async => await _prefsBox?.put('general_announcements_enabled', enabled);
  static bool isGeneralAnnouncementsEnabled() => _prefsBox?.get('general_announcements_enabled', defaultValue: true) as bool? ?? true;

  // SRAAP AND SESSION
  static Future<void> setSraapConnected(bool connected) async => await _prefsBox?.put('sraap_connected', connected);
  static bool isSraapConnected() => _prefsBox?.get('sraap_connected', defaultValue: false) as bool? ?? false;

  static Future<void> saveSraapAcademicCache(Map<String, dynamic> data) async => await _cacheBox?.put('sraap_academic_cache', data);
  static Map<String, dynamic>? getSraapAcademicCache() {
    final data = _cacheBox?.get('sraap_academic_cache');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> clearSraapAcademicCache() async => await _cacheBox?.delete('sraap_academic_cache');

  static Future<void> saveSraapLastSyncedAt(DateTime dateTime) async => await _prefsBox?.put('sraap_last_synced_at', dateTime.toIso8601String());

  static Future<Map<String, dynamic>?> loadSessionState() async {
    final data = _cacheBox?.get('sraap_session_state');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }
  static Future<void> saveSessionState(Map<String, dynamic> state) async => await _cacheBox?.put('sraap_session_state', state);
  static Future<void> clearSessionState() async => await _cacheBox?.delete('sraap_session_state');
}
