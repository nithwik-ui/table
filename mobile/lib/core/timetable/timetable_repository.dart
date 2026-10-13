import 'package:flutter/foundation.dart';
import '../storage.dart';
import '../utils.dart';
import '../timetable_status_engine.dart';
import '../sync.dart';
import 'timetable_state.dart';

class TimetableRepository extends ChangeNotifier {
  static final TimetableRepository instance = TimetableRepository._internal();
  TimetableRepository._internal();

  TimetableState _state = TimetableState.empty;
  TimetableState get state => _state;

  TimetableMetadata _metadata = const TimetableMetadata();
  TimetableMetadata get metadata => _metadata;

  List<dynamic> _classes = [];
  List<dynamic> get classes => List.unmodifiable(_classes);

  List<dynamic> _todayClasses = [];
  List<dynamic> get todayClasses => List.unmodifiable(_todayClasses);

  Map<String, dynamic>? _upNextClass;
  Map<String, dynamic>? get upNextClass => _upNextClass;

  String _upNextStatus = '';
  String get upNextStatus => _upNextStatus;

  String? _todayHolidayTitle;
  String? get todayHolidayTitle => _todayHolidayTitle;

  String? _todayHolidayMessage;
  String? get todayHolidayMessage => _todayHolidayMessage;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Immediate local cache initialization (< 100ms render target).
  /// MUST be called synchronously or immediately at app launch.
  void init() {
    if (_initialized) return;
    _initialized = true;
    loadFromCache();
  }

  /// Loads timetable from local Hive storage immediately without any network calls.
  void loadFromCache() {
    final userMode = StorageService.getUserMode() ?? 'student';
    final cachedData = userMode == 'faculty'
        ? StorageService.getFacultyTimetableCache()
        : StorageService.getTimetableCache();

    final lastSynced = userMode == 'faculty'
        ? StorageService.getFacultyLastSyncedAt()
        : StorageService.getLastSyncedAt();

    _classes = cachedData.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    if (_classes.isNotEmpty) {
      final isStale = lastSynced != null &&
          DateTime.now().difference(lastSynced).inHours >= 6;

      _metadata = TimetableMetadata(
        lastUpdated: lastSynced,
        source: 'local_cache',
        version: 3,
        isStale: isStale,
      );
      _state = isStale ? TimetableState.stale : TimetableState.cached;
    } else {
      _metadata = const TimetableMetadata(
        source: 'empty',
        version: 3,
        isStale: false,
      );
      _state = TimetableState.empty;
    }

    _recalculateSchedule();
    notifyListeners();
  }

  /// Atomically updates local cache and notifies all tabs.
  /// Never deletes existing data if the incoming payload is empty or invalid.
  void updateTimetable(List<dynamic> newClasses, {String source = 'remote'}) {
    if (newClasses.isEmpty && _classes.isNotEmpty) {
      // Retain existing classes rather than wiping
      return;
    }

    _classes = newClasses.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final now = DateTime.now();
    _metadata = TimetableMetadata(
      lastUpdated: now,
      source: source,
      version: 3,
      isStale: false,
    );
    _state = TimetableState.fresh;
    _recalculateSchedule();
    notifyListeners();
  }

  /// Marks state as stale with a non-blocking error reason, retaining all cached classes.
  void markStale(String reason) {
    _metadata = _metadata.copyWith(
      isStale: true,
      errorMessage: reason,
    );
    _state = TimetableState.stale;
    notifyListeners();
  }

  int _refreshGeneration = 0;

  /// Pull-to-refresh or background synchronization.
  /// NEVER clears or wipes existing classes before or during refresh.
  Future<void> refresh({bool force = false}) async {
    if (_state == TimetableState.syncing && !force) return;

    final currentGen = ++_refreshGeneration;
    final previousClasses = List.from(_classes);
    _state = TimetableState.syncing;
    notifyListeners();

    try {
      await SyncService.instance.syncTimetable(force: force);
      if (currentGen != _refreshGeneration) {
        debugPrint('[REPO] Discarding stale refresh generation $currentGen');
        return;
      }
      if (SyncService.instance.syncState == SyncState.online) {
        // On success, reload fresh data from storage:
        loadFromCache();
        _state = TimetableState.fresh;
      } else {
        // On failure, retain existing data intact and mark stale!
        _classes = previousClasses;
        _state = TimetableState.stale;
        _recalculateSchedule();
      }
    } catch (e) {
      if (currentGen != _refreshGeneration) {
        debugPrint('[REPO] Discarding error from stale refresh generation $currentGen');
        return;
      }
      // Retain existing data!
      _classes = previousClasses;
      markStale(e.toString());
      _recalculateSchedule();
    } finally {
      if (currentGen == _refreshGeneration) {
        if (_state == TimetableState.syncing) {
          _state = _classes.isNotEmpty ? TimetableState.cached : TimetableState.stale;
        }
        notifyListeners();
      }
    }
  }

  /// Periodic UI schedule evaluation (called every minute without network access).
  void updateStatusCalculations() {
    _recalculateSchedule();
    notifyListeners();
  }

  void _recalculateSchedule() {
    final nowLocal = TimeUtils.nowInSruTime();
    final weekdayIndex = nowLocal.weekday; // 1 = Mon, 7 = Sun
    final weekdays = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final currentDay = weekdays[weekdayIndex].toLowerCase();

    // Check holiday overrides
    final userMode = StorageService.getUserMode() ?? 'student';
    final overrides = userMode == 'faculty'
        ? StorageService.getFacultyCalendarOverridesCache()
        : StorageService.getStudentCalendarOverridesCache();

    final todayStr = '${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}';
    _todayHolidayTitle = null;
    _todayHolidayMessage = null;

    for (final override in overrides) {
      if (override['override_date'] == todayStr && override['is_holiday'] == true) {
        _todayHolidayTitle = override['title'] ?? 'Holiday';
        _todayHolidayMessage = override['description'];
        break;
      }
    }

    // Filter today's classes
    final dayClasses = _classes.where((c) {
      final day = (c['day'] as String? ?? '').toLowerCase();
      return day == currentDay;
    }).toList();

    // Sort by start_time
    dayClasses.sort((a, b) {
      final tA = a['start_time'] as String? ?? '';
      final tB = b['start_time'] as String? ?? '';
      return tA.compareTo(tB);
    });

    _todayClasses = dayClasses;

    // Up next class
    final referenceDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final nextClass = TimetableStatusEngine.getNextClass(
      dayClasses: _todayClasses,
      referenceDate: referenceDate,
      nowLocal: nowLocal,
    );

    if (nextClass != null) {
      _upNextClass = nextClass;
      final classStatus = TimetableStatusEngine.getStatus(
        classData: _upNextClass!,
        referenceDate: referenceDate,
        nowLocal: nowLocal,
      );
      if (classStatus == ClassStatus.ongoing) {
        _upNextStatus = 'Ongoing';
      } else {
        final currentBreak = TimetableStatusEngine.getCurrentBreak(
          dayClasses: _todayClasses,
          referenceDate: referenceDate,
          nowLocal: nowLocal,
        );
        final startDt = TimeUtils.parseClassDateTime(referenceDate, _upNextClass!['start_time'] as String? ?? '00:00');
        final diff = startDt.difference(nowLocal).inMinutes;
        if (currentBreak != null) {
          _upNextStatus = '${currentBreak.label} • Next at ${TimeUtils.format12Hour(_upNextClass!['start_time'] as String? ?? '00:00')}';
        } else {
          _upNextStatus = diff > 0 ? 'Starts in $diff min' : 'Starting now';
        }
      }
    } else {
      _upNextClass = null;
      _upNextStatus = '';
    }
  }

  /// Get classes for a specific day (e.g. 'monday', 'tuesday')
  List<dynamic> getClassesForDay(String dayName) {
    final normalized = dayName.toLowerCase();
    final dayClasses = _classes.where((c) {
      final day = (c['day'] as String? ?? '').toLowerCase();
      return day == normalized;
    }).toList();

    dayClasses.sort((a, b) {
      final tA = a['start_time'] as String? ?? '';
      final tB = b['start_time'] as String? ?? '';
      return tA.compareTo(tB);
    });

    return dayClasses;
  }
}
