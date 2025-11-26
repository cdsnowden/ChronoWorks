import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/password_reset_screen.dart';
import 'screens/auth/first_admin_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/employee_list_screen.dart';
import 'screens/admin/add_employee_screen.dart';
import 'screens/admin/edit_employee_screen.dart';
import 'screens/admin/admin_time_tracking_screen.dart';
import 'screens/admin/schedule_grid_screen.dart';
import 'screens/admin/shift_templates_screen.dart';
import 'screens/admin/overtime_approval_queue_screen.dart';
import 'screens/admin/overtime_risk_dashboard.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/manager/time_off_approval_screen.dart' as manager_time_off;
import 'screens/employee/employee_dashboard.dart';
import 'screens/employee/clock_screen.dart';
import 'screens/employee/time_entries_screen.dart';
import 'screens/employee/my_schedule_screen.dart';
import 'screens/subscription_plans_page.dart';
import 'screens/super_admin/super_admin_dashboard.dart';
import 'screens/account_manager/am_dashboard_screen.dart';
import 'screens/customer_subscription_management_screen.dart';
import 'screens/signup/company_signup_form_screen.dart';
import 'screens/signup/plan_selection_screen.dart';
import 'screens/admin/registration_requests_page.dart';
import 'screens/profile/complete_profile_screen.dart';
import 'screens/employee/request_time_off_screen.dart';
import 'screens/employee/my_time_off_screen.dart';
import 'screens/admin/time_off_approval_screen.dart';
import 'screens/admin/blocked_dates_screen.dart';
import 'screens/admin/payroll_export_screen.dart';
import 'screens/landing_page.dart';

class AppRoutes {
  // Public routes
  static const String home = '/';

  // Auth routes
  static const String login = '/login';
  static const String passwordReset = '/password-reset';
  static const String changePassword = '/change-password';
  static const String firstAdmin = '/first-admin';
  static const String signup = '/signup';
  static const String completeProfile = '/complete-profile';

  // Super Admin routes
  static const String superAdminDashboard = '/super-admin/dashboard';
  static const String registrationRequests = '/admin/registration-requests';

  // Account Manager routes
  static const String accountManagerDashboard = '/account-manager/dashboard';

  // Admin routes
  static const String adminDashboard = '/admin/dashboard';
  static const String employeeList = '/admin/employees';
  static const String addEmployee = '/admin/employees/add';
  static const String editEmployee = '/admin/employees/edit';
  static const String adminTimeTracking = '/admin/time-tracking';
  static const String scheduleManagement = '/admin/schedules';
  static const String shiftTemplates = '/admin/shift-templates';
  static const String overtimeApprovals = '/admin/overtime-approvals';
  static const String overtimeRiskDashboard = '/admin/overtime-risk';
  static const String timeOffApprovals = '/admin/time-off-approvals';
  static const String blockedDates = '/admin/blocked-dates';
  static const String payrollExport = '/admin/payroll-export';

  // Manager routes
  static const String managerDashboard = '/manager/dashboard';
  static const String teamSchedule = '/manager/schedule';
  static const String managerTimeOffApprovals = '/manager/time-off-approvals';

  // Employee routes
  static const String employeeDashboard = '/employee/dashboard';
  static const String clock = '/employee/clock';
  static const String myTimeEntries = '/employee/time-entries';
  static const String mySchedule = '/employee/schedule';
  static const String myTimeOff = '/employee/time-off';
  static const String requestTimeOff = '/employee/request-time-off';

  // Common routes
  static const String profile = '/profile';
  static const String subscriptionPlans = '/subscription-plans';
  static const String subscriptionManage = '/subscription/manage';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Extract path without query parameters for route matching
    final uri = Uri.parse(settings.name ?? '');
    final path = uri.path;

    switch (path) {
      // Public Routes
      case home:
        return MaterialPageRoute(builder: (_) => const LandingPage());

      // Auth Routes
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case passwordReset:
        return MaterialPageRoute(builder: (_) => const PasswordResetScreen());

      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());

      case completeProfile:
        return MaterialPageRoute(builder: (_) => const CompleteProfileScreen());

      case firstAdmin:
        return MaterialPageRoute(builder: (_) => const FirstAdminScreen());

      case signup:
        return MaterialPageRoute(builder: (_) => const PlanSelectionScreen());

      // Super Admin Routes
      case superAdminDashboard:
        return MaterialPageRoute(builder: (_) => const SuperAdminDashboard());

      case registrationRequests:
        return MaterialPageRoute(builder: (_) => const RegistrationRequestsPage());

      // Account Manager Routes
      case accountManagerDashboard:
        return MaterialPageRoute(builder: (_) => const AccountManagerDashboardScreen());

      // Admin Routes
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());

      case employeeList:
        return MaterialPageRoute(builder: (_) => const EmployeeListScreen());

      case addEmployee:
        return MaterialPageRoute(builder: (_) => const AddEmployeeScreen());

      case editEmployee:
        final employee = settings.arguments as UserModel?;
        if (employee == null) {
          return MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('No employee data provided')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => EditEmployeeScreen(employee: employee),
        );

      case adminTimeTracking:
        return MaterialPageRoute(builder: (_) => const AdminTimeTrackingScreen());

      case scheduleManagement:
        return MaterialPageRoute(builder: (_) => const ScheduleGridScreen());

      case shiftTemplates:
        return MaterialPageRoute(builder: (_) => const ShiftTemplatesScreen());

      case overtimeApprovals:
        return MaterialPageRoute(builder: (_) => const OvertimeApprovalQueueScreen());

      case overtimeRiskDashboard:
        return MaterialPageRoute(builder: (_) => const OvertimeRiskDashboard());

      case timeOffApprovals:
        return MaterialPageRoute(builder: (_) => const TimeOffApprovalScreen());

      case blockedDates:
        return MaterialPageRoute(builder: (_) => const BlockedDatesScreen());

      case payrollExport:
        return MaterialPageRoute(builder: (_) => const PayrollExportScreen());

      // Manager Routes
      case managerDashboard:
        return MaterialPageRoute(builder: (_) => const ManagerDashboard());

      case managerTimeOffApprovals:
        return MaterialPageRoute(builder: (_) => const manager_time_off.TimeOffApprovalScreen());

      // Employee Routes
      case employeeDashboard:
        return MaterialPageRoute(builder: (_) => const EmployeeDashboard());

      case clock:
        return MaterialPageRoute(builder: (_) => const ClockScreen());

      case myTimeEntries:
        return MaterialPageRoute(builder: (_) => const TimeEntriesScreen());

      case mySchedule:
        return MaterialPageRoute(builder: (_) => const MyScheduleScreen());

      case myTimeOff:
        return MaterialPageRoute(builder: (_) => const MyTimeOffScreen());

      case requestTimeOff:
        return MaterialPageRoute(builder: (_) => const RequestTimeOffScreen());

      // Common Routes
      case profile:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Profile - Coming Soon')),
          ),
        );

      case subscriptionPlans:
        return MaterialPageRoute(builder: (_) => const SubscriptionPlansPage());

      // Subscription Management (public, token-based)
      case subscriptionManage:
        // Extract token from query parameters
        final token = uri.queryParameters['token'];

        if (token == null || token.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Invalid Link')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'This link is invalid. Please use the link provided in your email.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) => CustomerSubscriptionManagementScreen(token: token),
        );

      // Default (404)
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
