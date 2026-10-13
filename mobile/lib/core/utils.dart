import 'package:intl/intl.dart';

class TimeUtils {
  /// Converts a 24-hour time string (e.g. "13:30" or "09:00")
  /// to a 12-hour AM/PM format (e.g. "1:30 PM" or "9:00 AM").
  static String format12Hour(String timeStr) {
    if (timeStr.isEmpty) return timeStr;
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return timeStr;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      
      // format 'h:mm a' will output "1:30 PM" without leading zero on hours
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return timeStr;
    }
  }

  /// Returns the current time at SR University (India Standard Time, UTC+5:30)
  /// as a standard DateTime so all hour/minute comparisons remain mathematically correct.
  static DateTime nowInSruTime() {
    final utc = DateTime.now().toUtc();
    final ist = utc.add(const Duration(hours: 5, minutes: 30));
    return DateTime(ist.year, ist.month, ist.day, ist.hour, ist.minute, ist.second, ist.millisecond);
  }

  /// Backward-compatible alias for nowInSruTime().
  static DateTime getKolkataTime() => nowInSruTime();

  /// Parses a timetable time string ("HH:MM") on a given reference calendar date
  /// into a DateTime in the exact same frame of reference as nowInSruTime().
  static DateTime parseClassDateTime(DateTime referenceDate, String timeStr) {
    int hour = 0;
    int min = 0;
    if (timeStr.isNotEmpty) {
      final parts = timeStr.split(':');
      if (parts.isNotEmpty) hour = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) min = int.tryParse(parts[1]) ?? 0;
    }
    return DateTime(referenceDate.year, referenceDate.month, referenceDate.day, hour, min);
  }
}
