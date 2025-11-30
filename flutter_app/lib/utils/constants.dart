class AppConstants {
  // App Info
  static const String appName = 'ChronoWorks';
  static const String appVersion = '1.1.0';

  // Business Rules
  static const int overtimeThresholdHours = 40; // hours per week
  static const int breakEntitlementMinutes = 60; // 1 hour per shift
  static const int geofenceRadiusMeters = 50; // 50 meters (164 feet)
  static const double faceMatchConfidenceThreshold = 85.0; // 85% minimum

  // Break Compliance Rules
  static const double hoursBeforeBreakRequired = 6.0; // Break required after 6 hours
  static const int minimumBreakMinutes = 30; // Minimum 30-minute break
  static const int breakWarningThresholdMinutes = 30; // Warn if no break in 5.5 hours

  // Week Definition
  static const int weekStartDay = 0; // Sunday = 0

  // Time Formats
  static const String dateFormat = 'MMM dd, yyyy';
  static const String timeFormat = 'h:mm a';
  static const String dateTimeFormat = 'MMM dd, yyyy h:mm a';

  // Validation
  static const int minPasswordLength = 8;
  static const int maxBreakSessionsPerDay = 5;

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 5);
}

class FirebaseCollections {
  static const String users = 'users';
  static const String shifts = 'shifts';
  static const String shiftTemplates = 'shiftTemplates';
  static const String schedules = 'schedules';
  static const String scheduleTemplates = 'scheduleTemplates';
  static const String timeEntries = 'timeEntries';
  static const String breakEntries = 'breakEntries';
  static const String activeClockIns = 'activeClockIns';
  static const String weeklyHours = 'weeklyHours';
  static const String overtimeRequests = 'overtimeRequests';
  static const String substitutionSuggestions = 'substitutionSuggestions';
  static const String weeklyBreakStats = 'weeklyBreakStats';
  static const String employeeBreakProfiles = 'employeeBreakProfiles';
  static const String payrollPeriods = 'payrollPeriods';
  static const String emailLogs = 'emailLogs';
  static const String timeOffRequests = 'timeOffRequests';
  static const String shiftSwapRequests = 'shiftSwapRequests';
  static const String offPremisesAlerts = 'offPremisesAlerts';
  static const String ptoPolicies = 'ptoPolicies';
  static const String ptoBalances = 'ptoBalances';
}

class UserRoles {
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String employee = 'employee';
}

class EmploymentTypes {
  static const String fullTime = 'full-time';
  static const String partTime = 'part-time';
}
