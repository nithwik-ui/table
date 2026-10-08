class FacultyProfile {
  final String name;
  final String facultyId;
  final String employeeId;
  final String department;
  final String email;
  final String designation;
  final String campus;

  FacultyProfile({
    required this.name,
    required this.facultyId,
    required this.employeeId,
    required this.department,
    required this.email,
    required this.designation,
    required this.campus,
  });

  factory FacultyProfile.fromJson(Map<String, dynamic> json) {
    return FacultyProfile(
      name: json['name']?.toString() ?? '',
      facultyId: json['faculty_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      campus: json['campus']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'faculty_id': facultyId,
      'employee_id': employeeId,
      'department': department,
      'email': email,
      'designation': designation,
      'campus': campus,
    };
  }
}
