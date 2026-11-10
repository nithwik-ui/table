class SraapAcademicData {
  final double? overallAttendance;
  final double? placementAttendance;
  final List<SraapSubjectAttendance> subjects;
  final String? cgpa;
  final SraapMentor? mentor;
  final String? yearSem;
  final String? batchNumber;
  final int? coursesCount;
  final int? backlogsCount;
  final String? alphaCoins;
  final String? sigmaCoins;
  final List<String> announcements;
  final List<SraapDailyAttendance> recentDailyAttendance;
  final DateTime lastSynced;

  SraapAcademicData({
    this.overallAttendance,
    this.placementAttendance,
    this.subjects = const [],
    this.cgpa,
    this.mentor,
    this.yearSem,
    this.batchNumber,
    this.coursesCount,
    this.backlogsCount,
    this.alphaCoins,
    this.sigmaCoins,
    this.announcements = const [],
    this.recentDailyAttendance = const [],
    required this.lastSynced,
  });

  bool get isOverallSafe => (overallAttendance ?? 0.0) >= 75.0;
  bool get isOverallCondonation =>
      (overallAttendance ?? 0.0) >= 65.0 && (overallAttendance ?? 0.0) < 75.0;
  bool get isOverallWarning => (overallAttendance ?? 0.0) < 65.0;

  String get overallStatusLabel {
    if (isOverallSafe) return 'Safe • Eligible';
    if (isOverallCondonation) return 'Condonation Zone';
    return 'Warning • Detention Risk';
  }

  Map<String, dynamic> toJson() {
    return {
      'overallAttendance': overallAttendance,
      'placementAttendance': placementAttendance,
      'subjects': subjects.map((x) => x.toJson()).toList(),
      'cgpa': cgpa,
      'mentor': mentor?.toJson(),
      'yearSem': yearSem,
      'batchNumber': batchNumber,
      'coursesCount': coursesCount,
      'backlogsCount': backlogsCount,
      'alphaCoins': alphaCoins,
      'sigmaCoins': sigmaCoins,
      'announcements': announcements,
      'recentDailyAttendance':
          recentDailyAttendance.map((x) => x.toJson()).toList(),
      'lastSynced': lastSynced.toIso8601String(),
    };
  }

  factory SraapAcademicData.fromJson(Map<String, dynamic> json) {
    return SraapAcademicData(
      overallAttendance: (json['overallAttendance'] as num?)?.toDouble(),
      placementAttendance: (json['placementAttendance'] as num?)?.toDouble(),
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map(
                (x) => SraapSubjectAttendance.fromJson(
                  Map<String, dynamic>.from(x as Map),
                ),
              )
              .toList() ??
          [],
      cgpa: json['cgpa'] as String?,
      mentor: json['mentor'] != null
          ? SraapMentor.fromJson(
              Map<String, dynamic>.from(json['mentor'] as Map),
            )
          : null,
      yearSem: json['yearSem'] as String?,
      batchNumber: json['batchNumber'] as String?,
      coursesCount: json['coursesCount'] as int?,
      backlogsCount: json['backlogsCount'] as int?,
      alphaCoins: json['alphaCoins'] as String?,
      sigmaCoins: json['sigmaCoins'] as String?,
      announcements: (json['announcements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recentDailyAttendance:
          (json['recentDailyAttendance'] as List<dynamic>?)
                  ?.map(
                    (x) => SraapDailyAttendance.fromJson(
                      Map<String, dynamic>.from(x as Map),
                    ),
                  )
                  .toList() ??
              [],
      lastSynced:
          DateTime.tryParse(json['lastSynced']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SraapDailyAttendance {
  final String date;
  final int held;
  final int attended;
  final String? detailHref;

  const SraapDailyAttendance({
    required this.date,
    required this.held,
    required this.attended,
    this.detailHref,
  });

  double get percentage => held > 0 ? (attended / held) * 100.0 : 0.0;

  Map<String, dynamic> toJson() => {
        'date': date,
        'held': held,
        'attended': attended,
        'detailHref': detailHref,
      };

  factory SraapDailyAttendance.fromJson(Map<String, dynamic> json) {
    return SraapDailyAttendance(
      date: json['date']?.toString() ?? '',
      held: (json['held'] as num?)?.toInt() ?? 0,
      attended: (json['attended'] as num?)?.toInt() ?? 0,
      detailHref: json['detailHref'] as String?,
    );
  }
}

class SraapSubjectAttendance {
  final String subjectName;
  final String? subjectCode;
  final double attendancePercentage;
  final int? presentCount;
  final int? absentCount;
  final int? totalCount;
  final int? ltpCount;
  final String? detailHref;

  SraapSubjectAttendance({
    required this.subjectName,
    this.subjectCode,
    required this.attendancePercentage,
    this.presentCount,
    this.absentCount,
    this.totalCount,
    this.ltpCount,
    this.detailHref,
  });

  bool get isBelow65 => attendancePercentage < 65.0;
  bool get isCondonation =>
      attendancePercentage >= 65.0 && attendancePercentage < 75.0;
  bool get isSafe => attendancePercentage >= 75.0;

  String get statusLabel {
    if (isSafe) return 'Safe';
    if (isCondonation) return 'Condonation Zone';
    return 'Warning';
  }

  String get secondaryStatusLabel {
    if (isSafe) return 'Eligible';
    if (isCondonation) return '';
    return 'Detention Risk';
  }

  String get fullStatusLabel {
    if (isSafe) return 'Safe • Eligible';
    if (isCondonation) return 'Condonation Zone';
    return 'Warning • Detention Risk';
  }

  int? get classesNeededFor75 {
    if (presentCount == null || totalCount == null || totalCount == 0) {
      return null;
    }
    if (attendancePercentage >= 75.0) return 0;
    final needed = (3 * totalCount! - 4 * presentCount!);
    return needed > 0 ? needed : 1;
  }

  int? get classesCanMissWhileSafe {
    if (presentCount == null || totalCount == null || totalCount == 0) {
      return null;
    }
    if (attendancePercentage < 75.0) return 0;
    final canMiss = (4 * presentCount! - 3 * totalCount!) ~/ 3;
    return canMiss > 0 ? canMiss : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'subjectName': subjectName,
      'subjectCode': subjectCode,
      'attendancePercentage': attendancePercentage,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'totalCount': totalCount,
      'ltpCount': ltpCount,
      'detailHref': detailHref,
    };
  }

  factory SraapSubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SraapSubjectAttendance(
      subjectName: json['subjectName'] ?? 'Unknown Subject',
      subjectCode: json['subjectCode'] as String?,
      attendancePercentage:
          (json['attendancePercentage'] as num?)?.toDouble() ?? 0.0,
      presentCount: json['presentCount'] as int?,
      absentCount: json['absentCount'] as int?,
      totalCount: json['totalCount'] as int?,
      ltpCount: json['ltpCount'] as int?,
      detailHref: json['detailHref'] as String?,
    );
  }
}

class SraapMentor {
  final String name;
  final String? department;

  SraapMentor({
    required this.name,
    this.department,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
    };
  }

  factory SraapMentor.fromJson(Map<String, dynamic> json) {
    return SraapMentor(
      name: json['name'] ?? 'Unknown Mentor',
      department: json['department'] as String?,
    );
  }
}

class SraapAssessmentComponent {
  final String label;
  final String value;

  const SraapAssessmentComponent({
    required this.label,
    required this.value,
  });

  double? get maxMarks {
    final match = RegExp(r'\(\s*(\d+(?:\.\d+)?)\s*\)').firstMatch(label);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  double? get scoredMarks => double.tryParse(value.trim());

  bool get isEntered => value.trim().isNotEmpty;

  String get cleanTitle =>
      label.replaceAll(RegExp(r'\(\s*\d+(?:\.\d+)?\s*\)'), '').trim();

  bool get isEndTerm =>
      label.toLowerCase().contains('end term') ||
      label.toLowerCase().contains('ete');

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
      };

  factory SraapAssessmentComponent.fromJson(Map<String, dynamic> json) {
    return SraapAssessmentComponent(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

class SraapCourseMarks {
  final int sNo;
  final String yearSem;
  final String courseCode;
  final String courseName;
  final String cie;
  final String ete;
  final String? detailHref;
  final String? formAction;
  final String? formMethod;
  final Map<String, String>? formFields;
  final List<SraapAssessmentComponent> components;

  const SraapCourseMarks({
    required this.sNo,
    required this.yearSem,
    required this.courseCode,
    required this.courseName,
    required this.cie,
    required this.ete,
    this.detailHref,
    this.formAction,
    this.formMethod,
    this.formFields,
    this.components = const [],
  });

  double get cieScore => double.tryParse(cie.trim()) ?? 0.0;
  double get eteScore => double.tryParse(ete.trim()) ?? 0.0;
  double get totalScore => cieScore + eteScore;

  bool get isEtePublished {
    final v = ete.trim();
    if (v.isEmpty || v == '-' || v == 'NA') return false;
    final numVal = double.tryParse(v);
    return numVal != null && numVal > 0;
  }

  bool get hasDetailAction =>
      (detailHref != null && detailHref!.isNotEmpty) ||
      (formAction != null && formAction!.isNotEmpty) ||
      components.isNotEmpty;

  SraapCourseMarks copyWith({
    List<SraapAssessmentComponent>? components,
  }) {
    return SraapCourseMarks(
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
      components: components ?? this.components,
    );
  }

  Map<String, dynamic> toJson() => {
        'sNo': sNo,
        'yearSem': yearSem,
        'courseCode': courseCode,
        'courseName': courseName,
        'cie': cie,
        'ete': ete,
        'detailHref': detailHref,
        'formAction': formAction,
        'formMethod': formMethod,
        'formFields': formFields,
        'components': components.map((x) => x.toJson()).toList(),
      };

  factory SraapCourseMarks.fromJson(Map<String, dynamic> json) {
    return SraapCourseMarks(
      sNo: (json['sNo'] as num?)?.toInt() ?? 0,
      yearSem: json['yearSem']?.toString() ?? '',
      courseCode: json['courseCode']?.toString() ?? '',
      courseName: json['courseName']?.toString() ?? '',
      cie: json['cie']?.toString() ?? '0',
      ete: json['ete']?.toString() ?? '0',
      detailHref: json['detailHref'] as String?,
      formAction: json['formAction'] as String?,
      formMethod: json['formMethod'] as String?,
      formFields: json['formFields'] != null
          ? Map<String, String>.from(json['formFields'] as Map)
          : null,
      components: (json['components'] as List<dynamic>?)
              ?.map(
                (x) => SraapAssessmentComponent.fromJson(
                  Map<String, dynamic>.from(x as Map),
                ),
              )
              .toList() ??
          [],
    );
  }
}

class SraapSemesterMemoRow {
  final String yearSem;
  final String courseCode;
  final String courseName;
  final String grade;
  final String credits;
  final String status;
  final String? detailHref;

  const SraapSemesterMemoRow({
    required this.yearSem,
    required this.courseCode,
    required this.courseName,
    required this.grade,
    required this.credits,
    required this.status,
    this.detailHref,
  });

  Map<String, dynamic> toJson() => {
        'yearSem': yearSem,
        'courseCode': courseCode,
        'courseName': courseName,
        'grade': grade,
        'credits': credits,
        'status': status,
        'detailHref': detailHref,
      };

  factory SraapSemesterMemoRow.fromJson(Map<String, dynamic> json) {
    return SraapSemesterMemoRow(
      yearSem: json['yearSem']?.toString() ?? '',
      courseCode: json['courseCode']?.toString() ?? '',
      courseName: json['courseName']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      credits: json['credits']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      detailHref: json['detailHref'] as String?,
    );
  }
}

class SraapInternalMarksData {
  final List<SraapCourseMarks> courses;
  final List<SraapSemesterMemoRow> memos;
  final DateTime lastSynced;

  const SraapInternalMarksData({
    this.courses = const [],
    this.memos = const [],
    required this.lastSynced,
  });

  double get averageCie {
    if (courses.isEmpty) return 0.0;
    final total = courses.fold<double>(0.0, (sum, c) => sum + c.cieScore);
    return double.parse((total / courses.length).toStringAsFixed(1));
  }

  double get totalCieScored {
    return courses.fold<double>(0.0, (sum, c) => sum + c.cieScore);
  }

  List<String> get availableSemesters {
    final sems = <String>{};
    for (final c in courses) {
      if (c.yearSem.trim().isNotEmpty) {
        sems.add(c.yearSem.trim());
      }
    }
    return sems.toList();
  }

  Map<String, dynamic> toJson() => {
        'courses': courses.map((x) => x.toJson()).toList(),
        'memos': memos.map((x) => x.toJson()).toList(),
        'lastSynced': lastSynced.toIso8601String(),
      };

  factory SraapInternalMarksData.fromJson(Map<String, dynamic> json) {
    return SraapInternalMarksData(
      courses: (json['courses'] as List<dynamic>?)
              ?.map(
                (x) => SraapCourseMarks.fromJson(
                  Map<String, dynamic>.from(x as Map),
                ),
              )
              .toList() ??
          [],
      memos: (json['memos'] as List<dynamic>?)
              ?.map(
                (x) => SraapSemesterMemoRow.fromJson(
                  Map<String, dynamic>.from(x as Map),
                ),
              )
              .toList() ??
          [],
      lastSynced:
          DateTime.tryParse(json['lastSynced']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
