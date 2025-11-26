import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee_payroll_summary.dart';
import '../models/user_model.dart';
import '../models/time_entry_model.dart';
import '../models/time_off_request_model.dart';
import '../models/pay_period_model.dart';
import '../utils/constants.dart';

class PayrollExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Standard workweek hours for overtime calculation
  static const double standardWeekHours = 40.0;
  static const double overtimeMultiplier = 1.5;
  static const double standardDailyHours = 8.0; // For PTO calculation

  /// Generate payroll summary for all employees in a company for a given pay period
  Future<List<EmployeePayrollSummary>> generatePayrollReport({
    required String companyId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      // Get all active employees for the company
      final employeesSnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final employees = employeesSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      final List<EmployeePayrollSummary> summaries = [];

      for (final employee in employees) {
        final summary = await _generateEmployeeSummary(
          employee: employee,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
        summaries.add(summary);
      }

      // Sort by employee name
      summaries.sort((a, b) => a.employeeName.compareTo(b.employeeName));

      return summaries;
    } catch (e) {
      throw Exception('Failed to generate payroll report: $e');
    }
  }

  /// Generate payroll summary for a single employee
  Future<EmployeePayrollSummary> _generateEmployeeSummary({
    required UserModel employee,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    // Get all time entries for the period
    final timeEntries = await _getTimeEntriesForPeriod(
      employeeId: employee.id,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    // Get approved time off for the period
    final timeOffRequests = await _getApprovedTimeOffForPeriod(
      employeeId: employee.id,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    // Calculate hours worked
    final hoursData = _calculateHours(timeEntries);
    final regularHours = hoursData['regular']!;
    final overtimeHours = hoursData['overtime']!;
    final totalHours = regularHours + overtimeHours;

    // Calculate PTO
    final ptoData = _calculatePTO(timeOffRequests, periodStart, periodEnd);
    final paidDays = ptoData['paidDays']!.toInt();
    final unpaidDays = ptoData['unpaidDays']!.toInt();
    final paidHours = paidDays * standardDailyHours;

    // Calculate pay
    final regularPay = regularHours * employee.hourlyRate;
    final overtimePay = overtimeHours * employee.hourlyRate * overtimeMultiplier;
    final ptoPay = paidHours * employee.hourlyRate;
    final grossPay = regularPay + overtimePay + ptoPay;

    return EmployeePayrollSummary(
      employeeId: employee.id,
      employeeName: employee.fullName,
      employeeEmail: employee.email,
      hourlyRate: employee.hourlyRate,
      employmentType: employee.employmentType,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      totalHours: totalHours,
      paidTimeOffDays: paidDays,
      unpaidTimeOffDays: unpaidDays,
      paidTimeOffHours: paidHours,
      regularPay: regularPay,
      overtimePay: overtimePay,
      paidTimeOffPay: ptoPay,
      grossPay: grossPay,
      periodStart: periodStart,
      periodEnd: periodEnd,
      totalShifts: timeEntries.length,
    );
  }

  /// Get time entries for an employee within a pay period
  Future<List<TimeEntryModel>> _getTimeEntriesForPeriod({
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      // Normalize dates to start/end of day
      final startOfPeriod = DateTime(periodStart.year, periodStart.month, periodStart.day);
      final endOfPeriod = DateTime(periodEnd.year, periodEnd.month, periodEnd.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .where('userId', isEqualTo: employeeId)
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfPeriod))
          .get();

      return querySnapshot.docs
          .map((doc) => TimeEntryModel.fromFirestore(doc))
          .where((entry) => entry.clockOutTime != null) // Only completed entries
          .toList();
    } catch (e) {
      // If query fails, fetch all and filter (no index issue)
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .where('userId', isEqualTo: employeeId)
          .get();

      final startOfPeriod = DateTime(periodStart.year, periodStart.month, periodStart.day);
      final endOfPeriod = DateTime(periodEnd.year, periodEnd.month, periodEnd.day, 23, 59, 59);

      return querySnapshot.docs
          .map((doc) => TimeEntryModel.fromFirestore(doc))
          .where((entry) =>
              entry.clockOutTime != null &&
              entry.clockInTime.isAfter(startOfPeriod.subtract(const Duration(seconds: 1))) &&
              entry.clockInTime.isBefore(endOfPeriod.add(const Duration(seconds: 1))))
          .toList();
    }
  }

  /// Get approved time off requests for an employee within a pay period
  Future<List<TimeOffRequestModel>> _getApprovedTimeOffForPeriod({
    required String employeeId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: 'approved')
          .get();

      // Filter for requests that overlap with the pay period
      return querySnapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .where((request) {
            // Check if request overlaps with pay period
            return request.startDate.isBefore(periodEnd.add(const Duration(days: 1))) &&
                   request.endDate.isAfter(periodStart.subtract(const Duration(days: 1)));
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to get time off requests: $e');
    }
  }

  /// Calculate regular and overtime hours from time entries
  Map<String, double> _calculateHours(List<TimeEntryModel> timeEntries) {
    double calculatedTotalHours = 0.0;

    // Calculate total hours from all entries
    for (final entry in timeEntries) {
      calculatedTotalHours += entry.totalHours;
    }

    // Calculate overtime (hours over 40 per week)
    // For simplicity, we're treating the entire period as one calculation
    // In a real system, you'd calculate weekly totals separately
    double regularHours = calculatedTotalHours;
    double overtimeHours = 0.0;

    if (calculatedTotalHours > standardWeekHours) {
      regularHours = standardWeekHours;
      overtimeHours = calculatedTotalHours - standardWeekHours;
    }

    return {
      'regular': regularHours,
      'overtime': overtimeHours,
    };
  }

  /// Calculate paid and unpaid time off days
  Map<String, double> _calculatePTO(
    List<TimeOffRequestModel> timeOffRequests,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    int paidDays = 0;
    int unpaidDays = 0;

    for (final request in timeOffRequests) {
      // Calculate overlap days with the pay period
      final requestStart = request.startDate.isAfter(periodStart)
          ? request.startDate
          : periodStart;

      final requestEnd = request.endDate.isBefore(periodEnd)
          ? request.endDate
          : periodEnd;

      final daysInPeriod = requestEnd.difference(requestStart).inDays + 1;

      if (request.type == 'paid') {
        paidDays += daysInPeriod;
      } else if (request.type == 'unpaid') {
        unpaidDays += daysInPeriod;
      }
    }

    return {
      'paidDays': paidDays.toDouble(),
      'unpaidDays': unpaidDays.toDouble(),
    };
  }

  /// Generate CSV string from payroll summaries
  String generateCSV(List<EmployeePayrollSummary> summaries) {
    final List<String> csvLines = [];

    // Add header
    csvLines.add(EmployeePayrollSummary.csvHeaders.join(','));

    // Add data rows
    for (final summary in summaries) {
      csvLines.add(summary.toCsvRow().map((field) => _escapeCsvField(field)).join(','));
    }

    return csvLines.join('\n');
  }

  /// Escape CSV field (handle commas, quotes, newlines)
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Generate summary totals
  Map<String, double> calculateTotals(List<EmployeePayrollSummary> summaries) {
    double totalRegularHours = 0;
    double totalOvertimeHours = 0;
    double totalHours = 0;
    double totalRegularPay = 0;
    double totalOvertimePay = 0;
    double totalPTOPay = 0;
    double totalGrossPay = 0;
    int totalEmployees = summaries.length;

    for (final summary in summaries) {
      totalRegularHours += summary.regularHours;
      totalOvertimeHours += summary.overtimeHours;
      totalHours += summary.totalHours;
      totalRegularPay += summary.regularPay;
      totalOvertimePay += summary.overtimePay;
      totalPTOPay += summary.paidTimeOffPay;
      totalGrossPay += summary.grossPay;
    }

    return {
      'totalRegularHours': totalRegularHours,
      'totalOvertimeHours': totalOvertimeHours,
      'totalHours': totalHours,
      'totalRegularPay': totalRegularPay,
      'totalOvertimePay': totalOvertimePay,
      'totalPTOPay': totalPTOPay,
      'totalGrossPay': totalGrossPay,
      'totalEmployees': totalEmployees.toDouble(),
    };
  }
}
