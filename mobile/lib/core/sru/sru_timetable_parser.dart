import 'package:html/parser.dart' as html_parser;

class SruTimetableParser {
  static List<Map<String, dynamic>> parseTimetable(String htmlContent, {String source = 'sru_portal'}) {
    final document = html_parser.parse(htmlContent);
    final List<Map<String, dynamic>> entries = [];

    // The new SRU timetable uses li elements with class "stt-slot"
    final slots = document.querySelectorAll('.stt-slot');
    
    for (final slot in slots) {
      String day = slot.attributes['data-day'] ?? '';
      final fromMinutesStr = slot.attributes['data-from'] ?? '';
      final toMinutesStr = slot.attributes['data-to'] ?? '';

      if (day.isEmpty || fromMinutesStr.isEmpty || toMinutesStr.isEmpty) {
        continue;
      }

      // data-day is often numeric (1=Monday, etc). Map it to string to match app logic.
      switch (day) {
        case '1': day = 'Monday'; break;
        case '2': day = 'Tuesday'; break;
        case '3': day = 'Wednesday'; break;
        case '4': day = 'Thursday'; break;
        case '5': day = 'Friday'; break;
        case '6': day = 'Saturday'; break;
        case '7': day = 'Sunday'; break;
      }

      final fromMinutes = int.tryParse(fromMinutesStr) ?? 0;
      final toMinutes = int.tryParse(toMinutesStr) ?? 0;

      final startHour = (fromMinutes ~/ 60).toString().padLeft(2, '0');
      final startMin = (fromMinutes % 60).toString().padLeft(2, '0');
      final startTime = '$startHour:$startMin';

      final endHour = (toMinutes ~/ 60).toString().padLeft(2, '0');
      final endMin = (toMinutes % 60).toString().padLeft(2, '0');
      final endTime = '$endHour:$endMin';

      // Look inside the slot for .stt-class elements (could be multiple in a single slot)
      final classes = slot.querySelectorAll('.stt-class');
      for (final cls in classes) {
        final subjectEl = cls.querySelector('.stt-subject');
        final typeEl = cls.querySelector('.stt-type');
        final roomEl = cls.querySelector('.stt-room');
        final personEl = cls.querySelector('.stt-person');

        if (subjectEl == null) continue;

        String subject = subjectEl.text.trim();
        String classType = typeEl?.text.trim() ?? 'Lecture';
        
        String room = roomEl?.text.trim() ?? '';
        room = room.replaceAll('Room', '').trim(); // Remove visually-hidden text
        
        String faculty = personEl?.text.trim() ?? '';
        faculty = faculty.replaceAll('Faculty', '').trim(); // Remove visually-hidden text

        final normSub = subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final normRoom = room.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final id = '${day.toLowerCase()}_${startTime}_${endTime}_${normSub}_$normRoom';

        entries.add({
          'id': id,
          'day': day,
          'start_time': startTime,
          'end_time': endTime,
          'subject': subject,
          'class_type': classType,
          'ltp': classType,
          'room': room,
          'faculty': faculty,
          'source': source,
        });
      }
    }

    return entries;
  }
}
