import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { active, closed }

class AttendanceSession {
  final String sessionId;
  final String courseCode;
  final String lecturerUid;
  final DateTime date;
  final SessionStatus status;
  final int totalPresent;

  const AttendanceSession({
    required this.sessionId,
    required this.courseCode,
    required this.lecturerUid,
    required this.date,
    this.status = SessionStatus.active,
    this.totalPresent = 0,
  });

  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceSession(
      sessionId: doc.id,
      courseCode: data['course_code'] ?? '',
      lecturerUid: data['lecturer_uid'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      status: SessionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SessionStatus.active,
      ),
      totalPresent: data['total_present'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_code': courseCode,
      'lecturer_uid': lecturerUid,
      'date': Timestamp.fromDate(date),
      'status': status.name,
      'total_present': totalPresent,
    };
  }

  bool get isActive => status == SessionStatus.active;

  AttendanceSession copyWith({
    SessionStatus? status,
    int? totalPresent,
  }) {
    return AttendanceSession(
      sessionId: sessionId,
      courseCode: courseCode,
      lecturerUid: lecturerUid,
      date: date,
      status: status ?? this.status,
      totalPresent: totalPresent ?? this.totalPresent,
    );
  }
}

class AttendanceRecord {
  final String schoolId;
  final DateTime matchedAt;
  final double confidence;

  const AttendanceRecord({
    required this.schoolId,
    required this.matchedAt,
    required this.confidence,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      schoolId: doc.id,
      matchedAt: (data['matched_at'] as Timestamp).toDate(),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'school_id': schoolId,
      'matched_at': Timestamp.fromDate(matchedAt),
      'confidence': confidence,
    };
  }
}
