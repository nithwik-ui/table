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

  static DateTime getKolkataTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }
}
