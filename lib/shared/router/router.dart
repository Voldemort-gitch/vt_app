import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/providers/auth_provider.dart';
import '../../features/authentication/views/login_screen.dart';
import '../../features/authentication/views/biometric_screen.dart';
import '../../features/dashboard/views/employee_dashboard_screen.dart';
import '../../features/dashboard/views/admin_dashboard_screen.dart';
import '../../features/dashboard/views/employee_profile_screen.dart';
import '../../features/dashboard/views/admin_reports_screen.dart';
import '../../features/attendance/views/employee_history_screen.dart';
import '../../features/attendance/views/admin_attendance_screen.dart';
import '../../features/employees/views/admin_employee_crud_screen.dart';
import '../../features/leave/views/employee_leave_request_screen.dart';
import '../../features/leave/views/admin_leave_approval_screen.dart';
import '../../features/leave/views/admin_leave_calendar_screen.dart';
import '../../features/settings/views/admin_settings_screen.dart';
import '../../features/qr/views/qr_scanner_screen.dart';
import '../../features/qr/views/qr_display_screen.dart';
import '../../features/payroll/views/admin_payroll_dashboard.dart';
import '../../features/payroll/views/admin_payroll_review.dart';
import '../../features/payroll/views/admin_salary_config.dart';
import '../../features/payroll/views/employee_salary_screen.dart';
import '../../features/advance/views/employee_advance_request.dart';
import '../../features/advance/views/admin_advance_approval.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final profile = authState.profile;
      final location = state.matchedLocation;

      if (authState.isInitializing) return null;

      if (profile != null) {
        if (authState.biometricAvailable &&
            authState.biometricEnabled &&
            location == '/login') {
          return '/biometric';
        }
        if (location == '/biometric') {
          if (authState.biometricAvailable && authState.biometricEnabled) return null;
          if (profile.isAdmin) return '/admin';
          return '/employee';
        }
        if (location == '/login') {
          if (profile.isAdmin) return '/admin';
          return '/employee';
        }
        return null;
      }

      if (location != '/login') return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/biometric',
        builder: (context, state) => const BiometricScreen(),
      ),
      GoRoute(
        path: '/employee',
        builder: (context, state) => const EmployeeDashboardScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, state) => const EmployeeHistoryScreen(),
          ),
          GoRoute(
            path: 'leave',
            builder: (context, state) => const EmployeeLeaveRequestScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const EmployeeProfileScreen(),
          ),
          GoRoute(
            path: 'qr-scanner',
            builder: (context, state) => const QrScannerScreen(),
          ),
          GoRoute(
            path: 'advance',
            builder: (context, state) => const EmployeeAdvanceRequest(),
          ),
          GoRoute(
            path: 'salary',
            builder: (context, state) => const EmployeeSalaryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'attendance',
            builder: (context, state) => const AdminAttendanceScreen(),
          ),
          GoRoute(
            path: 'employees',
            builder: (context, state) => const AdminEmployeeCrudScreen(),
          ),
          GoRoute(
            path: 'leave',
            builder: (context, state) => const AdminLeaveApprovalScreen(),
            routes: [
              GoRoute(
                path: 'calendar',
                builder: (context, state) => const AdminLeaveCalendarScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const AdminReportsScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),
          GoRoute(
            path: 'qr-code',
            builder: (context, state) => const QrDisplayScreen(),
          ),
          GoRoute(
            path: 'advance',
            builder: (context, state) => const AdminAdvanceApproval(),
          ),
          GoRoute(
            path: 'payroll',
            builder: (context, state) => const AdminPayrollDashboard(),
          ),
          GoRoute(
            path: 'payroll/salary',
            builder: (context, state) => const AdminSalaryConfig(),
          ),
          GoRoute(
            path: 'payroll/review/:id',
            builder: (context, state) => const AdminPayrollReview(),
          ),
        ],
      ),
    ],
  );

  ref.listen<AuthState>(authStateProvider, (_, __) {
    router.refresh();
  });

  return router;
});
