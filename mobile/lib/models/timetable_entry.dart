class TimetableEntry {
  final String id;
  final String day;
  final String startTime;
  final String endTime;
  final String subject;
  final String subjectCode;
  final String faculty;
  final String facultyId;
  final String room;
  final String roomId;
  final String classType;
  final String degree;
  final String department;
  final String year;
  final String section;
  final String batch;
  final String semester;
  final String source;
  final String timetableVersion;
  final DateTime? lastUpdated;

  TimetableEntry({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.subjectCode,
    required this.faculty,
    required this.facultyId,
    required this.room,
    required this.roomId,
    required this.classType,
    required this.degree,
    required this.department,
    required this.year,
    required this.section,
    required this.batch,
    required this.semester,
    required this.source,
    required this.timetableVersion,
    this.lastUpdated,
  });



  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': day,
      'start_time': startTime,
      'end_time': endTime,
      'subject': subject,
      'subject_code': subjectCode,
      'faculty': faculty,
      'faculty_id': facultyId,
      'room': room,
      'room_id': roomId,
      'class_type': classType,
      'degree': degree,
      'department': department,
      'year': year,
      'section': section,
      'batch': batch,
      'semester': semester,
      'source': source,
      'timetable_version': timetableVersion,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }
}
