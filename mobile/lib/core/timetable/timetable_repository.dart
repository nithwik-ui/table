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

  String _upNextCountdown = '';
  String get upNextCountdown => _upNextCountdown;

  FreePeriodSlot? _nextFreePeriod;
  FreePeriodSlot? get nextFreePeriod => _nextFreePeriod;

  String? _todayHolidayTitle;
  String? get todayHolidayTitle => _todayHolidayTitle;

  String? _todayHolidayMessage;
  String? get todayHolidayMessage => _todayHolidayMessage;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Immediate local cache initialization (< 100ms render target).
  /// MUST be called synchronously or immediately at app launch.
  /// Never modifies `lastSyncedAt`.
  void init() {
    if (_initialized) return;
    _initialized = true;
    loadFromCache();
  }

  /// Loads timetable from local Hive storage immediately without any network calls.
  /// Preserves the authoritative `lastSyncedAt` from storage — never fakes "Updated just now".
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
      final isStale = lastSynced == null ||
          DateTime.now().difference(lastSynced).inHours >= 6;

      _metadata = TimetableMetadata(
        lastUpdated: lastSynced,
        source: 'local_cache',
        version: 3,
        isStale: isStale,
      );
      _state = isStale ? TimetableState.stale : TimetableState.cached;
    } else {
      _metadata = TimetableMetadata(
        lastUpdated: lastSynced,
        source: 'empty',
        version: 3,
        isStale: false,
      );
      _state = TimetableState.empty;
    }

    _recalculateSchedule();
    notifyListeners();
  }

  /// Atomically updates in-memory timetable and metadata ONLY after a verified
  /// fetch -> validate -> parse -> cache write sequence completes.
  /// Never deletes existing data if the incoming payload is empty or invalid.
  void updateTimetable(
    List<dynamic> newClasses, {
    String source = 'remote',
    DateTime? syncedAt,
  }) {
    if (newClasses.isEmpty && _classes.isNotEmpty) {
      // Retain existing classes and old lastSyncedAt rather than wiping
      return;
    }

    _classes = newClasses.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final authoritativeSyncTime = syncedAt ??
        (StorageService.getUserMode() == 'faculty'
            ? StorageService.getFacultyLastSyncedAt()
            : StorageService.getLastSyncedAt()) ??
        DateTime.now();

    _metadata = TimetableMetadata(
      lastUpdated: authoritativeSyncTime,
      source: source,
      version: 3,
      isStale: false,
    );
    _state = TimetableState.fresh;
    _recalculateSchedule();
    notifyListeners();
  }

  /// Marks state as stale with a non-blocking error reason, retaining all cached classes
  /// and preserving the existing `lastUpdated` timestamp.
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
  /// NEVER clears or wipes existing classes or `lastSyncedAt` before or during refresh.
  Future<void> refresh({bool force = false}) async {
    if (_state == TimetableState.syncing && !force) return;

    final currentGen = ++_refreshGeneration;
    final previousClasses = List.from(_classes);
    final previousMetadata = _metadata;
    _state = TimetableState.syncing;
    notifyListeners();

    try {
      await SyncService.instance.syncTimetable(force: force);
      if (currentGen != _refreshGeneration) {
        debugPrint('[REPO] Discarding stale refresh generation $currentGen');
        return;
      }
      if (SyncService.instance.syncState == SyncState.online) {
        // On success, reload fresh data & authoritative lastSyncedAt from storage:
        loadFromCache();
        if (_classes.isNotEmpty) {
          _state = TimetableState.fresh;
          _metadata = _metadata.copyWith(isStale: false, errorMessage: null);
        }
      } else {
        // On failure, retain existing data and old lastSyncedAt intact and mark stale!
        _classes = previousClasses;
        _metadata = previousMetadata.copyWith(isStale: true);
        _state = TimetableState.stale;
        _recalculateSchedule();
      }
    } catch (e) {
      if (currentGen != _refreshGeneration) {
        debugPrint('[REPO] Discarding error from stale refresh generation $currentGen');
        return;
      }
      _classes = previousClasses;
      _metadata = previousMetadata;
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

    final todayStr =
        '${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}';
    _todayHolidayTitle = null;
    _todayHolidayMessage = null;

    for (final override in overrides) {
      if (override['override_date'] == todayStr && override['is_holiday'] == true) {
        _todayHolidayTitle = override['title'] ?? 'Holiday';
        _todayHolidayMessage = override['description'] ?? override['message'];
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

    final referenceDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    // Next free period today
    _nextFreePeriod = TimetableStatusEngine.getNextFreePeriod(
      dayClasses: _todayClasses,
      referenceDate: referenceDate,
      nowLocal: nowLocal,
    );

    // Up next class
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
      _upNextCountdown = TimetableStatusEngine.getCountdownText(
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
        if (currentBreak != null) {
          _upNextStatus =
              '${currentBreak.label} • Next at ${TimeUtils.format12Hour(_upNextClass!['start_time'] as String? ?? '00:00')}';
        } else {
          _upNextStatus = 'Up Next';
        }
      }
    } else {
      _upNextClass = null;
      _upNextStatus = '';
      _upNextCountdown = '';
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

  /// Local instant search across Subject, Faculty, Room, and Day (0 network calls).
  static List<Map<String, dynamic>> searchClasses(
    List<dynamic> sourceClasses,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    const dayOrder = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };

    final matches = <Map<String, dynamic>>[];
    for (final raw in sourceClasses) {
      if (raw is! Map) continue;
      final c = Map<String, dynamic>.from(raw);
      final subject = (c['subject']?.toString() ?? '').toLowerCase();
      final faculty = (c['faculty']?.toString() ?? '').toLowerCase();
      final room = (c['room']?.toString() ?? '').toLowerCase();
      final day = (c['day']?.toString() ?? '').toLowerCase();
      final ltp = (c['ltp']?.toString() ?? '').toLowerCase();

      if (subject.contains(q) ||
          faculty.contains(q) ||
          room.contains(q) ||
          day.contains(q) ||
          ltp.contains(q)) {
        matches.add(c);
      }
    }

    matches.sort((a, b) {
      final dA = dayOrder[(a['day']?.toString() ?? '').toLowerCase()] ?? 99;
      final dB = dayOrder[(b['day']?.toString() ?? '').toLowerCase()] ?? 99;
      if (dA != dB) return dA.compareTo(dB);
      final tA = a['start_time']?.toString() ?? '';
      final tB = b['start_time']?.toString() ?? '';
      return tA.compareTo(tB);
    });

    return matches;
  }
}
