import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

int _getWeekdayNumber(String dayName) {
  switch (dayName.toLowerCase()) {
    case 'monday': return DateTime.monday;
    case 'tuesday': return DateTime.tuesday;
    case 'wednesday': return DateTime.wednesday;
    case 'thursday': return DateTime.thursday;
    case 'friday': return DateTime.friday;
    case 'saturday': return DateTime.saturday;
    case 'sunday': return DateTime.sunday;
    default: return 0;
  }
}

void main() {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  final nowTz = tz.TZDateTime.now(tz.local);
  print('Diagnostic: current Asia/Kolkata time = ${nowTz}');

  String startTimeStr = "15:00"; // Time already passed today
  int targetWeekday = _getWeekdayNumber('Friday'); // Today

  final parts = startTimeStr.split(':');
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;

  var targetDate = tz.TZDateTime(tz.local, nowTz.year, nowTz.month, nowTz.day, hour, minute);
  
  while (targetDate.weekday != targetWeekday) {
    targetDate = targetDate.add(const Duration(days: 1));
  }

  var reminderTime = targetDate.subtract(const Duration(minutes: 15));
  
  if (reminderTime.isBefore(nowTz)) {
    targetDate = targetDate.add(const Duration(days: 7));
    reminderTime = targetDate.subtract(const Duration(minutes: 15));
  }

  print('Class start tz.TZDateTime = ${targetDate}');
  print('Calculated reminder tz.TZDateTime = ${reminderTime}');
}
