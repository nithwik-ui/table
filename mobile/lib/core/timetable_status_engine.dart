import 'utils.dart';

enum ClassStatus {
  completed,
  ongoing,
  upNext,
  upcoming,
  cancelled,
  scheduled
}

class BreakInfo {
  final String label; // "Lunch" or "Break"
  final String startTime;
  final String endTime;
  final Map<String, dynamic> nextClass;

  const BreakInfo({
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.nextClass,
  });

  bool get isLunch => label == 'Lunch';
}

class TimetableStatusEngine {
  /// Converts a timetable string (HH:MM) for a specific calendar date 
  /// into a consistent DateTime in the SRU frame of reference.
  static DateTime parseSruTimeToLocal(DateTime calendarDate, String timeStr) {
    return TimeUtils.parseClassDateTime(calendarDate, timeStr);
  }

  /// Calculates the definitive status for a given class event.
  /// Rules:
  /// - now >= endTime: COMPLETED
  /// - startTime <= now < endTime: ONGOING
  /// - now < startTime: UPCOMING
  static ClassStatus getStatus({
    required Map classData,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    if (classData['isCancelled'] == true) {
      return ClassStatus.cancelled;
    }

    final startTimeStr = classData['start_time'] as String? ?? '00:00';
    final endTimeStr = classData['end_time'] as String? ?? '00:00';

    final startDt = TimeUtils.parseClassDateTime(referenceDate, startTimeStr);
    final endDt = TimeUtils.parseClassDateTime(referenceDate, endTimeStr);

    // COMPLETED: now >= endTime (end boundary is inclusive)
    if (nowLocal.isAfter(endDt) || nowLocal.isAtSameMomentAs(endDt)) {
      return ClassStatus.completed;
    }

    // ONGOING: startTime <= now && now < endTime
    if (!nowLocal.isBefore(startDt) && nowLocal.isBefore(endDt)) {
      return ClassStatus.ongoing;
    }

    // UPCOMING: now < startTime
    return ClassStatus.upcoming;
  }

  /// Evaluates day classes and returns the next or ongoing class to display.
  /// If a class is currently ONGOING, returns that ongoing class.
  /// If between classes (e.g. Lunch or Break), returns the next upcoming class.
  /// Only returns null if all classes for the day have finished or list is empty.
  static Map<String, dynamic>? getNextClass({
    required List<dynamic> dayClasses,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    if (dayClasses.isEmpty) return null;

    final sorted = List<Map<String, dynamic>>.from(
      dayClasses.where((c) => c['isCancelled'] != true).map((c) => Map<String, dynamic>.from(c as Map))
    );
    if (sorted.isEmpty) return null;

    sorted.sort((a, b) {
      final startA = TimeUtils.parseClassDateTime(referenceDate, a['start_time'] as String? ?? '00:00');
      final startB = TimeUtils.parseClassDateTime(referenceDate, b['start_time'] as String? ?? '00:00');
      return startA.compareTo(startB);
    });

    // 1. First priority: Check if a class is ONGOING right now
    for (final c in sorted) {
      final status = getStatus(
        classData: c,
        referenceDate: referenceDate,
        nowLocal: nowLocal,
      );
      if (status == ClassStatus.ongoing) {
        return c;
      }
    }

    // 2. Second priority: Find all strictly UPCOMING classes (startTime > now)
    final upcoming = sorted.where((c) {
      final startDt = TimeUtils.parseClassDateTime(referenceDate, c['start_time'] as String? ?? '00:00');
      return startDt.isAfter(nowLocal);
    }).toList();

    if (upcoming.isNotEmpty) {
      return upcoming.first;
    }

    // All classes have finished for the day
    return null;
  }

  /// Returns the ID of the next class (backward compatible).
  static String? getNextClassId({
    required List<dynamic> dayClasses,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    final next = getNextClass(
      dayClasses: dayClasses,
      referenceDate: referenceDate,
      nowLocal: nowLocal,
    );
    if (next == null) return null;
    return (next['id'] as String?) ?? '${next['day']}_${next['start_time']}_${next['end_time']}_${next['subject']}';
  }

  /// Checks if current time is inside a break (such as Lunch) between scheduled classes.
  static BreakInfo? getCurrentBreak({
    required List<dynamic> dayClasses,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    if (dayClasses.isEmpty) return null;

    final sorted = List<Map<String, dynamic>>.from(
      dayClasses.where((c) => c['isCancelled'] != true).map((c) => Map<String, dynamic>.from(c as Map))
    );
    if (sorted.isEmpty) return null;

    sorted.sort((a, b) {
      final startA = TimeUtils.parseClassDateTime(referenceDate, a['start_time'] as String? ?? '00:00');
      final startB = TimeUtils.parseClassDateTime(referenceDate, b['start_time'] as String? ?? '00:00');
      return startA.compareTo(startB);
    });

    // If a class is currently ongoing, not in a break
    for (final c in sorted) {
      final status = getStatus(
        classData: c,
        referenceDate: referenceDate,
        nowLocal: nowLocal,
      );
      if (status == ClassStatus.ongoing) return null;
    }

    // Find previous completed class and next upcoming class
    Map<String, dynamic>? prevCompleted;
    Map<String, dynamic>? nextUpcoming;

    for (final c in sorted) {
      final startDt = TimeUtils.parseClassDateTime(referenceDate, c['start_time'] as String? ?? '00:00');
      final endDt = TimeUtils.parseClassDateTime(referenceDate, c['end_time'] as String? ?? '00:00');

      if (endDt.isBefore(nowLocal) || endDt.isAtSameMomentAs(nowLocal)) {
        prevCompleted = c;
      } else if (startDt.isAfter(nowLocal)) {
        nextUpcoming = c;
        break;
      }
    }

    if (prevCompleted != null && nextUpcoming != null) {
      final prevEnd = prevCompleted['end_time'] as String? ?? '00:00';
      final nextStart = nextUpcoming['start_time'] as String? ?? '00:00';

      final prevEndDt = TimeUtils.parseClassDateTime(referenceDate, prevEnd);
      final nextStartDt = TimeUtils.parseClassDateTime(referenceDate, nextStart);

      final gapMinutes = nextStartDt.difference(prevEndDt).inMinutes;

      // Standard Indian University Lunch window is typically 12:00 - 14:00 with duration >= 30 mins
      final isLunch = (prevEndDt.hour >= 12 && prevEndDt.hour <= 13) && gapMinutes >= 30;

      return BreakInfo(
        label: isLunch ? 'Lunch' : 'Break',
        startTime: prevEnd,
        endTime: nextStart,
        nextClass: nextUpcoming,
      );
    }

    return null;
  }
}
