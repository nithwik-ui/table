import 'package:html/parser.dart' as html_parser;
import 'models/sraap_academic_data.dart';
import '../storage.dart';

class SraapParser {
  static SraapAcademicData parseDashboard(String html) {
    final document = html_parser.parse(html);
    
    // Parse student name
    String studentName = 'Student';
    // The name is usually in a strong tag like: <strong style="color:#FFFF33">Welcome to KURRE NITHWIK REDDY ...
    final headerElements = document.querySelectorAll('strong');
    for (var el in headerElements) {
      if (el.text.contains('ome to') || el.text.contains('Welcome to')) {
        final parts = el.text.split('-');
        if (parts.isNotEmpty) {
          studentName = parts[0].replaceAll('Welcome to', '').replaceAll('ome to', '').trim();
        }
        break;
      }
    }
    if (studentName.isNotEmpty && studentName != 'Student') {
      StorageService.saveUserName(studentName);
    }

    double attendance = 0.0;
    double cgpa = 0.0;
    String mentorName = 'Not Assigned';
    String mentorPhone = '';

    // Find the p tags that contain the labels
    final pElements = document.querySelectorAll('p');
    for (var p in pElements) {
      final text = p.text.trim();
      final parent = p.parent;
      if (parent == null) continue;
      
      final parentText = parent.text.trim();

      if (text == 'Attendance %') {
        final valText = parentText.replaceAll('Attendance %', '').trim();
        attendance = double.tryParse(valText) ?? 0.0;
      } else if (text == 'Overall CGPA %') {
        final valText = parentText.replaceAll('Overall CGPA %', '').trim();
        cgpa = double.tryParse(valText) ?? 0.0;
      } else if (text == 'Mentoring Staff') {
        final valText = parentText.replaceAll('Mentoring Staff', '').trim();
        // RAVEENDRA BABU VEMPATIContact No: 7989330650
        if (valText.contains('Contact No:')) {
          final parts = valText.split('Contact No:');
          mentorName = parts[0].trim();
          mentorPhone = parts[1].trim();
        } else {
          mentorName = valText;
        }
      }
    }

    return SraapAcademicData(
      overallAttendance: attendance,
      cgpa: cgpa.toString(),
      mentor: SraapMentor(name: mentorName, department: mentorPhone.isNotEmpty ? mentorPhone : null),
      subjects: [],
      lastSynced: DateTime.now(),
    );
  }

  static SraapAcademicData parseSubjects(String html, SraapAcademicData existingData) {
    final document = html_parser.parse(html);
    final List<SraapSubjectAttendance> subjects = [];

    // Find the table body
    var table = document.getElementById('attendanceTable');
    if (table == null) {
      final tables = document.querySelectorAll('table');
      for (var t in tables) {
        if (t.text.contains('Course Name') && t.text.contains('LTP Cls')) {
          table = t;
          break;
        }
      }
    }

    if (table != null) {
      final rows = table.querySelectorAll('tr');
      for (var row in rows) {
          // In some SRAAP pages (like dash_board.php), the first two cells are <th> instead of <td>
          final cells = row.children.where((e) => e.localName == 'td' || e.localName == 'th').toList();
          
          if (cells.length >= 5) {
            // S.No, Course Name, LTP Cls, Held Cls, Present
            final nameCell = cells[1];
            String courseName = nameCell.text.trim();
            if (courseName.toLowerCase() == 'course name') {
              continue;
            }
            String? courseCode;
            // Extract code if it exists (e.g. 24CS301PC311@SOFTWARE ENGINEERING)
            if (courseName.contains('@')) {
              final parts = courseName.split('@');
              courseCode = parts.first.trim();
              courseName = parts.last.trim();
            }

            final totalClasses = int.tryParse(cells[3].text.trim()) ?? 0;
            final attendedClasses = int.tryParse(cells[4].text.trim()) ?? 0;
            
            double percentage = 0.0;
            if (totalClasses > 0) {
              percentage = (attendedClasses / totalClasses) * 100;
              percentage = double.parse(percentage.toStringAsFixed(1));
            }

            subjects.add(SraapSubjectAttendance(
              subjectName: courseName,
              subjectCode: courseCode,
              totalCount: totalClasses,
              presentCount: attendedClasses,
              attendancePercentage: percentage.clamp(0.0, 100.0),
            ));
          }
        }
      }

    double? overallAttendance = existingData.overallAttendance;
    if ((overallAttendance == null || overallAttendance == 0.0) && subjects.isNotEmpty) {
      int totalHeld = 0;
      int totalPresent = 0;
      for (final s in subjects) {
        if (s.totalCount != null && s.presentCount != null) {
          totalHeld += s.totalCount!;
          totalPresent += s.presentCount!;
        }
      }
      if (totalHeld > 0) {
        final calc = (totalPresent / totalHeld) * 100;
        overallAttendance = double.parse(calc.toStringAsFixed(1)).clamp(0.0, 100.0);
      }
    }

    return SraapAcademicData(
      overallAttendance: overallAttendance,
      cgpa: existingData.cgpa,
      mentor: existingData.mentor,
      subjects: subjects,
      lastSynced: DateTime.now(),
    );
  }
}
