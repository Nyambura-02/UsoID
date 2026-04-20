import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uso_id/core/models/app_user.dart';
import 'package:uso_id/core/services/auth_service.dart';

// Feature screens
import 'package:uso_id/features/auth/screens/login_screen.dart';
import 'package:uso_id/features/admin/screens/admin_dashboard_screen.dart';
import 'package:uso_id/features/admin/screens/student_management_screen.dart';
import 'package:uso_id/features/admin/screens/unit_management_screen.dart';
import 'package:uso_id/features/admin/screens/analytics_screen.dart';
import 'package:uso_id/features/lecturer/screens/lecturer_dashboard_screen.dart';
import 'package:uso_id/features/lecturer/screens/scan_attendance_screen.dart';
import 'package:uso_id/features/lecturer/screens/session_history_screen.dart';
import 'package:uso_id/features/student/screens/student_dashboard_screen.dart';
import 'package:uso_id/features/student/screens/student_registration_screen.dart';
import 'package:uso_id/features/student/screens/face_enrollment_screen.dart';
import 'package:uso_id/features/shared/screens/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';

      if (isSplash) return null; // Let splash handle redirect

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/splash-redirect';
      }

      return null;
    },
    routes: [
      // ── Splash / Loading ──
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth ──
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Splash Redirect (determines role-based redirect) ──
      GoRoute(
        path: '/splash-redirect',
        builder: (context, state) => const SplashScreen(),
      ),

      // ══════════════════════════════════════════
      // ADMIN ROUTES
      // ══════════════════════════════════════════
      ShellRoute(
        builder: (context, state, child) => _AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/students',
            builder: (context, state) => const StudentManagementScreen(),
          ),
          GoRoute(
            path: '/admin/units',
            builder: (context, state) => const UnitManagementScreen(),
          ),
          GoRoute(
            path: '/admin/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
        ],
      ),

      // ══════════════════════════════════════════
      // LECTURER ROUTES
      // ══════════════════════════════════════════
      ShellRoute(
        builder: (context, state, child) => _LecturerShell(child: child),
        routes: [
          GoRoute(
            path: '/lecturer',
            builder: (context, state) => const LecturerDashboardScreen(),
          ),
          GoRoute(
            path: '/lecturer/scan/:courseCode',
            builder: (context, state) => ScanAttendanceScreen(
              courseCode: state.pathParameters['courseCode']!,
            ),
          ),
          GoRoute(
            path: '/lecturer/history/:courseCode',
            builder: (context, state) => SessionHistoryScreen(
              courseCode: state.pathParameters['courseCode']!,
            ),
          ),
        ],
      ),

      // ══════════════════════════════════════════
      // STUDENT ROUTES
      // ══════════════════════════════════════════
      ShellRoute(
        builder: (context, state, child) => _StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            builder: (context, state) => const StudentDashboardScreen(),
          ),
          GoRoute(
            path: '/student/register',
            builder: (context, state) => const StudentRegistrationScreen(),
          ),
          GoRoute(
            path: '/student/enroll-face',
            builder: (context, state) => const FaceEnrollmentScreen(),
          ),
        ],
      ),
    ],
  );
});

// ── Navigation Shells ──

class _AdminShell extends StatelessWidget {
  final Widget child;
  const _AdminShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getIndex(GoRouterState.of(context).matchedLocation),
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Units',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  int _getIndex(String location) {
    if (location.startsWith('/admin/students')) return 1;
    if (location.startsWith('/admin/units')) return 2;
    if (location.startsWith('/admin/analytics')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/admin');
      case 1:
        context.go('/admin/students');
      case 2:
        context.go('/admin/units');
      case 3:
        context.go('/admin/analytics');
    }
  }
}

class _LecturerShell extends StatelessWidget {
  final Widget child;
  const _LecturerShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}

class _StudentShell extends StatelessWidget {
  final Widget child;
  const _StudentShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}
