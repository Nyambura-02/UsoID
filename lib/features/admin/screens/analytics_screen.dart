import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uso_id/core/models/attendance_session.dart';
import 'package:uso_id/core/services/auth_service.dart';
import 'package:uso_id/core/services/firestore_service.dart';
import 'package:uso_id/core/theme/app_theme.dart';
import 'package:uso_id/features/shared/widgets/section_header.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        // ✅ Correct method name from FirestoreService
        future: firestoreService.getEnrollmentStats(),
        builder: (context, snap) {
          final data = snap.data ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'Student Overview'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Students',
                      value: '${data['total'] ?? '—'}',
                      icon: Icons.people_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Face Enrolled',
                      value: '${data['enrolled'] ?? '—'}',
                      icon: Icons.face_rounded,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Pending Enrollment',
                      value: '${data['pending'] ?? '—'}',
                      icon: Icons.pending_rounded,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Attendance Sessions'),
              const SizedBox(height: 12),
              // ✅ Uses watchUnits() + watchSessionHistory() per-unit
              _RecentSessionsList(firestoreService: firestoreService),
            ],
          );
        },
      ),
    );
  }
}

/// Fetches unit list, then collects the latest sessions from each unit.
class _RecentSessionsList extends StatelessWidget {
  final FirestoreService firestoreService;
  const _RecentSessionsList({required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: firestoreService.watchUnits(),
      builder: (context, unitSnap) {
        if (unitSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final units = unitSnap.data ?? [];
        if (units.isEmpty) {
          return _emptyCard('No units configured yet.');
        }

        // Show session streams for each unit in a column
        return Column(
          children: units.map((unit) {
            return StreamBuilder<List<AttendanceSession>>(
              stream: firestoreService.watchSessionHistory(unit.courseCode),
              builder: (context, sessionSnap) {
                final sessions = sessionSnap.data ?? [];
                if (sessions.isEmpty) return const SizedBox.shrink();

                // Show only the most recent session per unit
                final latest = sessions.first;
                return _SessionRow(
                  courseCode: unit.courseCode,
                  session: latest,
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Center(
        child: Text(msg,
            style: const TextStyle(color: AppTheme.textSecondary)),
      ),
    );
  }
}

// ─── Stat Card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session Row ─────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final String courseCode;
  final AttendanceSession session;
  const _SessionRow({required this.courseCode, required this.session});

  @override
  Widget build(BuildContext context) {
    final date = session.date;
    final isClosed = session.status == SessionStatus.closed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(
            isClosed
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_checked,
            color: isClosed ? AppTheme.success : AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseCode,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}  ·  ${isClosed ? 'Closed' : 'Active'}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${session.totalPresent} present',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
