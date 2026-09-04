import 'dart:async';
import 'package:flutter/foundation.dart';
import 'storage.dart';
import 'api.dart';
import 'notifications.dart';

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();

  SyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<void> syncTimetable() async {
    if (_isSyncing) return;
    
    final userMode = StorageService.getUserMode();
    if (userMode == null || userMode.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    try {
      if (userMode == 'faculty') {
        final selection = StorageService.getFacultySelection();
        if (selection != null) {
          final facultyId = selection['facultyId']!;
          
          // Fetch calendar overrides for faculty
          final overrides = await ApiService.fetchCalendarOverrides('', 'faculty');
          await StorageService.saveFacultyCalendarOverridesCache(overrides);

          // Fetch faculty timetable
          final list = await ApiService.fetchFacultyTimetable(facultyId);
          await StorageService.saveFacultyTimetableCache(list);
          await StorageService.saveFacultyLastSyncedAt(DateTime.now());
          
          if (StorageService.isClassRemindersEnabled()) {
            await NotificationService.scheduleClassReminders(list);
          }
        }
      } else if (userMode == 'student') {
        final selection = StorageService.getSelection();
        if (selection != null) {
          final batchId = selection['batchId']!;

          // Fetch calendar overrides for student
          final overrides = await ApiService.fetchCalendarOverrides('', 'student');
          await StorageService.saveStudentCalendarOverridesCache(overrides);

          // Fetch student timetable
          final list = await ApiService.fetchTimetable(batchId);
          await StorageService.saveTimetableCache(list);
          await StorageService.saveLastSyncedAt(DateTime.now());

          if (StorageService.isClassRemindersEnabled()) {
            await NotificationService.scheduleClassReminders(list);
          }
        }
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
