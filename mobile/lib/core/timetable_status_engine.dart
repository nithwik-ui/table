import 'utils.dart';

enum ClassStatus {
  completed,
  ongoing,
  upNext,
  upcoming,
  cancelled,
  scheduled,
}

class BreakInfo {
  final String label; // "Lunch" or "FREE PERIOD" or "Break"
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final Map<String, dynamic> nextClass;

  const BreakInfo({
    required this.label,
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 0,
    required this.nextClass,
  });

  bool get isLunch => label == 'Lunch';
  bool get isFreePeriod => label == 'FREE PERIOD' || label == 'Break';
}

class FreePeriodSlot {
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final bool isLunch;

  const FreePeriodSlot({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isLunch = false,
  });

  String get formattedRange =>
      '${TimeUtils.format12Hour(startTime)} – ${TimeUtils.format12Hour(endTime)}';
}

class WeeklyTimetableStats {
  final int totalClasses;
  final int labsCount;
  final int freePeriodsCount;
  final String busiestDay;
  final String lightestDay;
  final Map<String, int> classesPerDay;

  const WeeklyTimetableStats({
    required this.totalClasses,
    required this.labsCount,
    required this.freePeriodsCount,
    required this.busiestDay,
    required this.lightestDay,
    required this.classesPerDay,
  });
}

class TimetableStatusEngine {
  /// Converts a timetable string (HH:MM) for a specific calendar date
  /// into a consistent DateTime in the SRU (IST) frame of reference.
  static DateTime parseSruTimeToLocal(DateTime calendarDate, String timeStr) {
    return TimeUtils.parseClassDateTime(calendarDate, timeStr);
  }

  static bool _isCancelledMap(Map classData) {
    return classData['isCancelled'] == true ||
        classData['is_cancelled'] == true ||
        classData['is_struck_off'] == true;
  }

  /// Calculates the definitive status for a given class event based on:
  /// - selected date (`referenceDate`)
  /// - class start time
  /// - class end time
  /// - current IST time (`nowLocal`)
  ///
  /// Invariant: A future class (selected date > today) MUST NEVER be marked Completed.
  static ClassStatus getStatus({
    required Map classData,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    if (_isCancelledMap(classData)) {
      return ClassStatus.cancelled;
    }

    final refDay = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final todayDay = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    final startTimeStr = classData['start_time'] as String? ?? '00:00';
    final endTimeStr = classData['end_time'] as String? ?? '00:00';

    final startDt = TimeUtils.parseClassDateTime(refDay, startTimeStr);
    var endDt = TimeUtils.parseClassDateTime(refDay, endTimeStr);

    // If endDt is before startDt, the class spans past midnight into the next calendar day
    final spansMidnight = endDt.isBefore(startDt);
    if (spansMidnight) {
      endDt = endDt.add(const Duration(days: 1));
    }

    // Future calendar date -> strictly UPCOMING (never Completed or Ongoing)
    if (refDay.isAfter(todayDay)) {
      return ClassStatus.upcoming;
    }

    // Past calendar date -> strictly COMPLETED unless midnight-crossing class is still ongoing
    if (refDay.isBefore(todayDay)) {
      if (!spansMidnight || nowLocal.isAfter(endDt) || nowLocal.isAtSameMomentAs(endDt)) {
        return ClassStatus.completed;
      }
    }

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

  /// Formats a human-readable countdown string for Up Next / Class cards.
  /// Examples:
  /// - "Starts in 18 min"
  /// - "Ends in 32 min"
  /// - "Completed"
  static String getCountdownText({
    required Map classData,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    final status = getStatus(
      classData: classData,
      referenceDate: referenceDate,
      nowLocal: nowLocal,
    );

    if (status == ClassStatus.cancelled) return 'Cancelled';
    if (status == ClassStatus.completed) return 'Completed';

    final refDay = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final startTimeStr = classData['start_time'] as String? ?? '00:00';
    final endTimeStr = classData['end_time'] as String? ?? '00:00';

    final startDt = TimeUtils.parseClassDateTime(refDay, startTimeStr);
    var endDt = TimeUtils.parseClassDateTime(refDay, endTimeStr);
    if (endDt.isBefore(startDt)) {
      endDt = endDt.add(const Duration(days: 1));
    }

    if (status == ClassStatus.ongoing) {
      final rem = endDt.difference(nowLocal).inMinutes;
      final safeRem = rem < 1 ? 1 : rem;
      return 'Ends in $safeRem min';
    }

    final diff = startDt.difference(nowLocal).inMinutes;
    if (diff <= 0) return 'Starting now';
    if (diff < 60) return 'Starts in $diff min';
    final hrs = diff ~/ 60;
    final mins = diff % 60;
    return mins > 0 ? 'Starts in ${hrs}h ${mins}m' : 'Starts in ${hrs}h';
  }

  /// Evaluates day classes and returns the next or ongoing class to display.
  static Map<String, dynamic>? getNextClass({
    required List<dynamic> dayClasses,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    if (dayClasses.isEmpty) return null;

    final sorted = List<Map<String, dynamic>>.from(
      dayClasses
          .where((c) => !_isCancelledMap(c as Map))
          .map((c) => Map<String, dynamic>.from(c as Map)),
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
      final status = getStatus(
        classData: c,
        referenceDate: referenceDate,
        nowLocal: nowLocal,
      );
      return status == ClassStatus.upcoming;
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
    return (next['id'] as String?) ??
        '${next['day']}_${next['start_time']}_${next['end_time']}_${next['subject']}';
  }

  /// Checks if current time is inside a break (such as Lunch or Free Period) between scheduled classes.
  static BreakInfo? getCurrentBreak({
    required List<dynamic> dayClasses,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    if (dayClasses.isEmpty) return null;

    final sorted = List<Map<String, dynamic>>.from(
      dayClasses
          .where((c) => !_isCancelledMap(c as Map))
          .map((c) => Map<String, dynamic>.from(c as Map)),
    );
    if (sorted.isEmpty) return null;

    sorted.sort((a, b) {
      final startA = TimeUtils.parseClassDateTime(referenceDate, a['start_time'] as String? ?? '00:00');
      final startB = TimeUtils.parseClassDateTime(referenceDate, b['start_time'] as String? ?? '00:00');
      return startA.compareTo(startB);
    });

    for (final c in sorted) {
      final status = getStatus(
        classData: c,
        referenceDate: referenceDate,
        nowLocal: nowLocal,
      );
      if (status == ClassStatus.ongoing) return null;
    }

    Map<String, dynamic>? prevCompleted;
    Map<String, dynamic>? nextUpcoming;

    for (final c in sorted) {
      final startDt = TimeUtils.parseClassDateTime(referenceDate, c['start_time'] as String? ?? '00:00');
      var endDt = TimeUtils.parseClassDateTime(referenceDate, c['end_time'] as String? ?? '00:00');
      if (endDt.isBefore(startDt)) {
        endDt = endDt.add(const Duration(days: 1));
      }

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
      if (gapMinutes <= 0) return null;

      final isLunch = (prevEndDt.hour >= 12 && prevEndDt.hour <= 13) && gapMinutes >= 30;

      return BreakInfo(
        label: isLunch ? 'Lunch' : 'Break',
        startTime: prevEnd,
        endTime: nextStart,
        durationMinutes: gapMinutes,
        nextClass: nextUpcoming,
      );
    }

    return null;
  }

  /// Detects all free periods (and lunch breaks) between classes for a single day.
  static List<FreePeriodSlot> detectDayGaps(List<dynamic> dayClasses) {
    final List<FreePeriodSlot> slots = [];
    if (dayClasses.length < 2) return slots;

    final active = dayClasses
        .where((c) => c is Map && !_isCancelledMap(c))
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    if (active.length < 2) return slots;

    int toMins(String s) {
      final p = s.split(':');
      if (p.length < 2) return 0;
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }

    active.sort((a, b) =>
        toMins(a['start_time']?.toString() ?? '00:00')
            .compareTo(toMins(b['start_time']?.toString() ?? '00:00')));

    int prevEndMins = -1;
    String prevEndStr = '';

    for (final c in active) {
      final startStr = c['start_time']?.toString() ?? '';
      final endStr = c['end_time']?.toString() ?? '';
      if (startStr.isEmpty || endStr.isEmpty) continue;

      final sMins = toMins(startStr);
      final eMins = toMins(endStr);

      if (prevEndMins != -1 && sMins > prevEndMins) {
        final gap = sMins - prevEndMins;
        if (gap >= 15) {
          final isLunch =
              (prevEndMins >= 12 * 60 && prevEndMins <= 13 * 60 + 15) && gap >= 30;
          slots.add(FreePeriodSlot(
            startTime: prevEndStr,
            endTime: startStr,
            durationMinutes: gap,
            isLunch: isLunch,
          ));
        }
      }

      if (eMins > prevEndMins) {
        prevEndMins = eMins;
        prevEndStr = endStr;
      }
    }

    return slots;
  }

  /// Returns the next (or currently ongoing) non-lunch FREE PERIOD for today, if any.
  static FreePeriodSlot? getNextFreePeriod({
    required List<dynamic> dayClasses,
    required DateTime referenceDate,
    required DateTime nowLocal,
  }) {
    final gaps = detectDayGaps(dayClasses).where((g) => !g.isLunch).toList();
    if (gaps.isEmpty) return null;

    final refDay = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    for (final gap in gaps) {
      final endDt = TimeUtils.parseClassDateTime(refDay, gap.endTime);
      if (endDt.isAfter(nowLocal)) {
        return gap;
      }
    }
    return null;
  }

  /// Calculates Weekly Statistics (Classes, Labs, Free periods, Busiest day, Lightest day)
  /// purely from locally available timetable data.
  static WeeklyTimetableStats calculateWeeklyStats(List<dynamic> allClasses) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    int totalClasses = 0;
    int labsCount = 0;
    int freePeriodsCount = 0;
    final Map<String, int> perDay = {for (final d in weekdays) d: 0};

    for (final raw in allClasses) {
      if (raw is! Map) continue;
      if (_isCancelledMap(raw)) continue;

      final dayRaw = (raw['day']?.toString() ?? '').trim();
      if (dayRaw.isEmpty) continue;

      final matchedDay = weekdays.firstWhere(
        (d) => d.toLowerCase() == dayRaw.toLowerCase(),
        orElse: () => '',
      );
      if (matchedDay.isEmpty) continue;

      totalClasses++;
      perDay[matchedDay] = (perDay[matchedDay] ?? 0) + 1;

      final ltp = (raw['ltp']?.toString() ?? '').toLowerCase();
      final subj = (raw['subject']?.toString() ?? '').toLowerCase();
      if (ltp.contains('lab') ||
          ltp.contains('practical') ||
          ltp == 'p' ||
          subj.contains('lab')) {
        labsCount++;
      }
    }

    for (final day in weekdays) {
      final dayList = allClasses
          .where((c) =>
              c is Map &&
              (c['day']?.toString() ?? '').toLowerCase() == day.toLowerCase())
          .toList();
      final gaps = detectDayGaps(dayList).where((g) => !g.isLunch).length;
      freePeriodsCount += gaps;
    }

    // Determine busiest and lightest scheduled days among days with classes
    final activeDays = weekdays
        .where((d) => (perDay[d] ?? 0) > 0)
        .toList();

    String busiest = 'Monday';
    String lightest = 'Monday';
    int maxCount = -1;
    int minCount = 999999;

    for (final d in activeDays) {
      final count = perDay[d] ?? 0;
      if (count > maxCount) {
        maxCount = count;
        busiest = d;
      }
      if (count < minCount) {
        minCount = count;
        lightest = d;
      }
    }

    if (totalClasses == 0) {
      busiest = 'None';
      lightest = 'None';
    }

    return WeeklyTimetableStats(
      totalClasses: totalClasses,
      labsCount: labsCount,
      freePeriodsCount: freePeriodsCount,
      busiestDay: busiest,
      lightestDay: lightest,
      classesPerDay: perDay,
    );
  }
}
