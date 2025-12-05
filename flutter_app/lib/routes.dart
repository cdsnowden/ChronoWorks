import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/password_reset_screen.dart';
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
import 'screens/manager/manager_team_reports_screen.dart';
import 'screens/manager/team_pto_screen.dart';
import 'screens/employee/employee_dashboard.dart';
import 'screens/employee/clock_screen.dart';
import 'screens/employee/time_entries_screen.dart';
import 'screens/employee/my_schedule_screen.dart';
import 'screens/employee/face_registration_screen.dart';
import 'screens/employee/employee_personal_reports_screen.dart';
import 'screens/profile/complete_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/employee/request_time_off_screen.dart';
import 'screens/employee/my_time_off_screen.dart';
import 'screens/admin/time_off_approval_screen.dart';
import 'screens/admin/blocked_dates_screen.dart';
import 'screens/admin/payroll_export_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';
import 'screens/admin/pto_policy_screen.dart';
import 'screens/admin/pto_balance_management_screen.dart';
import 'screens/admin/compliance_settings_screen.dart';
import 'screens/super_admin/platform_reports_screen.dart';
import 'screens/super_admin/super_admin_dashboard.dart';
import 'screens/admin/registration_requests_page.dart';
import 'screens/public/register_page.dart';
import 'screens/public/pricing_page.dart';
import 'screens/landing_page.dart';

class AppRoutes {
  // Home route - now goes to login
  static const String home = '/';

  // Auth routes
  static const String login = '/login';
  static const String passwordReset = '/password-reset';
  static const String changePassword = '/change-password';
  static const String completeProfile = '/complete-profile';

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
  static const String adminAnalytics = '/admin/analytics';
  static const String ptoPolicySettings = '/admin/pto-policy';
  static const String ptoBalanceManagement = '/admin/pto-balances';
  static const String complianceSettings = '/admin/compliance-settings';

  // Manager routes
  static const String managerDashboard = '/manager/dashboard';
  static const String teamSchedule = '/manager/schedule';
  static const String managerTimeOffApprovals = '/manager/time-off-approvals';
  static const String managerTeamReports = '/manager/team-reports';
  static const String managerTeamPto = '/manager/team-pto';

  // Super Admin routes
  static const String platformReports = '/super-admin/reports';
  static const String superAdminDashboard = '/super-admin/dashboard';
  static const String registrationRequests = '/super-admin/registration-requests';
  static const String signup = '/signup';
  static const String pricing = '/pricing';

  // Employee routes
  static const String employeeDashboard = '/employee/dashboard';
  static const String clock = '/employee/clock';
  static const String myTimeEntries = '/employee/time-entries';
  static const String mySchedule = '/employee/schedule';
  static const String myTimeOff = '/employee/time-off';
  static const String requestTimeOff = '/employee/request-time-off';
  static const String faceRegistration = '/employee/face-registration';
  static const String employeeReports = '/employee/reports';

  // Common routes
  static const String profile = '/profile';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '');
    final path = uri.path;

    switch (path) {
      // Home Route - Landing Page on web, Login on mobile
      case home:
        if (kIsWeb) {
          return MaterialPageRoute(builder: (_) => const LandingPage());
        }
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      // Auth Routes
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case passwordReset:
        return MaterialPageRoute(builder: (_) => const PasswordResetScreen());

      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());

      case completeProfile:
        return MaterialPageRoute(builder: (_) => const CompleteProfileScreen());

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

      case adminAnalytics:
        return MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen());

      case payrollExport:
        return MaterialPageRoute(builder: (_) => const PayrollExportScreen());

      case ptoPolicySettings:
        return MaterialPageRoute(builder: (_) => const PtoPolicyScreen());

      case ptoBalanceManagement:
        return MaterialPageRoute(builder: (_) => const PtoBalanceManagementScreen());

      case complianceSettings:
        return MaterialPageRoute(builder: (_) => const ComplianceSettingsScreen());

      // Manager Routes
      case managerDashboard:
        return MaterialPageRoute(builder: (_) => const ManagerDashboard());

      case platformReports:
        return MaterialPageRoute(builder: (_) => const PlatformReportsScreen());

      case managerTeamReports:
        return MaterialPageRoute(builder: (_) => const ManagerTeamReportsScreen());

      case managerTeamPto:
        return MaterialPageRoute(builder: (_) => const TeamPtoScreen());

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

      case faceRegistration:
        return MaterialPageRoute(builder: (_) => const FaceRegistrationScreen());

      case employeeReports:
        return MaterialPageRoute(builder: (_) => const EmployeePersonalReportsScreen());


      // Common Routes
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      // Pricing Route
      case pricing:
        return MaterialPageRoute(builder: (_) => const PricingPage());

      // Signup/Register Route
      case signup:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      // Default - redirect to login
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}
