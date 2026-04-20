import 'package:cloud_firestore/cloud_firestore.dart';

class Unit {
  final String courseCode;
  final String unitName;
  final String department;
  final String lecturerUid;
  final List<String> registeredStudents;

  const Unit({
    required this.courseCode,
    required this.unitName,
    required this.department,
    required this.lecturerUid,
    this.registeredStudents = const [],
  });

  factory Unit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Unit(
      courseCode: doc.id,
      unitName: data['unit_name'] ?? '',
      department: data['department'] ?? '',
      lecturerUid: data['lecturer_uid'] ?? '',
      registeredStudents: List<String>.from(data['registered_students'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'unit_name': unitName,
      'course_code': courseCode,
      'department': department,
      'lecturer_uid': lecturerUid,
      'registered_students': registeredStudents,
    };
  }

  int get studentCount => registeredStudents.length;

  Unit copyWith({
    String? unitName,
    String? department,
    String? lecturerUid,
    List<String>? registeredStudents,
  }) {
    return Unit(
      courseCode: courseCode,
      unitName: unitName ?? this.unitName,
      department: department ?? this.department,
      lecturerUid: lecturerUid ?? this.lecturerUid,
      registeredStudents: registeredStudents ?? this.registeredStudents,
    );
  }
}
