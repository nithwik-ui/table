class SraapAcademicData {
  final double? overallAttendance;
  final List<SraapSubjectAttendance> subjects;
  final String? cgpa;
  final SraapMentor? mentor;
  final DateTime lastSynced;

  SraapAcademicData({
    this.overallAttendance,
    this.subjects = const [],
    this.cgpa,
    this.mentor,
    required this.lastSynced,
  });

  bool get isOverallSafe => (overallAttendance ?? 0.0) >= 75.0;
  bool get isOverallCondonation => (overallAttendance ?? 0.0) >= 65.0 && (overallAttendance ?? 0.0) < 75.0;
  bool get isOverallWarning => (overallAttendance ?? 0.0) < 65.0;

  String get overallStatusLabel {
    if (isOverallSafe) return 'Safe • Eligible';
    if (isOverallCondonation) return 'Condonation Zone';
    return 'Warning • Detention Risk';
  }

  Map<String, dynamic> toJson() {
    return {
      'overallAttendance': overallAttendance,
      'subjects': subjects.map((x) => x.toJson()).toList(),
      'cgpa': cgpa,
      'mentor': mentor?.toJson(),
      'lastSynced': lastSynced.toIso8601String(),
    };
  }

  factory SraapAcademicData.fromJson(Map<String, dynamic> json) {
    return SraapAcademicData(
      overallAttendance: (json['overallAttendance'] as num?)?.toDouble(),
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((x) => SraapSubjectAttendance.fromJson(Map<String, dynamic>.from(x as Map)))
              .toList() ??
          [],
      cgpa: json['cgpa'] as String?,
      mentor: json['mentor'] != null ? SraapMentor.fromJson(Map<String, dynamic>.from(json['mentor'] as Map)) : null,
      lastSynced: DateTime.tryParse(json['lastSynced']?.toString() ?? '') ?? DateTime.now(),
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

  SraapSubjectAttendance({
    required this.subjectName,
    this.subjectCode,
    required this.attendancePercentage,
    this.presentCount,
    this.absentCount,
    this.totalCount,
  });

  bool get isBelow65 => attendancePercentage < 65.0;
  bool get isCondonation => attendancePercentage >= 65.0 && attendancePercentage < 75.0;
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
    if (presentCount == null || totalCount == null || totalCount == 0) return null;
    if (attendancePercentage >= 75.0) return 0;
    final needed = (3 * totalCount! - 4 * presentCount!);
    return needed > 0 ? needed : 1;
  }

  int? get classesCanMissWhileSafe {
    if (presentCount == null || totalCount == null || totalCount == 0) return null;
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
    };
  }

  factory SraapSubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SraapSubjectAttendance(
      subjectName: json['subjectName'] ?? 'Unknown Subject',
      subjectCode: json['subjectCode'] as String?,
      attendancePercentage: (json['attendancePercentage'] as num?)?.toDouble() ?? 0.0,
      presentCount: json['presentCount'] as int?,
      absentCount: json['absentCount'] as int?,
      totalCount: json['totalCount'] as int?,
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
