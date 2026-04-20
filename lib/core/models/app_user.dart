import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, lecturer, student }

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final String? department;
  final String? schoolId; // Only for students
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.department,
    this.schoolId,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.student,
      ),
      department: data['department'],
      schoolId: data['school_id'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'department': department,
      'school_id': schoolId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isLecturer => role == UserRole.lecturer;
  bool get isStudent => role == UserRole.student;
}
