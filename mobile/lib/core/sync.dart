import 'dart:async';
import 'package:flutter/foundation.dart';
import 'storage.dart';
import 'api.dart';
import 'notifications.dart';
import 'analytics_service.dart';
import 'widget_updater.dart';
import 'sru/sru_student_source.dart';
import 'sru/sru_faculty_source.dart';
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
  DateTime? _lastCheckedAt;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  DateTime? _syncStartTime;
  int _syncGeneration = 0;
  int get syncGeneration => _syncGeneration;

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
        // Run calendar overrides in background/concurrently without blocking timetable
        final overridesFuture = ApiService.fetchCalendarOverrides('', 'faculty')
            .then((overrides) => StorageService.saveFacultyCalendarOverridesCache(overrides))
            .catchError((e) {
          debugPrint('[SYNC] Faculty overrides fetch non-fatal: $e');
        });

        // Timetable fetch is primary
        final list = await SruFacultySource.instance.fetchTimetable();
        
        // Decouple profile fetch so it never blocks timetable render
        unawaited(SruFacultySource.instance.fetchProfile().then((profile) async {
          if (currentGeneration == _syncGeneration) {
            await StorageService.saveProfile(profile);
          }
        }).catchError((e) {
          debugPrint('[SYNC] Faculty profile sync non-fatal: $e');
        }));
        
        // Await overrides if quick, non-fatal
        await overridesFuture;
        
        // Race check: discard if superseded by a newer sync
        if (currentGeneration != _syncGeneration) {
          debugPrint('[SYNC] Discarding stale faculty sync (generation $currentGeneration != $_syncGeneration)');
          return;
        }

        AnalyticsService.instance.logTimetableLoaded(
          mode: 'faculty',
          classCount: list.length,
          fromCache: false,
        );
        
        final oldTimetable = StorageService.getFacultyTimetableCache();
        await _detectAndSaveTimetableChanges(oldTimetable, list, 'faculty');
        
        await StorageService.saveFacultyTimetableCache(list);
        await StorageService.saveFacultyLastSyncedAt(DateTime.now());
        TimetableRepository.instance.updateTimetable(list, source: 'sru_authenticated_faculty');
        
        await WidgetUpdater.updateWidgetInfo();

        if (StorageService.isClassRemindersEnabled()) {
          await NotificationService.reconcileReminders();
        }
      } else {
        // Student Mode (default)
        // Run calendar overrides concurrently without blocking timetable
        final overridesFuture = ApiService.fetchCalendarOverrides('', 'student')
            .then((overrides) => StorageService.saveStudentCalendarOverridesCache(overrides))
            .catchError((e) {
          debugPrint('[SYNC] Student overrides fetch non-fatal: $e');
        });

        // Timetable fetch is primary (SruStudentSource.fetchTimetable auto-extracts & saves profile)
        final list = await SruStudentSource.instance.fetchTimetable();
        
        // Await overrides if quick, non-fatal
        await overridesFuture;

        // Race check: discard if superseded by a newer sync
        if (currentGeneration != _syncGeneration) {
          debugPrint('[SYNC] Discarding stale student sync (generation $currentGeneration != $_syncGeneration)');
          return;
        }

        AnalyticsService.instance.logTimetableLoaded(
          mode: 'student',
          classCount: list.length,
          fromCache: false,
        );
        
        final oldTimetable = StorageService.getTimetableCache();
        await _detectAndSaveTimetableChanges(oldTimetable, list, 'student');
        
        await StorageService.saveTimetableCache(list);
        await StorageService.saveLastSyncedAt(DateTime.now());
        TimetableRepository.instance.updateTimetable(list, source: 'sru_authenticated_student');

        await WidgetUpdater.updateWidgetInfo();

        if (StorageService.isClassRemindersEnabled()) {
          await NotificationService.reconcileReminders();
        }
      }
      
      if (currentGeneration != _syncGeneration) return;

      _syncState = SyncState.online;
      _lastCheckedAt = DateTime.now();
      _retryCount = 0; // Reset on success

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
      } else if (eStr.contains('socketexception') || eStr.contains('clientexception') || eStr.contains('xmlhttprequest')) {
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

  Future<void> _detectAndSaveTimetableChanges(List<dynamic> oldData, List<dynamic> newData, String mode) async {
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
        // Class Added
        detectedChanges.add({
          'change_type': 'CLASS_ADDED',
          'field_name': 'class:$contextLabel',
          'old_value': 'None',
          'new_value': 'Scheduled',
          'detected_at': now,
        });
      } else {
        // Check fields
        if (oldCls['room'] != newCls['room']) {
          detectedChanges.add({
            'change_type': 'ROOM_CHANGED',
            'field_name': 'room:$contextLabel',
            'old_value': oldCls['room']?.toString() ?? 'TBA',
            'new_value': newCls['room']?.toString() ?? 'TBA',
            'detected_at': now,
          });
        }
        if (oldCls['faculty'] != newCls['faculty']) {
          detectedChanges.add({
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
    }
  }
}
