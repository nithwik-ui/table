import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'models/sraap_academic_data.dart';
import '../storage.dart';

class SraapParser {
  static String _normalizeStudentHref(String rawHref) {
    final trimmed = rawHref.trim();
    if (trimmed.isEmpty ||
        trimmed == '#' ||
        trimmed.toLowerCase().startsWith('javascript:')) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        return '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      }
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return trimmed;
    }
    return '/student/$trimmed';
  }

  static SraapAcademicData parseDashboard(String html) {
    final document = html_parser.parse(html);

    // Parse student name
    String studentName = 'Student';
    final headerElements = document.querySelectorAll('strong');
    for (var el in headerElements) {
      if (el.text.contains('ome to') || el.text.contains('Welcome to')) {
        final parts = el.text.split('-');
        if (parts.isNotEmpty) {
          studentName = parts[0]
              .replaceAll('Welcome to', '')
              .replaceAll('ome to', '')
              .trim();
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
    String? yearSem;
    String? batchNumber;
    int? coursesCount;
    int? backlogsCount;
    String? alphaCoins;
    String? sigmaCoins;

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
        if (valText.contains('Contact No:')) {
          final parts = valText.split('Contact No:');
          mentorName = parts[0].trim();
          mentorPhone = parts[1].trim();
        } else {
          mentorName = valText;
        }
      } else if (text == 'Year-Sem') {
        final h3s = parent.querySelectorAll('h3');
        if (h3s.length >= 2) {
          batchNumber = h3s[0].text.trim();
          yearSem = h3s[1].text.trim();
        } else {
          final valText = parentText.replaceAll('Year-Sem', '').trim();
          yearSem = valText;
        }
      } else if (text.contains('No.of Courses') || text.contains('Backlogs')) {
        final valText = parentText.replaceAll(text, '').trim();
        if (valText.contains('|')) {
          final parts = valText.split('|');
          coursesCount = int.tryParse(parts[0].trim());
          backlogsCount = int.tryParse(parts[1].trim());
        }
      } else if (text == 'Student Success Management') {
        final h4s = parent.querySelectorAll('h4');
        for (final h4 in h4s) {
          final t = h4.text.trim();
          if (t.toLowerCase().contains('alpha')) {
            alphaCoins = t;
          } else if (t.toLowerCase().contains('sigma')) {
            sigmaCoins = t;
          }
        }
      }
    }

    // Parse announcements from marquee
    final List<String> announcements = [];
    final announceSpans = document.querySelectorAll('.announce-item');
    for (final span in announceSpans) {
      final item = span.text.trim();
      if (item.isNotEmpty && !announcements.contains(item)) {
        announcements.add(item);
      }
    }

    // Parse Last Week Attendance % table
    final List<SraapDailyAttendance> recentDailyAttendance = [];
    final tables = document.querySelectorAll('table');
    for (final t in tables) {
      final tText = t.text;
      if (tText.contains('Date') &&
          tText.contains('Held') &&
          tText.contains('Attend')) {
        final rows = t.querySelectorAll('tr');
        for (final row in rows) {
          final cells = row.children
              .where((e) => e.localName == 'td' || e.localName == 'th')
              .toList();
          if (cells.length >= 4) {
            final dateText = cells[1].text.trim();
            if (dateText.toLowerCase() == 'date' || dateText.isEmpty) continue;
            final held = int.tryParse(cells[2].text.trim());
            final attended = int.tryParse(cells[3].text.trim());
            if (held != null && attended != null) {
              String? href;
              final aTag = cells[1].querySelector('a');
              if (aTag != null) {
                final rawHref = aTag.attributes['href'] ?? '';
                final norm = _normalizeStudentHref(rawHref);
                if (norm.isNotEmpty) href = norm;
              }
              recentDailyAttendance.add(
                SraapDailyAttendance(
                  date: dateText,
                  held: held,
                  attended: attended,
                  detailHref: href,
                ),
              );
            }
          }
        }
        break;
      }
    }

    return SraapAcademicData(
      overallAttendance: attendance,
      cgpa: cgpa.toString(),
      mentor: SraapMentor(
        name: mentorName,
        department: mentorPhone.isNotEmpty ? mentorPhone : null,
      ),
      yearSem: yearSem,
      batchNumber: batchNumber,
      coursesCount: coursesCount,
      backlogsCount: backlogsCount,
      alphaCoins: alphaCoins,
      sigmaCoins: sigmaCoins,
      announcements: announcements,
      recentDailyAttendance: recentDailyAttendance,
      subjects: [],
      lastSynced: DateTime.now(),
    );
  }

  static SraapAcademicData parseSubjects(
    String html,
    SraapAcademicData existingData,
  ) {
    final document = html_parser.parse(html);
    final List<SraapSubjectAttendance> subjects = [];

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
        final cells = row.children
            .where((e) => e.localName == 'td' || e.localName == 'th')
            .toList();

        if (cells.length >= 5) {
          final nameCell = cells[1];
          String courseName = nameCell.text.trim();
          if (courseName.toLowerCase() == 'course name') {
            continue;
          }
          String? courseCode;
          String? detailHref;
          final aTag = nameCell.querySelector('a');
          if (aTag != null) {
            final rawHref = aTag.attributes['href'] ?? '';
            final norm = _normalizeStudentHref(rawHref);
            if (norm.isNotEmpty) detailHref = norm;
            final uri = Uri.tryParse(rawHref);
            final ccParam = uri?.queryParameters['course_code'];
            if (ccParam != null && ccParam.contains('@')) {
              courseCode = ccParam.split('@').first.trim();
            }
          }
          if (courseName.contains('@')) {
            final parts = courseName.split('@');
            courseCode = parts.first.trim();
            courseName = parts.last.trim();
          }

          final ltpClasses = int.tryParse(cells[2].text.trim());
          final totalClasses = int.tryParse(cells[3].text.trim()) ?? 0;
          final attendedClasses = int.tryParse(cells[4].text.trim()) ?? 0;

          double percentage = 0.0;
          if (totalClasses > 0) {
            percentage = (attendedClasses / totalClasses) * 100;
            percentage = double.parse(percentage.toStringAsFixed(1));
          }

          subjects.add(
            SraapSubjectAttendance(
              subjectName: courseName,
              subjectCode: courseCode,
              ltpCount: ltpClasses,
              totalCount: totalClasses,
              presentCount: attendedClasses,
              attendancePercentage: percentage.clamp(0.0, 100.0),
              detailHref: detailHref,
            ),
          );
        }
      }
    }

    double? overallAttendance = existingData.overallAttendance;
    if ((overallAttendance == null || overallAttendance == 0.0) &&
        subjects.isNotEmpty) {
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
        overallAttendance =
            double.parse(calc.toStringAsFixed(1)).clamp(0.0, 100.0);
      }
    }

    return SraapAcademicData(
      overallAttendance: overallAttendance,
      placementAttendance: existingData.placementAttendance,
      cgpa: existingData.cgpa,
      mentor: existingData.mentor,
      yearSem: existingData.yearSem,
      batchNumber: existingData.batchNumber,
      coursesCount: existingData.coursesCount,
      backlogsCount: existingData.backlogsCount,
      alphaCoins: existingData.alphaCoins,
      sigmaCoins: existingData.sigmaCoins,
      announcements: existingData.announcements,
      recentDailyAttendance: existingData.recentDailyAttendance,
      subjects: subjects,
      lastSynced: DateTime.now(),
    );
  }

  /// Parses /student/student_mid1.php ("Examination Marks View")
  /// Columns: S.No | Year-Sem | Course | CIE | ETE | View
  static List<SraapCourseMarks> parseInternalMarks(String html) {
    if (html.isEmpty) return [];
    final document = html_parser.parse(html);
    final List<SraapCourseMarks> courses = [];

    final tables = document.querySelectorAll('table');
    dom.Element? marksTable;
    for (final t in tables) {
      final text = t.text;
      if ((text.contains('CIE') && text.contains('Course')) ||
          (text.contains('Year-Sem') && text.contains('CIE')) ||
          (text.contains('S.No') && text.contains('ETE'))) {
        marksTable = t;
        break;
      }
    }

    if (marksTable != null) {
      final rows = marksTable.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.children
            .where((e) => e.localName == 'td' || e.localName == 'th')
            .toList();
        if (cells.length < 5) continue;

        final c0 = cells[0].text.trim();
        final c1 = cells[1].text.trim();
        final c2 = cells[2].text.trim();
        if (c0.toLowerCase().contains('s.no') ||
            c2.toLowerCase() == 'course' ||
            c2.isEmpty) {
          continue;
        }

        final sNo = int.tryParse(c0) ?? (courses.length + 1);
        final yearSem = c1;

        // Parse Course e.g. "24CS301PC311-SOFTWARE ENGINEERING AND SYSTEM DESIGN"
        String courseCode = '';
        String courseName = c2;
        final dashIdx = c2.indexOf('-');
        final atIdx = c2.indexOf('@');
        if (dashIdx > 0 && dashIdx < 20) {
          courseCode = c2.substring(0, dashIdx).trim();
          courseName = c2.substring(dashIdx + 1).trim();
        } else if (atIdx > 0 && atIdx < 20) {
          courseCode = c2.substring(0, atIdx).trim();
          courseName = c2.substring(atIdx + 1).trim();
        }

        final cie = cells[3].text.trim().isEmpty ? '0' : cells[3].text.trim();
        final ete = cells[4].text.trim().isEmpty ? '0' : cells[4].text.trim();

        String? detailHref;
        String? formAction;
        String? formMethod;
        Map<String, String>? formFields;

        // Inspect View cell (cells[5]) or anywhere in the row for link / form
        final searchScope = cells.length >= 6 ? [cells[5], row] : [row];
        for (final scope in searchScope) {
          if (detailHref != null || formAction != null) break;

          final form = scope.querySelector('form');
          if (form != null) {
            final rawAction =
                form.attributes['action']?.trim() ?? 'student_mid1.php';
            formAction = _normalizeStudentHref(
              rawAction.isEmpty ? 'student_mid1.php' : rawAction,
            );
            formMethod =
                (form.attributes['method'] ?? 'POST').trim().toUpperCase();
            final fields = <String, String>{};
            for (final input
                in form.querySelectorAll('input, button, select')) {
              final name = input.attributes['name']?.trim();
              if (name != null && name.isNotEmpty) {
                fields[name] = input.attributes['value'] ?? '';
              }
            }
            formFields = fields;
            break;
          }

          for (final a in scope.querySelectorAll('a')) {
            final rawHref = a.attributes['href']?.trim() ?? '';
            final norm = _normalizeStudentHref(rawHref);
            if (norm.isNotEmpty) {
              detailHref = norm;
              break;
            }
            final onclick = a.attributes['onclick'] ?? '';
            final match =
                RegExp(r"""['"]([^'"]+\.php[^'"]*)['"]""").firstMatch(onclick);
            if (match != null) {
              detailHref = _normalizeStudentHref(match.group(1)!);
              break;
            }
          }

          if (detailHref == null) {
            for (final el in scope.querySelectorAll('[onclick]')) {
              final onclick = el.attributes['onclick'] ?? '';
              final match = RegExp(r"""['"]([^'"]+\.php[^'"]*)['"]""")
                  .firstMatch(onclick);
              if (match != null) {
                detailHref = _normalizeStudentHref(match.group(1)!);
                break;
              }
            }
          }
        }

        courses.add(
          SraapCourseMarks(
            sNo: sNo,
            yearSem: yearSem,
            courseCode: courseCode,
            courseName: courseName,
            cie: cie,
            ete: ete,
            detailHref: detailHref,
            formAction: formAction,
            formMethod: formMethod,
            formFields: formFields,
          ),
        );
      }
    }

    // If the HTML also contains a detail table (e.g. Course :SOFTWARE ENGINEERING...(24CS301PC311)), attach it
    final embeddedDetail = parseCourseMarksDetail(html);
    if (embeddedDetail.isNotEmpty && courses.isNotEmpty) {
      final htmlUpper = html.toUpperCase();
      for (int i = 0; i < courses.length; i++) {
        final c = courses[i];
        if ((c.courseCode.isNotEmpty &&
                htmlUpper.contains('(${c.courseCode.toUpperCase()})')) ||
            (c.courseName.isNotEmpty &&
                htmlUpper.contains(':${c.courseName.toUpperCase()}'))) {
          courses[i] = c.copyWith(components: embeddedDetail);
          break;
        }
      }
    }

    return courses;
  }

  /// Parses the detailed course marks table (Screenshot 3: Course :SOFTWARE ENGINEERING AND SYSTEM DESIGN(24CS301PC311))
  /// Columns: Mid Term Examination (20) | Lab Exam (10) | End Lab Exam (20) | Project (10) | Re Mid Marks | End Term Examination (40)
  static List<SraapAssessmentComponent> parseCourseMarksDetail(
    String html, {
    String? courseCode,
    String? courseName,
  }) {
    if (html.isEmpty) return [];
    final document = html_parser.parse(html);
    final tables = document.querySelectorAll('table');

    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) continue;

      final headerCells = rows[0]
          .children
          .where((e) => e.localName == 'th' || e.localName == 'td')
          .toList();
      if (headerCells.isEmpty) continue;

      final headerTexts = headerCells.map((c) => c.text.trim()).toList();
      final joinedHeaders = headerTexts.join(' ').toLowerCase();

      // Skip the main summary table ("S.No | Year-Sem | Course | CIE | ETE | View")
      if (joinedHeaders.contains('year-sem') &&
          joinedHeaders.contains('cie') &&
          joinedHeaders.contains('ete')) {
        continue;
      }
      // Skip student profile header table
      if (joinedHeaders.contains('father name') ||
          joinedHeaders.contains('batch number')) {
        continue;
      }

      final isDetailTable = joinedHeaders.contains('mid') ||
          joinedHeaders.contains('lab') ||
          joinedHeaders.contains('project') ||
          joinedHeaders.contains('end term') ||
          joinedHeaders.contains('exam') ||
          joinedHeaders.contains('quiz') ||
          joinedHeaders.contains('assignment') ||
          joinedHeaders.contains('internal') ||
          joinedHeaders.contains('marks') ||
          RegExp(r'\(\s*\d+\s*\)').hasMatch(joinedHeaders);

      if (!isDetailTable) continue;

      // Case 1: Horizontal table where row 0 is headers and row 1 is values
      final valueCells = rows[1]
          .children
          .where((e) => e.localName == 'td' || e.localName == 'th')
          .toList();
      if (headerCells.length >= 2 &&
          valueCells.length == headerCells.length &&
          rows.length == 2) {
        final List<SraapAssessmentComponent> components = [];
        for (int i = 0; i < headerCells.length; i++) {
          final label = headerCells[i].text.trim();
          if (label.isEmpty || label.toLowerCase() == 's.no') continue;
          final val = valueCells[i].text.trim();
          components.add(SraapAssessmentComponent(label: label, value: val));
        }
        if (components.isNotEmpty) return components;
      }

      // Case 2: Multi-row horizontal table (if multiple courses' detail rows are in one table)
      if (headerCells.length >= 3 && rows.length > 2) {
        dom.Element? targetRow;
        if (courseCode != null && courseCode.isNotEmpty) {
          for (final r in rows.skip(1)) {
            if (r.text.toUpperCase().contains(courseCode.toUpperCase())) {
              targetRow = r;
              break;
            }
          }
        }
        targetRow ??= rows[1];
        final cells = targetRow.children
            .where((e) => e.localName == 'td' || e.localName == 'th')
            .toList();
        if (cells.length == headerCells.length) {
          final List<SraapAssessmentComponent> components = [];
          for (int i = 0; i < headerCells.length; i++) {
            final label = headerCells[i].text.trim();
            if (label.isEmpty || label.toLowerCase() == 's.no') continue;
            components.add(
              SraapAssessmentComponent(
                label: label,
                value: cells[i].text.trim(),
              ),
            );
          }
          if (components.isNotEmpty) return components;
        }
      }

      // Case 3: Vertical 2-column table (Component | Marks)
      if (headerCells.length == 2 && rows.length >= 2) {
        final List<SraapAssessmentComponent> components = [];
        for (final r in rows.skip(1)) {
          final cells = r.children
              .where((e) => e.localName == 'td' || e.localName == 'th')
              .toList();
          if (cells.length >= 2) {
            final label = cells[0].text.trim();
            final val = cells[1].text.trim();
            if (label.isNotEmpty) {
              components.add(
                SraapAssessmentComponent(label: label, value: val),
              );
            }
          }
        }
        if (components.isNotEmpty) return components;
      }
    }

    return [];
  }

  /// Parses /student/student_sem_wise_memo.php ("Semester Memos")
  static List<SraapSemesterMemoRow> parseSemesterMemos(String html) {
    if (html.isEmpty) return [];
    final document = html_parser.parse(html);
    final List<SraapSemesterMemoRow> memos = [];

    final tables = document.querySelectorAll('table');
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) continue;

      final headerRow = rows.first;
      final headerCells = headerRow.children
          .where((e) => e.localName == 'th' || e.localName == 'td')
          .map((e) => e.text.trim().toLowerCase())
          .toList();
      final joined = headerCells.join(' ');
      if (joined.contains('father name') || joined.contains('batch number')) {
        continue;
      }

      int semIdx = -1;
      int codeIdx = -1;
      int nameIdx = -1;
      int gradeIdx = -1;
      int creditIdx = -1;
      int statusIdx = -1;

      for (int i = 0; i < headerCells.length; i++) {
        final h = headerCells[i];
        if (h.contains('sem') || h.contains('year')) {
          semIdx = i;
        } else if (h.contains('code')) {
          codeIdx = i;
        } else if (h.contains('course') ||
            h.contains('subject') ||
            h.contains('title') ||
            h.contains('memo')) {
          nameIdx = i;
        } else if (h.contains('grade') || h.contains('sgpa') || h.contains('cgpa')) {
          gradeIdx = i;
        } else if (h.contains('credit')) {
          creditIdx = i;
        } else if (h.contains('status') || h.contains('result')) {
          statusIdx = i;
        }
      }

      for (final row in rows.skip(1)) {
        final cells = row.children
            .where((e) => e.localName == 'td' || e.localName == 'th')
            .toList();
        if (cells.length < 2) continue;

        final firstText = cells[0].text.trim().toLowerCase();
        if (firstText == 's.no' || firstText == 'sno') continue;

        String? detailHref;
        final aTag = row.querySelector('a');
        if (aTag != null) {
          final norm = _normalizeStudentHref(aTag.attributes['href'] ?? '');
          if (norm.isNotEmpty) detailHref = norm;
        }

        String yearSem = semIdx >= 0 && semIdx < cells.length
            ? cells[semIdx].text.trim()
            : (cells.length >= 2 ? cells[1].text.trim() : '');
        String rawCourse = nameIdx >= 0 && nameIdx < cells.length
            ? cells[nameIdx].text.trim()
            : (cells.length >= 3 ? cells[2].text.trim() : cells.last.text.trim());
        String courseCode = codeIdx >= 0 && codeIdx < cells.length
            ? cells[codeIdx].text.trim()
            : '';
        String courseName = rawCourse;
        if (courseCode.isEmpty && rawCourse.contains('-')) {
          final idx = rawCourse.indexOf('-');
          if (idx > 0 && idx < 20) {
            courseCode = rawCourse.substring(0, idx).trim();
            courseName = rawCourse.substring(idx + 1).trim();
          }
        }
        String grade = gradeIdx >= 0 && gradeIdx < cells.length
            ? cells[gradeIdx].text.trim()
            : '';
        String credits = creditIdx >= 0 && creditIdx < cells.length
            ? cells[creditIdx].text.trim()
            : '';
        String status = statusIdx >= 0 && statusIdx < cells.length
            ? cells[statusIdx].text.trim()
            : '';

        if (courseName.isEmpty && yearSem.isEmpty) continue;

        memos.add(
          SraapSemesterMemoRow(
            yearSem: yearSem,
            courseCode: courseCode,
            courseName: courseName,
            grade: grade,
            credits: credits,
            status: status,
            detailHref: detailHref,
          ),
        );
      }
    }

    return memos;
  }

  /// Generic table parser for day-wise (`attendance_daywise.php`) or subject-wise (`attendance_subwise.php`) drilldowns.
  static List<Map<String, String>> parseGenericDetailTable(String html) {
    if (html.isEmpty) return [];
    final document = html_parser.parse(html);
    final tables = document.querySelectorAll('table');

    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) continue;

      final joined = rows.first.text.toLowerCase();
      if (joined.contains('father name') || joined.contains('batch number')) {
        continue;
      }

      final headers = rows.first.children
          .where((e) => e.localName == 'th' || e.localName == 'td')
          .map((e) => e.text.trim())
          .toList();
      if (headers.length < 2) continue;

      final List<Map<String, String>> result = [];
      for (final row in rows.skip(1)) {
        final cells = row.children
            .where((e) => e.localName == 'td' || e.localName == 'th')
            .map((e) => e.text.trim())
            .toList();
        if (cells.length < 2) continue;
        if (cells[0].toLowerCase() == 's.no') continue;

        final map = <String, String>{};
        for (int i = 0; i < headers.length && i < cells.length; i++) {
          final key = headers[i].isEmpty ? 'Col ${i + 1}' : headers[i];
          map[key] = cells[i];
        }
        if (map.isNotEmpty) {
          result.add(map);
        }
      }
      if (result.isNotEmpty) return result;
    }
    return [];
  }

  /// Parses placement/training attendance from https://sraap.in/student/std_training_atten_view.php
  static double? parsePlacementAttendance(String html) {
    if (html.isEmpty) return null;
    final document = html_parser.parse(html);

    final pElements = document.querySelectorAll(
      'p, span, strong, b, h1, h2, h3, h4, h5, div',
    );
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

    final tables = document.querySelectorAll('table');
    for (var table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.isEmpty) continue;

      int pctCol = -1;
      int presentCol = -1;
      int totalCol = -1;

      for (var row in rows) {
        final headers = row.querySelectorAll('th, td');
        for (int i = 0; i < headers.length; i++) {
          final hText = headers[i].text.trim().toLowerCase();
          if (hText.contains('%') ||
              hText.contains('percentage') ||
              hText.contains('atten %')) {
            pctCol = i;
          } else if (hText.contains('present') ||
              hText.contains('attended')) {
            presentCol = i;
          } else if (hText.contains('held') ||
              hText.contains('total') ||
              hText.contains('conducted')) {
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
        final isTotalRow = rowText.contains('total') ||
            rowText.contains('overall') ||
            rowText.contains('average');

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

        if (presentCol != -1 &&
            totalCol != -1 &&
            presentCol < cells.length &&
            totalCol < cells.length) {
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

    final regexes = [
      RegExp(
        r'(?:total|overall|training|placement)\s*attendance[^\d%]{0,30}(\d+(?:\.\d+)?)\s*%',
        caseSensitive: false,
      ),
      RegExp(
        r'attendance\s*%[^\d%]{0,30}(\d+(?:\.\d+)?)\s*%',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:\.\d+)?)\s*%\s*(?:attendance|overall|training)',
        caseSensitive: false,
      ),
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
