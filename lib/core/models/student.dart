import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String schoolId;
  final String fullName;
  final String email;
  final String courseCode;
  final String department;
  final List<double>? faceEmbedding;
  final bool isEnrolled;
  final DateTime? enrolledAt;
  final DateTime? createdAt;

  const Student({
    required this.schoolId,
    required this.fullName,
    this.email = '',
    this.courseCode = '',
    this.department = '',
    this.faceEmbedding,
    this.isEnrolled = false,
    this.enrolledAt,
    this.createdAt,
  });

  /// Alias used by manage_students_screen.dart
  bool get faceEnrolled => isEnrolled;

  factory Student.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student(
      schoolId: doc.id,
      fullName: data['full_name'] ?? '',
      email: data['email'] ?? '',
      courseCode: data['course_code'] ?? data['department'] ?? '',
      department: data['department'] ?? data['course_code'] ?? '',
      faceEmbedding: data['face_embedding'] != null
          ? List<double>.from(data['face_embedding'])
          : null,
      isEnrolled: data['is_enrolled'] ?? data['face_enrolled'] ?? false,
      enrolledAt: data['enrolled_at'] != null
          ? (data['enrolled_at'] as Timestamp).toDate()
          : null,
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'school_id': schoolId,
      'email': email,
      'course_code': courseCode,
      'department': department.isEmpty ? courseCode : department,
      'face_embedding': faceEmbedding,
      'is_enrolled': isEnrolled,
      'enrolled_at':
          enrolledAt != null ? Timestamp.fromDate(enrolledAt!) : null,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  Student copyWith({
    String? fullName,
    String? email,
    String? courseCode,
    String? department,
    List<double>? faceEmbedding,
    bool? isEnrolled,
    DateTime? enrolledAt,
  }) {
    return Student(
      schoolId: schoolId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      courseCode: courseCode ?? this.courseCode,
      department: department ?? this.department,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      createdAt: createdAt,
    );
  }
}
