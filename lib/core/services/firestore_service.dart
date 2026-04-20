import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uso_id/core/models/student.dart';
import 'package:uso_id/core/models/unit.dart';
import 'package:uso_id/core/models/attendance_session.dart';
import 'package:uso_id/core/models/unit_attendance_summary.dart';


final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════
  // STUDENTS
  // ══════════════════════════════════════════════════════

  /// Get all students
  Stream<List<Student>> watchStudents() {
    return _db.collection('students').snapshots().map(
          (snap) => snap.docs.map((doc) => Student.fromFirestore(doc)).toList(),
        );
  }

  /// Get a single student by school_id
  Future<Student?> getStudent(String schoolId) async {
    final doc = await _db.collection('students').doc(schoolId).get();
    return doc.exists ? Student.fromFirestore(doc) : null;
  }

  /// Create or update a student
  Future<void> upsertStudent(Student student) async {
    await _db
        .collection('students')
        .doc(student.schoolId)
        .set(student.toMap(), SetOptions(merge: true));
  }

  /// Bulk import students from CSV data
  Future<int> bulkImportStudents(List<Student> students) async {
    final batch = _db.batch();
    int count = 0;

    for (final student in students) {
      final ref = _db.collection('students').doc(student.schoolId);
      batch.set(ref, student.toMap(), SetOptions(merge: true));
      count++;

      // Firestore batch limit is 500
      if (count % 450 == 0) {
        await batch.commit();
      }
    }

    await batch.commit();
    return count;
  }

  /// Update student face embedding
  Future<void> enrollStudentFace(
    String schoolId,
    List<double> embedding,
  ) async {
    await _db.collection('students').doc(schoolId).update({
      'face_embedding': embedding,
      'is_enrolled': true,
      'enrolled_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get students by department
  Stream<List<Student>> watchStudentsByDepartment(String department) {
    return _db
        .collection('students')
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Student.fromFirestore(doc)).toList());
  }

  /// Get enrollment stats
  Future<Map<String, int>> getEnrollmentStats() async {
    final snap = await _db.collection('students').get();
    final total = snap.docs.length;
    final enrolled = snap.docs.where((doc) {
      final data = doc.data();
      return data['is_enrolled'] == true;
    }).length;

    return {
      'total': total,
      'enrolled': enrolled,
      'pending': total - enrolled,
    };
  }

  /// Alias for upsertStudent — used by manage_students_screen.dart
  Future<void> addStudent(Student student) => upsertStudent(student);

  /// Alias for bulkImportStudents — used by manage_students_screen.dart
  Future<int> bulkAddStudents(List<Student> students) =>
      bulkImportStudents(students);

  /// Check whether face embedding data exists for a student
  Future<bool> hasFaceData(String schoolId) async {
    if (schoolId.isEmpty) return false;
    final doc = await _db.collection('students').doc(schoolId).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    final emb = data['face_embedding'];
    return emb != null && (emb as List).isNotEmpty;
  }

  /// Real-time stream of attendance summaries for a single student.
  /// Used by StudentDashboardScreen.
  Stream<List<UnitAttendanceSummary>> watchStudentAttendanceSummary(
      String schoolId) async* {
    await for (final unitSnap in _db
        .collection('units')
        .where('registered_students', arrayContains: schoolId)
        .snapshots()) {
      final List<UnitAttendanceSummary> summaries = [];

      for (final unitDoc in unitSnap.docs) {
        final unitData = unitDoc.data();
        final courseCode = unitDoc.id;
        final unitName = unitData['unit_name'] as String? ?? courseCode;

        final sessionsSnap = await _db
            .collection('attendance_sessions')
            .where('course_code', isEqualTo: courseCode)
            .where('status', isEqualTo: 'closed')
            .get();

        final totalSessions = sessionsSnap.docs.length;
        int attended = 0;

        for (final sessionDoc in sessionsSnap.docs) {
          final presentDoc = await _db
              .collection('attendance_sessions')
              .doc(sessionDoc.id)
              .collection('present_students')
              .doc(schoolId)
              .get();
          if (presentDoc.exists) attended++;
        }

        summaries.add(UnitAttendanceSummary(
          courseCode: courseCode,
          unitName: unitName,
          sessionsAttended: attended,
          totalSessions: totalSessions,
        ));
      }

      yield summaries;
    }
  }


  // ══════════════════════════════════════════════════════
  // UNITS
  // ══════════════════════════════════════════════════════

  /// Get all units
  Stream<List<Unit>> watchUnits() {
    return _db.collection('units').snapshots().map(
          (snap) => snap.docs.map((doc) => Unit.fromFirestore(doc)).toList(),
        );
  }

  /// Get units assigned to a lecturer
  Stream<List<Unit>> watchLecturerUnits(String lecturerUid) {
    return _db
        .collection('units')
        .where('lecturer_uid', isEqualTo: lecturerUid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Unit.fromFirestore(doc)).toList());
  }

  /// Get units available for a student's department
  Stream<List<Unit>> watchDepartmentUnits(String department) {
    return _db
        .collection('units')
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Unit.fromFirestore(doc)).toList());
  }

  /// Create or update a unit
  Future<void> upsertUnit(Unit unit) async {
    await _db
        .collection('units')
        .doc(unit.courseCode)
        .set(unit.toMap(), SetOptions(merge: true));
  }

  /// Register a student for a unit
  Future<void> registerStudentForUnit(
      String courseCode, String schoolId) async {
    await _db.collection('units').doc(courseCode).update({
      'registered_students': FieldValue.arrayUnion([schoolId]),
    });
  }

  /// Unregister student from unit
  Future<void> unregisterStudentFromUnit(
      String courseCode, String schoolId) async {
    await _db.collection('units').doc(courseCode).update({
      'registered_students': FieldValue.arrayRemove([schoolId]),
    });
  }

  // ══════════════════════════════════════════════════════
  // ATTENDANCE SESSIONS
  // ══════════════════════════════════════════════════════

  /// Create a new attendance session
  Future<String> createSession(AttendanceSession session) async {
    final ref = _db.collection('attendance_sessions').doc();
    final newSession = AttendanceSession(
      sessionId: ref.id,
      courseCode: session.courseCode,
      lecturerUid: session.lecturerUid,
      date: session.date,
      status: SessionStatus.active,
      totalPresent: 0,
    );
    await ref.set(newSession.toMap());
    return ref.id;
  }

  /// Close a session
  Future<void> closeSession(String sessionId) async {
    // Count present students
    final presentSnap = await _db
        .collection('attendance_sessions')
        .doc(sessionId)
        .collection('present_students')
        .get();

    await _db.collection('attendance_sessions').doc(sessionId).update({
      'status': SessionStatus.closed.name,
      'total_present': presentSnap.docs.length,
    });
  }

  /// Get active session for a unit
  Future<AttendanceSession?> getActiveSession(String courseCode) async {
    final snap = await _db
        .collection('attendance_sessions')
        .where('course_code', isEqualTo: courseCode)
        .where('status', isEqualTo: SessionStatus.active.name)
        .limit(1)
        .get();

    return snap.docs.isEmpty
        ? null
        : AttendanceSession.fromFirestore(snap.docs.first);
  }

  /// Watch session history for a unit
  Stream<List<AttendanceSession>> watchSessionHistory(String courseCode) {
    return _db
        .collection('attendance_sessions')
        .where('course_code', isEqualTo: courseCode)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceSession.fromFirestore(doc))
            .toList());
  }

  /// Mark a student as present
  Future<void> markPresent({
    required String sessionId,
    required String schoolId,
    required double confidence,
  }) async {
    final record = AttendanceRecord(
      schoolId: schoolId,
      matchedAt: DateTime.now(),
      confidence: confidence,
    );

    await _db
        .collection('attendance_sessions')
        .doc(sessionId)
        .collection('present_students')
        .doc(schoolId)
        .set(record.toMap());

    // Increment counter
    await _db.collection('attendance_sessions').doc(sessionId).update({
      'total_present': FieldValue.increment(1),
    });
  }

  /// Check if student is already marked
  Future<bool> isStudentMarked(String sessionId, String schoolId) async {
    final doc = await _db
        .collection('attendance_sessions')
        .doc(sessionId)
        .collection('present_students')
        .doc(schoolId)
        .get();

    return doc.exists;
  }

  /// Get present students for a session
  Stream<List<AttendanceRecord>> watchPresentStudents(String sessionId) {
    return _db
        .collection('attendance_sessions')
        .doc(sessionId)
        .collection('present_students')
        .orderBy('matched_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceRecord.fromFirestore(doc))
            .toList());
  }

  // ══════════════════════════════════════════════════════
  // ANALYTICS
  // ══════════════════════════════════════════════════════

  /// Get attendance rate for a unit
  Future<double> getUnitAttendanceRate(String courseCode) async {
    final sessionsSnap = await _db
        .collection('attendance_sessions')
        .where('course_code', isEqualTo: courseCode)
        .where('status', isEqualTo: SessionStatus.closed.name)
        .get();

    if (sessionsSnap.docs.isEmpty) return 0.0;

    // Get unit to know total registered students
    final unitDoc = await _db.collection('units').doc(courseCode).get();
    if (!unitDoc.exists) return 0.0;

    final unit = Unit.fromFirestore(unitDoc);
    final totalRegistered = unit.registeredStudents.length;
    if (totalRegistered == 0) return 0.0;

    double totalRate = 0;
    for (final sessionDoc in sessionsSnap.docs) {
      final session = AttendanceSession.fromFirestore(sessionDoc);
      totalRate += session.totalPresent / totalRegistered;
    }

    return totalRate / sessionsSnap.docs.length;
  }

  /// Get student attendance summary across all units
  Future<Map<String, double>> getStudentAttendanceSummary(
      String schoolId) async {
    final unitsSnap = await _db
        .collection('units')
        .where('registered_students', arrayContains: schoolId)
        .get();

    final Map<String, double> summary = {};

    for (final unitDoc in unitsSnap.docs) {
      final courseCode = unitDoc.id;
      final sessionsSnap = await _db
          .collection('attendance_sessions')
          .where('course_code', isEqualTo: courseCode)
          .where('status', isEqualTo: SessionStatus.closed.name)
          .get();

      if (sessionsSnap.docs.isEmpty) {
        summary[courseCode] = 0.0;
        continue;
      }

      int attended = 0;
      for (final sessionDoc in sessionsSnap.docs) {
        final presentDoc = await _db
            .collection('attendance_sessions')
            .doc(sessionDoc.id)
            .collection('present_students')
            .doc(schoolId)
            .get();
        if (presentDoc.exists) attended++;
      }

      summary[courseCode] = attended / sessionsSnap.docs.length;
    }

    return summary;
  }

  /// Get at-risk students (below threshold)
  Future<List<Map<String, dynamic>>> getAtRiskStudents({
    double threshold = 0.5,
    String? courseCode,
  }) async {
    final List<Map<String, dynamic>> atRisk = [];

    // Get all closed sessions for the course
    var query = _db
        .collection('attendance_sessions')
        .where('status', isEqualTo: SessionStatus.closed.name);

    if (courseCode != null) {
      query = query.where('course_code', isEqualTo: courseCode);
    }

    final sessionsSnap = await query.get();
    if (sessionsSnap.docs.isEmpty) return atRisk;

    // Group sessions by course code
    final Map<String, List<AttendanceSession>> sessionsByCourse = {};
    for (final doc in sessionsSnap.docs) {
      final session = AttendanceSession.fromFirestore(doc);
      sessionsByCourse.putIfAbsent(session.courseCode, () => []).add(session);
    }

    // Check each unit's students
    for (final entry in sessionsByCourse.entries) {
      final unitDoc = await _db.collection('units').doc(entry.key).get();
      if (!unitDoc.exists) continue;

      final unit = Unit.fromFirestore(unitDoc);
      final totalSessions = entry.value.length;

      for (final studentId in unit.registeredStudents) {
        int attended = 0;
        for (final session in entry.value) {
          final presentDoc = await _db
              .collection('attendance_sessions')
              .doc(session.sessionId)
              .collection('present_students')
              .doc(studentId)
              .get();
          if (presentDoc.exists) attended++;
        }

        final rate = totalSessions > 0 ? attended / totalSessions : 0.0;
        if (rate < threshold) {
          final studentDoc =
              await _db.collection('students').doc(studentId).get();
          if (studentDoc.exists) {
            atRisk.add({
              'student': Student.fromFirestore(studentDoc),
              'course_code': entry.key,
              'attendance_rate': rate,
              'sessions_attended': attended,
              'total_sessions': totalSessions,
            });
          }
        }
      }
    }

    // Sort by worst attendance first
    atRisk.sort((a, b) =>
        (a['attendance_rate'] as double).compareTo(b['attendance_rate'] as double));

    return atRisk;
  }
}
