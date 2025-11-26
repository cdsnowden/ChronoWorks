import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pay_period_model.dart';
import '../models/time_entry_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class PayrollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Overtime multiplier (1.5x for overtime hours)
  static const double overtimeMultiplier = 1.5;

  /// Calculate payroll for a single employee for a pay period
  Future<EmployeePayroll> calculateEmployeePayroll({
    required UserModel employee,
    required PayPeriodModel payPeriod,
  }) async {
    try {
      // Get all time entries for the employee in this pay period
      final timeEntries = await _getTimeEntriesForPeriod(
        userId: employee.id,
        startDate: payPeriod.startDate,
        endDate: payPeriod.endDate,
      );

      // Calculate total hours
      double regularHours = 0.0;
      double overtimeHours = 0.0;

      // Group entries by week to calculate overtime properly
      final weeklyHours = <int, double>{};

      for (final entry in timeEntries) {
        if (entry.clockOutTime == null) continue; // Skip ongoing shifts

        // Get week number for this entry
        final weekNumber = _getWeekNumber(entry.clockInTime);

        // Add hours to weekly total
        weeklyHours[weekNumber] = (weeklyHours[weekNumber] ?? 0.0) + entry.totalHours;
      }

      // Calculate regular and overtime hours
      weeklyHours.forEach((week, hours) {
        if (hours <= AppConstants.overtimeThresholdHours) {
          regularHours += hours;
        } else {
          regularHours += AppConstants.overtimeThresholdHours.toDouble();
          overtimeHours += (hours - AppConstants.overtimeThresholdHours);
        }
      });

      // Calculate pay
      final regularPay = regularHours * employee.hourlyRate;
      final overtimePay = overtimeHours * employee.hourlyRate * overtimeMultiplier;
      final grossPay = regularPay + overtimePay;

      return EmployeePayroll(
        employeeId: employee.id,
        employeeName: employee.fullName,
        payPeriod: payPeriod,
        hourlyRate: employee.hourlyRate,
        regularHours: regularHours,
        overtimeHours: overtimeHours,
        regularPay: regularPay,
        overtimePay: overtimePay,
        grossPay: grossPay,
        timeEntriesCount: timeEntries.length,
      );
    } catch (e) {
      throw Exception('Failed to calculate employee payroll: $e');
    }
  }

  /// Calculate payroll for all employees for a pay period
  Future<PayrollSummary> calculatePayrollForPeriod(PayPeriodModel payPeriod) async {
    try {
      // Get all active employees
      final employeesSnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('isActive', isEqualTo: true)
          .where('role', whereIn: ['employee', 'manager'])
          .get();

      final employees = employeesSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Calculate payroll for each employee
      final List<EmployeePayroll> employeePayrolls = [];

      for (final employee in employees) {
        final payroll = await calculateEmployeePayroll(
          employee: employee,
          payPeriod: payPeriod,
        );
        employeePayrolls.add(payroll);
      }

      // Calculate totals
      double totalRegularHours = 0.0;
      double totalOvertimeHours = 0.0;
      double totalRegularPay = 0.0;
      double totalOvertimePay = 0.0;
      double totalGrossPay = 0.0;

      for (final payroll in employeePayrolls) {
        totalRegularHours += payroll.regularHours;
        totalOvertimeHours += payroll.overtimeHours;
        totalRegularPay += payroll.regularPay;
        totalOvertimePay += payroll.overtimePay;
        totalGrossPay += payroll.grossPay;
      }

      return PayrollSummary(
        payPeriod: payPeriod,
        employeePayrolls: employeePayrolls,
        totalEmployees: employeePayrolls.length,
        totalRegularHours: totalRegularHours,
        totalOvertimeHours: totalOvertimeHours,
        totalRegularPay: totalRegularPay,
        totalOvertimePay: totalOvertimePay,
        totalGrossPay: totalGrossPay,
      );
    } catch (e) {
      throw Exception('Failed to calculate payroll for period: $e');
    }
  }

  /// Export payroll to CSV format
  String exportPayrollToCSV(PayrollSummary payrollSummary) {
    final StringBuffer csv = StringBuffer();

    // Add header
    csv.writeln('Employee Name,Employee ID,Hourly Rate,Regular Hours,Overtime Hours,Regular Pay,Overtime Pay,Gross Pay');

    // Add employee data
    for (final payroll in payrollSummary.employeePayrolls) {
      csv.writeln(
        '${payroll.employeeName},'
        '${payroll.employeeId},'
        '\$${payroll.hourlyRate.toStringAsFixed(2)},'
        '${payroll.regularHours.toStringAsFixed(2)},'
        '${payroll.overtimeHours.toStringAsFixed(2)},'
        '\$${payroll.regularPay.toStringAsFixed(2)},'
        '\$${payroll.overtimePay.toStringAsFixed(2)},'
        '\$${payroll.grossPay.toStringAsFixed(2)}'
      );
    }

    // Add summary row
    csv.writeln();
    csv.writeln(
      'TOTAL,,'
      '-,'
      '${payrollSummary.totalRegularHours.toStringAsFixed(2)},'
      '${payrollSummary.totalOvertimeHours.toStringAsFixed(2)},'
      '\$${payrollSummary.totalRegularPay.toStringAsFixed(2)},'
      '\$${payrollSummary.totalOvertimePay.toStringAsFixed(2)},'
      '\$${payrollSummary.totalGrossPay.toStringAsFixed(2)}'
    );

    return csv.toString();
  }

  /// Get time entries for a specific period
  Future<List<TimeEntryModel>> _getTimeEntriesForPeriod({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .where('userId', isEqualTo: userId)
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate.add(const Duration(days: 1))))
          .orderBy('clockInTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => TimeEntryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get time entries: $e');
    }
  }

  /// Get week number from a date
  int _getWeekNumber(DateTime date) {
    // Calculate week number based on year
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay / 7).floor();
  }

  /// Create and save pay period
  Future<PayPeriodModel> createPayPeriod({
    required DateTime startDate,
    required DateTime endDate,
    required String periodType,
  }) async {
    try {
      final docRef = _firestore.collection(FirebaseCollections.payrollPeriods).doc();

      final payPeriod = PayPeriodModel(
        id: docRef.id,
        startDate: startDate,
        endDate: endDate,
        periodType: periodType,
        createdAt: DateTime.now(),
      );

      await docRef.set(payPeriod.toMap());
      return payPeriod;
    } catch (e) {
      throw Exception('Failed to create pay period: $e');
    }
  }

  /// Mark pay period as processed
  Future<void> markPayPeriodProcessed({
    required String payPeriodId,
    required String processedBy,
  }) async {
    try {
      await _firestore
          .collection(FirebaseCollections.payrollPeriods)
          .doc(payPeriodId)
          .update({
        'isProcessed': true,
        'processedAt': Timestamp.now(),
        'processedBy': processedBy,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to mark pay period as processed: $e');
    }
  }

  /// Get all pay periods
  Future<List<PayPeriodModel>> getAllPayPeriods() async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.payrollPeriods)
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PayPeriodModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pay periods: $e');
    }
  }

  /// Get unprocessed pay periods
  Future<List<PayPeriodModel>> getUnprocessedPayPeriods() async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.payrollPeriods)
          .where('isProcessed', isEqualTo: false)
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PayPeriodModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get unprocessed pay periods: $e');
    }
  }
}

/// Employee payroll calculation result
class EmployeePayroll {
  final String employeeId;
  final String employeeName;
  final PayPeriodModel payPeriod;
  final double hourlyRate;
  final double regularHours;
  final double overtimeHours;
  final double regularPay;
  final double overtimePay;
  final double grossPay;
  final int timeEntriesCount;

  EmployeePayroll({
    required this.employeeId,
    required this.employeeName,
    required this.payPeriod,
    required this.hourlyRate,
    required this.regularHours,
    required this.overtimeHours,
    required this.regularPay,
    required this.overtimePay,
    required this.grossPay,
    required this.timeEntriesCount,
  });

  double get totalHours => regularHours + overtimeHours;

  @override
  String toString() {
    return 'EmployeePayroll($employeeName: \$${grossPay.toStringAsFixed(2)} '
        '[$regularHours reg + $overtimeHours OT hrs])';
  }
}

/// Payroll summary for an entire pay period
class PayrollSummary {
  final PayPeriodModel payPeriod;
  final List<EmployeePayroll> employeePayrolls;
  final int totalEmployees;
  final double totalRegularHours;
  final double totalOvertimeHours;
  final double totalRegularPay;
  final double totalOvertimePay;
  final double totalGrossPay;

  PayrollSummary({
    required this.payPeriod,
    required this.employeePayrolls,
    required this.totalEmployees,
    required this.totalRegularHours,
    required this.totalOvertimeHours,
    required this.totalRegularPay,
    required this.totalOvertimePay,
    required this.totalGrossPay,
  });

  double get totalHours => totalRegularHours + totalOvertimeHours;

  double get averagePayPerEmployee =>
      totalEmployees > 0 ? totalGrossPay / totalEmployees : 0.0;

  @override
  String toString() {
    return 'PayrollSummary(${payPeriod.formattedDateRange}: '
        '\$${totalGrossPay.toStringAsFixed(2)} for $totalEmployees employees)';
  }
}
