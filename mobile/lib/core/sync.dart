import 'dart:async';
import 'package:flutter/foundation.dart';
import 'storage.dart';
import 'api.dart';
import 'notifications.dart';
import 'analytics_service.dart';
import 'widget_updater.dart';
import 'sru/sru_student_source.dart';
import 'sru/sru_faculty_source.dart';
import 'sru/sru_timetable_parser.dart';
import 'sru/sru_profile_parser.dart';
import 'timetable_normalizer.dart';
import 'timetable/timetable_repository.dart';
import 'auth/auth_repository.dart';
import 'auth/auth_state.dart';

enum SyncState { online, offline, serverUnavailable, syncTimeout, sessionExpired }

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();

  SyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncState _syncState = SyncState.online;
  SyncState get syncState => _syncState;

  int _retryCount = 0;
  Timer? _retryTimer;
  Timer? _hourlySyncTimer;
  DateTime? _lastCheckedAt;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  DateTime? _syncStartTime;
  int _syncGeneration = 0;
  int get syncGeneration => _syncGeneration;

  /// Starts the 1-hour periodic background sync against the Cloudflare backend.
  void startHourlySync() {
    _hourlySyncTimer?.cancel();
    _hourlySyncTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (!_isSyncing) {
        TimetableRepository.instance.refresh();
      }
    });
  }

  void stopHourlySync() {
    _hourlySyncTimer?.cancel();
    _hourlySyncTimer = null;
  }

  /// Imports timetable HTML copied from an official browser session (Zero direct SRU network calls).
  Future<int> importTimetableFromHtml(String htmlContent) async {
    final userMode = StorageService.getUserMode() ?? 'student';
    final rawEntries = SruTimetableParser.parseTimetable(htmlContent, source: 'browser_import');
    final list = TimetableNormalizer.normalize(rawEntries);
    if (list.isEmpty) {
      throw Exception('No timetable classes found in the pasted content. Copy the full timetable page source from sruniv.com.');
    }

    // Extract profile if present in HTML
    try {
      final profile = SruProfileParser.parseProfile(htmlContent, userMode);
      if (profile.isNotEmpty) {
        final existing = StorageService.getProfile() ?? {};
        existing.addAll(profile);
        await StorageService.saveProfile(existing);
        if (profile['name'] != null && profile['name'] != 'Student') {
          await StorageService.saveUserName(profile['name']);
        }
      }
    } catch (_) {}

    final oldTimetable = userMode == 'faculty'
        ? StorageService.getFacultyTimetableCache()
        : StorageService.getTimetableCache();

    await _detectAndSaveTimetableChanges(oldTimetable, list, userMode);

    final syncedAt = DateTime.now();
    if (userMode == 'faculty') {
      await StorageService.saveFacultyTimetableCache(list);
      await StorageService.saveFacultyLastSyncedAt(syncedAt);
    } else {
      await StorageService.saveTimetableCache(list);
      await StorageService.saveLastSyncedAt(syncedAt);
    }

    TimetableRepository.instance.updateTimetable(
      list,
      source: 'browser_import',
      syncedAt: syncedAt,
    );

    if (StorageService.isClassRemindersEnabled()) {
      await NotificationService.reconcileReminders();
    }

    _syncState = SyncState.online;
    _lastCheckedAt = syncedAt;
    notifyListeners();
    return list.length;
  }

  /// Executes the strict data freshness pipeline:
  /// fetch timetable -> validate response -> parse timetable -> write cache -> update lastSyncedAt.
  /// Never updates `lastSyncedAt` on start, failure, or empty invalid payloads.
  Future<void> syncTimetable({bool force = false}) async {
    final now = DateTime.now();
    if (_isSyncing) {
      final isStuck = _syncStartTime != null && now.difference(_syncStartTime!).inSeconds > 15;
      if (!force && !isStuck) {
        return;
      }
      debugPrint('[SYNC] Overriding in-flight sync (force: $force, isStuck: $isStuck)');
    }

    var userMode = StorageService.getUserMode();
    if (userMode == null || userMode.isEmpty) {
      userMode = 'student';
      await StorageService.setUserMode('student');
    }

    final currentGeneration = ++_syncGeneration;
    _isSyncing = true;
    _syncStartTime = DateTime.now();
    _retryTimer?.cancel();
    notifyListeners();

    try {
      if (userMode == 'faculty') {
        final overridesFuture = ApiService.fetchCalendarOverrides('', 'faculty')
            .then((overrides) => StorageService.saveFacultyCalendarOverridesCache(overrides))
            .catchError((e) {
          debugPrint('[SYNC] Faculty overrides fetch non-fatal: $e');
        });

        // 1. Fetch & parse timetable
        final list = await SruFacultySource.instance.fetchTimetable();

        // Decouple profile fetch so it never blocks timetable render
        unawaited(SruFacultySource.instance.fetchProfile().then((profile) async {
          if (currentGeneration == _syncGeneration) {
            await StorageService.saveProfile(profile);
          }
        }).catchError((e) {
          debugPrint('[SYNC] Faculty profile sync non-fatal: $e');
        }));

        await overridesFuture;

        if (currentGeneration != _syncGeneration) {
          debugPrint('[SYNC] Discarding stale faculty sync (generation $currentGeneration != $_syncGeneration)');
          return;
        }

        // 2. Validate response before overwriting cache or updating lastSyncedAt
        final oldTimetable = StorageService.getFacultyTimetableCache();
        if (list.isEmpty && oldTimetable.isNotEmpty) {
          throw Exception('Empty timetable response received; retaining cached schedule');
        }

        AnalyticsService.instance.logTimetableLoaded(
          mode: 'faculty',
          classCount: list.length,
          fromCache: false,
        );

        await _detectAndSaveTimetableChanges(oldTimetable, list, 'faculty');

        // 3. Successfully write cache first, then update authoritative lastSyncedAt
        await StorageService.saveFacultyTimetableCache(list);
        final syncedAt = DateTime.now();
        await StorageService.saveFacultyLastSyncedAt(syncedAt);
        TimetableRepository.instance.updateTimetable(
          list,
          source: 'sru_authenticated_faculty',
          syncedAt: syncedAt,
        );

        await WidgetUpdater.updateWidgetInfo();

        if (StorageService.isClassRemindersEnabled()) {
          await NotificationService.reconcileReminders();
        }
      } else {
        // Student Mode (default)
        final overridesFuture = ApiService.fetchCalendarOverrides('', 'student')
            .then((overrides) => StorageService.saveStudentCalendarOverridesCache(overrides))
            .catchError((e) {
          debugPrint('[SYNC] Student overrides fetch non-fatal: $e');
        });

        // 1. Fetch & parse timetable
        final list = await SruStudentSource.instance.fetchTimetable();

        await overridesFuture;

        if (currentGeneration != _syncGeneration) {
          debugPrint('[SYNC] Discarding stale student sync (generation $currentGeneration != $_syncGeneration)');
          return;
        }

        // 2. Validate response before overwriting cache or updating lastSyncedAt
        final oldTimetable = StorageService.getTimetableCache();
        if (list.isEmpty && oldTimetable.isNotEmpty) {
          throw Exception('Empty timetable response received; retaining cached schedule');
        }

        AnalyticsService.instance.logTimetableLoaded(
          mode: 'student',
          classCount: list.length,
          fromCache: false,
        );

        await _detectAndSaveTimetableChanges(oldTimetable, list, 'student');

        // 3. Successfully write cache first, then update authoritative lastSyncedAt
        await StorageService.saveTimetableCache(list);
        final syncedAt = DateTime.now();
        await StorageService.saveLastSyncedAt(syncedAt);
        TimetableRepository.instance.updateTimetable(
          list,
          source: 'sru_authenticated_student',
          syncedAt: syncedAt,
        );

        await WidgetUpdater.updateWidgetInfo();

        if (StorageService.isClassRemindersEnabled()) {
          await NotificationService.reconcileReminders();
        }
      }

      if (currentGeneration != _syncGeneration) return;

      _syncState = SyncState.online;
      _lastCheckedAt = DateTime.now();
      _retryCount = 0;
    } catch (e) {
      if (currentGeneration != _syncGeneration) {
        debugPrint('[SYNC] Discarding error from stale sync (generation $currentGeneration != $_syncGeneration)');
        return;
      }

      debugPrint('Sync failed: $e');
      AnalyticsService.instance.logTimetableLoadFailed(
        mode: userMode,
        reason: e.toString(),
      );

      _lastCheckedAt = DateTime.now();
      final eStr = e.toString().toLowerCase();
      if (eStr.contains('session expired')) {
        if (AuthRepository.instance.state == AuthState.authenticated ||
            AuthRepository.instance.state == AuthState.ready) {
          _syncState = SyncState.serverUnavailable;
          TimetableRepository.instance.markStale('Sync retry scheduled');
          _scheduleRetry();
        } else {
          _syncState = SyncState.sessionExpired;
          TimetableRepository.instance.markStale('Session expired');
        }
      } else if (eStr.contains('socketexception') ||
          eStr.contains('clientexception') ||
          eStr.contains('xmlhttprequest') ||
          eStr.contains('failed host lookup')) {
        _syncState = SyncState.offline;
        TimetableRepository.instance.markStale('Network unavailable');
        _scheduleRetry();
      } else if (e is TimeoutException) {
        _syncState = SyncState.syncTimeout;
        TimetableRepository.instance.markStale('Sync timed out');
        _scheduleRetry();
      } else {
        _syncState = SyncState.serverUnavailable;
        TimetableRepository.instance.markStale('Server unavailable');
        _scheduleRetry();
      }
    } finally {
      if (currentGeneration == _syncGeneration) {
        _isSyncing = false;
        _syncStartTime = null;
        notifyListeners();
      }
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= 4) return; // Max retries: 15s, 60s, 5m, 15m

    final delays = [15, 60, 300, 900];
    final delaySeconds = delays[_retryCount];
    _retryCount++;

    debugPrint('[SYNC] Scheduling retry in $delaySeconds seconds');

    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      syncTimetable();
    });
  }

  Future<void> _detectAndSaveTimetableChanges(
    List<dynamic> oldData,
    List<dynamic> newData,
    String mode,
  ) async {
    if (oldData.isEmpty) return; // Don't generate changes on first load

    List<dynamic> detectedChanges = [];
    final now = DateTime.now().toIso8601String();

    String generateId(dynamic cls) {
      return "${cls['day']}-${cls['start_time']}-${cls['end_time']}-${cls['subject']}";
    }

    final oldMap = {for (var cls in oldData) generateId(cls): cls};
    final newMap = {for (var cls in newData) generateId(cls): cls};

    // Check for additions and modifications
    for (var entry in newMap.entries) {
      final id = entry.key;
      final newCls = entry.value;
      final oldCls = oldMap[id];
      final contextLabel = "${newCls['subject']}|${newCls['day']}|${newCls['start_time']}";

      if (oldCls == null) {
        detectedChanges.add({
          'id': '${id}_added_$now',
          'change_type': 'CLASS_ADDED',
          'field_name': 'class:$contextLabel',
          'old_value': 'None',
          'new_value': 'Scheduled',
          'detected_at': now,
        });
      } else {
        if (oldCls['room'] != newCls['room']) {
          detectedChanges.add({
            'id': '${id}_room_$now',
            'change_type': 'ROOM_CHANGED',
            'field_name': 'room:$contextLabel',
            'old_value': oldCls['room']?.toString() ?? 'TBA',
            'new_value': newCls['room']?.toString() ?? 'TBA',
            'detected_at': now,
          });
        }
        if (oldCls['faculty'] != newCls['faculty']) {
          detectedChanges.add({
            'id': '${id}_faculty_$now',
            'change_type': 'FACULTY_CHANGED',
            'field_name': 'faculty:$contextLabel',
            'old_value': oldCls['faculty']?.toString() ?? 'TBA',
            'new_value': newCls['faculty']?.toString() ?? 'TBA',
            'detected_at': now,
          });
        }
        if (oldCls['is_cancelled'] != newCls['is_cancelled']) {
          if (newCls['is_cancelled'] == true) {
            detectedChanges.add({
              'id': '${id}_cancelled_$now',
              'change_type': 'CLASS_REMOVED',
              'field_name': 'status:$contextLabel',
              'old_value': 'Active',
              'new_value': 'Cancelled',
              'detected_at': now,
            });
          }
        }
      }
    }

    // Check for removals
    for (var entry in oldMap.entries) {
      if (!newMap.containsKey(entry.key)) {
        final oldCls = entry.value;
        final contextLabel = "${oldCls['subject']}|${oldCls['day']}|${oldCls['start_time']}";
        detectedChanges.add({
          'id': '${entry.key}_removed_$now',
          'change_type': 'CLASS_REMOVED',
          'field_name': 'class:$contextLabel',
          'old_value': 'Scheduled',
          'new_value': 'Removed',
          'detected_at': now,
        });
      }
    }

    if (detectedChanges.isNotEmpty) {
      if (mode == 'faculty') {
        final currentChanges = StorageService.getFacultyChangesCache();
        currentChanges.insertAll(0, detectedChanges);
        await StorageService.saveFacultyChangesCache(currentChanges);
      } else {
        final currentChanges = StorageService.getChangesCache();
        currentChanges.insertAll(0, detectedChanges);
        await StorageService.saveChangesCache(currentChanges);
      }

      try {
        await NotificationService.showForegroundNotification(
          'Timetable Updated',
          '${detectedChanges.length} schedule change(s) detected in your timetable.',
          {'type': 'timetable_change'},
        );
      } catch (e) {
        debugPrint('[SYNC] Change notification non-fatal: $e');
      }
    }
  }
}
