class StudentProfile {
  final String name;
  final String rollNumber;
  final String enrollmentNumber;
  final String studentId;
  final String degree;
  final String program;
  final String department;
  final String academicYear;
  final String currentYear;
  final String section;
  final String batch;
  final String semester;
  final String email;
  final String mobileNumber;

  StudentProfile({
    required this.name,
    required this.rollNumber,
    required this.enrollmentNumber,
    required this.studentId,
    required this.degree,
    required this.program,
    required this.department,
    required this.academicYear,
    required this.currentYear,
    required this.section,
    required this.batch,
    required this.semester,
    required this.email,
    required this.mobileNumber,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      name: json['name']?.toString() ?? '',
      rollNumber: json['roll_number']?.toString() ?? '',
      enrollmentNumber: json['enrollment_number']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      degree: json['degree']?.toString() ?? '',
      program: json['program']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      academicYear: json['academic_year']?.toString() ?? '',
      currentYear: json['current_year']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      batch: json['batch']?.toString() ?? '',
      semester: json['semester']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'roll_number': rollNumber,
      'enrollment_number': enrollmentNumber,
      'student_id': studentId,
      'degree': degree,
      'program': program,
      'department': department,
      'academic_year': academicYear,
      'current_year': currentYear,
      'section': section,
      'batch': batch,
      'semester': semester,
      'email': email,
      'mobile_number': mobileNumber,
    };
  }
}
