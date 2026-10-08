import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Lightweight, privacy-first Analytics service.
///
/// NOTE: Strictly compliant with privacy rules.
/// NEVER logs PII, student names, phone numbers, passwords, or raw timetable contents.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> init() async {
    if (_initialized && _initFuture != null) {
      return _initFuture!;
    }
    _initFuture = _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      // Explicitly guarantee analytics collection is activated
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _initialized = true;
      debugPrint('[ANALYTICS] Initialized successfully. Collection enabled: true');
    } catch (e, st) {
      debugPrint('[ANALYTICS] Initialization failed: $e\n$st');
    }
  }

  Future<void> _log(String eventName, [Map<String, Object>? parameters]) async {
    if (!_initialized) {
      await init();
    }
    if (_analytics == null) {
      debugPrint('[ANALYTICS] Event "$eventName" dropped - analytics instance is null');
      return;
    }
    try {
      if (parameters != null) {
        await _analytics!.logEvent(name: eventName, parameters: parameters);
        debugPrint('[ANALYTICS] Dispatched event: $eventName - Params: $parameters');
      } else {
        await _analytics!.logEvent(name: eventName);
        debugPrint('[ANALYTICS] Dispatched event: $eventName');
      }
    } catch (e) {
      debugPrint('[ANALYTICS] Failed to dispatch event "$eventName": $e');
    }
  }

  Future<void> logAppOpen() async {
    if (!_initialized) await init();
    if (_analytics == null) return;
    try {
      await _analytics!.logAppOpen();
      debugPrint('[ANALYTICS] Dispatched: app_open');
    } catch (e) {
      debugPrint('[ANALYTICS] Failed to dispatch app_open: $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    if (!_initialized) await init();
    if (_analytics == null) return;
    try {
      await _analytics!.logScreenView(screenName: screenName);
      debugPrint('[ANALYTICS] Dispatched: screen_view ($screenName)');
    } catch (e) {
      debugPrint('[ANALYTICS] Failed to dispatch screen_view: $e');
    }
  }

  Future<void> logTimetableLoaded({
    required String mode,
    required int classCount,
    required bool fromCache,
  }) async {
    await _log('timetable_loaded', {
      'mode': mode,
      'class_count': classCount,
      'from_cache': fromCache ? 1 : 0,
    });
  }

  Future<void> logTimetableLoadFailed({
    required String mode,
    required String reason,
  }) async {
    await _log('timetable_load_failed', {
      'mode': mode,
      'reason': reason.substring(0, reason.length.clamp(0, 50)),
    });
  }

  Future<void> logTimetableChanged({required String mode, required int changeCount}) async {
    await _log('timetable_changed', {
      'mode': mode,
      'change_count': changeCount,
    });
  }

  Future<void> logClassReminderScheduled({required int reminderCount}) async {
    await _log('class_reminder_scheduled', {
      'count': reminderCount,
    });
  }

  Future<void> logClassReminderOpened() async {
    await _log('class_reminder_opened');
  }

  Future<void> logFreeClassroomsOpened() async {
    await _log('free_classrooms_opened');
  }

  Future<void> logModeSwitched({required String targetMode}) async {
    await _log('mode_switched', {
      'target_mode': targetMode,
    });
  }
}
