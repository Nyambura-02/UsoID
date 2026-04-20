/// Lightweight summary of a student's attendance in a single unit.
/// Used by both [FirestoreService] and [StudentDashboardScreen].
class UnitAttendanceSummary {
  final String courseCode;
  final String unitName;
  final int sessionsAttended;
  final int totalSessions;

  const UnitAttendanceSummary({
    required this.courseCode,
    required this.unitName,
    required this.sessionsAttended,
    required this.totalSessions,
  });

  double get rate =>
      totalSessions > 0 ? sessionsAttended / totalSessions : 0.0;
}
