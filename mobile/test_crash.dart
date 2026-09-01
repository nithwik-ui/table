import 'dart:convert';

Map<String, String>? _getTimetableContext(Map<String, dynamic> change, List<dynamic> timetable) {
  String subject = 'Class';
  String day = '';
  String time = '';

  final fieldName = change['field_name'] as String? ?? '';
  final fieldParts = fieldName.split(':');
  if (fieldParts.length > 1) {
    final subjectPart = fieldParts.skip(1).join(':');
    final contextParts = subjectPart.split('|');
    subject = contextParts[0];
    if (contextParts.length == 3) {
      day = contextParts[1];
      time = contextParts[2];
    }
  }

  final type = change['change_type'] as String? ?? '';
  final newVal = change['new_value'] as String? ?? '';

  for (final cls in timetable) {
    bool isMatch = cls['subject'] == subject;
    if (isMatch && type == 'FACULTY_CHANGED' && newVal.isNotEmpty) {
      isMatch = cls['faculty'] == newVal;
    } else if (isMatch && type == 'ROOM_CHANGED' && newVal.isNotEmpty) {
      isMatch = cls['room'] == newVal;
    }

    if (isMatch) {
      final startTime = cls['start_time'] as String;
      final endTime = cls['end_time'] as String? ?? '';
      return {
        'day': cls['day'] as String,
        'time': endTime.isNotEmpty ? '$startTime - $endTime' : startTime,
        'subject': subject,
      };
    }
  }
  
  return {'day': day, 'time': time, 'subject': subject};
}

void main() {
  final timetable = [
    {
      'id': '123',
      'batch_id': 'b1',
      'day': 'Monday',
      'start_time': '10:00',
      'end_time': '11:00',
      'subject': 'Algorithms',
      'faculty': 'Ms. Anusha Vajjakeshavulu',
      'room': 'R1',
    },
    {
      'id': '124',
      'batch_id': 'b1',
      'day': 'Tuesday',
      'start_time': '11:00',
      'end_time': null, // test null end time
      'subject': 'Algorithms',
      'faculty': 'Ms. Anusha Vajjakeshavulu',
      'room': 'R1',
    }
  ];

  final change = {
    'batch_id': 'b1',
    'change_type': 'FACULTY_CHANGED',
    'field_name': 'faculty:Algorithms',
    'old_value': 'Mr. Srinivas Komakula',
    'new_value': 'Ms. Anusha Vajjakeshavulu',
  };

  try {
    final result = _getTimetableContext(change, timetable);
    print('Result: $result');
  } catch (e, stack) {
    print('CRASH: $e\n$stack');
  }
}
