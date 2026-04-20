import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uso_id/core/services/firestore_service.dart';
import 'package:uso_id/core/models/attendance_session.dart';
import 'package:uso_id/core/theme/app_theme.dart';

class SessionHistoryScreen extends ConsumerWidget {
  final String courseCode;
  const SessionHistoryScreen({super.key, required this.courseCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$courseCode — History'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AttendanceSession>>(
        stream: firestoreService.watchSessions(courseCode),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snap.data ?? [];

          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                'No sessions yet.\nStart an attendance session from the dashboard.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionCard(session: session);
            },
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AttendanceSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = session.createdAt;
    final dateStr =
        '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final attendanceRate = session.totalStudents > 0
        ? (session.presentCount / session.totalStudents * 100)
            .toStringAsFixed(1)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        title: Text(
          dateStr,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _Pill(
                label: '${session.presentCount} present',
                color: AppTheme.success,
              ),
              const SizedBox(width: 6),
              _Pill(
                label:
                    '${session.totalStudents - session.presentCount} absent',
                color: AppTheme.danger,
              ),
              const SizedBox(width: 6),
              if (session.openStatus)
                _Pill(label: 'OPEN', color: AppTheme.warning),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$attendanceRate%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _rateColor(double.tryParse(attendanceRate) ?? 0),
                  ),
            ),
            Text(
              'attendance',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        children: [
          if (session.attendanceRecords.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: session.attendanceRecords.length,
              itemBuilder: (context, i) {
                final record = session.attendanceRecords[i];
                return _StudentRow(record: record);
              },
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No attendance records found.'),
            ),
        ],
      ),
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 75) return AppTheme.success;
    if (rate >= 50) return AppTheme.warning;
    return AppTheme.danger;
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final AttendanceRecord record;
  const _StudentRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            record.present ? Icons.check_circle : Icons.cancel,
            color: record.present ? AppTheme.success : AppTheme.danger,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              record.schoolId,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (record.confidence != null)
            Text(
              '${(record.confidence! * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
