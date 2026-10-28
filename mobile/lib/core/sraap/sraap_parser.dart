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
      placementAttendance: existingData.placementAttendance,
      cgpa: existingData.cgpa,
      mentor: existingData.mentor,
      subjects: subjects,
      lastSynced: DateTime.now(),
    );
  }

  /// Parses placement/training attendance from https://sraap.in/student/std_training_atten_view.php
  /// Supports summary KPI blocks, tables (total rows, sum of present/held, or row averages),
  /// and contextual regex extraction. Never fabricates values or returns 0 on missing data.
  static double? parsePlacementAttendance(String html) {
    if (html.isEmpty) return null;
    final document = html_parser.parse(html);

    // 1. Look for explicit summary labels (e.g. "Total Attendance", "Overall %", "Training Attendance", "Attendance %")
    final pElements = document.querySelectorAll('p, span, strong, b, h1, h2, h3, h4, h5, div');
    for (var el in pElements) {
      final text = el.text.trim();
      final lower = text.toLowerCase();
      if (lower == 'training attendance' ||
          lower == 'placement attendance' ||
          lower == 'total attendance' ||
          lower == 'overall attendance' ||
          lower == 'attendance %' ||
          lower == 'overall %') {
        final parent = el.parent;
        if (parent != null) {
          final parentText = parent.text;
          final match = RegExp(r'(\d+(?:\.\d+)?)\s*%?').firstMatch(
            parentText.replaceFirst(text, '').trim(),
          );
          if (match != null) {
            final val = double.tryParse(match.group(1) ?? '');
            if (val != null && val >= 0.0 && val <= 100.0) {
              return double.parse(val.toStringAsFixed(1));
            }
          }
        }
      }
    }

    // 2. Look for table(s)
    final tables = document.querySelectorAll('table');
    for (var table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.isEmpty) continue;

      int pctCol = -1;
      int presentCol = -1;
      int totalCol = -1;

      // Identify header columns
      for (var row in rows) {
        final headers = row.querySelectorAll('th, td');
        for (int i = 0; i < headers.length; i++) {
          final hText = headers[i].text.trim().toLowerCase();
          if (hText.contains('%') || hText.contains('percentage') || hText.contains('atten %')) {
            pctCol = i;
          } else if (hText.contains('present') || hText.contains('attended')) {
            presentCol = i;
          } else if (hText.contains('held') || hText.contains('total') || hText.contains('conducted')) {
            totalCol = i;
          }
        }
        if (pctCol != -1 || (presentCol != -1 && totalCol != -1)) {
          break;
        }
      }

      int sumPresent = 0;
      int sumTotal = 0;
      double? totalRowPct;
      final List<double> rowPcts = [];

      for (var row in rows) {
        final cells = row.querySelectorAll('td, th');
        if (cells.length < 2) continue;
        final rowText = row.text.toLowerCase();
        final isTotalRow = rowText.contains('total') || rowText.contains('overall') || rowText.contains('average');

        if (pctCol != -1 && pctCol < cells.length) {
          final cellText = cells[pctCol].text.trim().replaceAll('%', '');
          final val = double.tryParse(cellText);
          if (val != null && val >= 0.0 && val <= 100.0) {
            if (isTotalRow) {
              totalRowPct = val;
            } else {
              rowPcts.add(val);
            }
          }
        }

        if (presentCol != -1 && totalCol != -1 && presentCol < cells.length && totalCol < cells.length) {
          final pVal = int.tryParse(cells[presentCol].text.trim());
          final tVal = int.tryParse(cells[totalCol].text.trim());
          if (pVal != null && tVal != null && tVal > 0) {
            if (isTotalRow) {
              totalRowPct ??= (pVal / tVal) * 100.0;
            } else {
              sumPresent += pVal;
              sumTotal += tVal;
            }
          }
        }
      }

      if (totalRowPct != null) {
        return double.parse(totalRowPct.toStringAsFixed(1)).clamp(0.0, 100.0);
      }
      if (sumTotal > 0) {
        final calc = (sumPresent / sumTotal) * 100.0;
        return double.parse(calc.toStringAsFixed(1)).clamp(0.0, 100.0);
      }
      if (rowPcts.isNotEmpty) {
        final avg = rowPcts.reduce((a, b) => a + b) / rowPcts.length;
        return double.parse(avg.toStringAsFixed(1)).clamp(0.0, 100.0);
      }
    }

    // 3. Fallback: Search for percentage patterns in the entire document
    final regexes = [
      RegExp(r'(?:total|overall|training|placement)\s*attendance[^\d%]{0,30}(\d+(?:\.\d+)?)\s*%', caseSensitive: false),
      RegExp(r'attendance\s*%[^\d%]{0,30}(\d+(?:\.\d+)?)\s*%', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*%\s*(?:attendance|overall|training)', caseSensitive: false),
    ];
    for (final reg in regexes) {
      final match = reg.firstMatch(html);
      if (match != null) {
        final val = double.tryParse(match.group(1) ?? '');
        if (val != null && val >= 0.0 && val <= 100.0) {
          return double.parse(val.toStringAsFixed(1));
        }
      }
    }

    return null;
  }
}
