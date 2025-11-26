import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_model.dart';
import '../utils/constants.dart';

class OvertimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Overtime threshold in hours per week
  static const double overtimeThreshold = 40.0;

  /// Get the start of the week (Sunday at 12:00 AM) for a given date
  DateTime getWeekStart(DateTime date) {
    final difference = date.weekday % 7; // Sunday = 0
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: difference));
  }

  /// Get the end of the week (Saturday at 11:59 PM) for a given date
  DateTime getWeekEnd(DateTime date) {
    final weekStart = getWeekStart(date);
    return weekStart.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
  }

  /// Calculate total scheduled hours for an employee in a given week
  Future<double> calculateWeeklyScheduledHours({
    required String employeeId,
    required DateTime weekDate,
    String? excludeShiftId, // Exclude a specific shift (for updates)
  }) async {
    try {
      final weekStart = getWeekStart(weekDate);
      final weekEnd = getWeekEnd(weekDate);

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      double totalHours = 0.0;

      for (final doc in querySnapshot.docs) {
        // Skip the excluded shift if provided (for update scenarios)
        if (excludeShiftId != null && doc.id == excludeShiftId) {
          continue;
        }

        final shift = ShiftModel.fromFirestore(doc);

        // Add shift hours (day offs return 0.0, so won't affect total)
        totalHours += shift.durationHours;
      }

      return totalHours;
    } catch (e) {
      throw Exception('Failed to calculate weekly hours: $e');
    }
  }

  /// Check if adding a new shift would cause overtime
  Future<OvertimeCheckResult> checkScheduleOvertime({
    required String employeeId,
    required DateTime shiftStartTime,
    required DateTime shiftEndTime,
    String? excludeShiftId, // For updates
  }) async {
    try {
      print('DEBUG: checkScheduleOvertime called for employee: $employeeId');
      print('DEBUG: Shift time: $shiftStartTime to $shiftEndTime');

      // Calculate current weekly hours
      final currentWeeklyHours = await calculateWeeklyScheduledHours(
        employeeId: employeeId,
        weekDate: shiftStartTime,
        excludeShiftId: excludeShiftId,
      );

      print('DEBUG: Current weekly hours: $currentWeeklyHours');

      // Calculate new shift hours
      final newShiftHours = shiftEndTime.difference(shiftStartTime).inMinutes / 60.0;

      print('DEBUG: New shift hours: $newShiftHours');

      // Calculate projected total
      final projectedTotal = currentWeeklyHours + newShiftHours;

      // Calculate overtime hours
      final overtimeHours = projectedTotal > overtimeThreshold
          ? projectedTotal - overtimeThreshold
          : 0.0;

      // Determine if this triggers overtime
      final wouldCauseOvertime = projectedTotal > overtimeThreshold;

      print('DEBUG: Overtime check result - projected: $projectedTotal, overtime: $wouldCauseOvertime');

      return OvertimeCheckResult(
        currentWeeklyHours: currentWeeklyHours,
        newShiftHours: newShiftHours,
        projectedTotalHours: projectedTotal,
        overtimeHours: overtimeHours,
        wouldCauseOvertime: wouldCauseOvertime,
        weekStartDate: getWeekStart(shiftStartTime),
        weekEndDate: getWeekEnd(shiftStartTime),
      );
    } catch (e, stackTrace) {
      print('DEBUG: Error in checkScheduleOvertime: $e');
      print('DEBUG: Stack trace: $stackTrace');
      throw Exception('Failed to check schedule overtime: $e');
    }
  }

  /// Get weekly hours summary for an employee
  Future<WeeklyHoursSummary> getWeeklyHoursSummary({
    required String employeeId,
    required DateTime weekDate,
  }) async {
    try {
      final weekStart = getWeekStart(weekDate);
      final weekEnd = getWeekEnd(weekDate);

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      double totalHours = 0.0;
      int shiftCount = 0;
      int dayOffCount = 0;
      double paidDayOffHours = 0.0;

      for (final doc in querySnapshot.docs) {
        final shift = ShiftModel.fromFirestore(doc);

        if (shift.isDayOff) {
          dayOffCount++;
          if (shift.paidHours != null) {
            paidDayOffHours += shift.paidHours!;
          }
        } else {
          shiftCount++;
          totalHours += shift.durationHours;
        }
      }

      final isOvertime = totalHours > overtimeThreshold;
      final overtimeHours = isOvertime ? totalHours - overtimeThreshold : 0.0;

      return WeeklyHoursSummary(
        employeeId: employeeId,
        weekStartDate: weekStart,
        weekEndDate: weekEnd,
        totalScheduledHours: totalHours,
        shiftCount: shiftCount,
        dayOffCount: dayOffCount,
        paidDayOffHours: paidDayOffHours,
        isOvertime: isOvertime,
        overtimeHours: overtimeHours,
      );
    } catch (e) {
      throw Exception('Failed to get weekly hours summary: $e');
    }
  }

  /// Check if an employee is at risk of overtime this week
  Future<bool> isOvertimeRisk({
    required String employeeId,
    required DateTime date,
  }) async {
    final weeklyHours = await calculateWeeklyScheduledHours(
      employeeId: employeeId,
      weekDate: date,
    );
    return weeklyHours >= overtimeThreshold;
  }

  /// Get employees who are currently over or near overtime (> 35 hours)
  /// Note: This method should be called with a list of employee IDs from the company
  /// to ensure proper multi-tenancy isolation
  Future<List<OvertimeAlert>> getOvertimeAlerts({
    required DateTime weekDate,
    required List<String> employeeIds,
  }) async {
    try {
      if (employeeIds.isEmpty) {
        return [];
      }

      final weekStart = getWeekStart(weekDate);
      final weekEnd = getWeekEnd(weekDate);

      // Group by employee and calculate hours
      final Map<String, double> employeeHours = {};
      final Map<String, String> employeeNames = {};

      // Process employees in batches of 10 (Firestore whereIn limit)
      for (int i = 0; i < employeeIds.length; i += 10) {
        final batch = employeeIds.skip(i).take(10).toList();

        // Get all shifts for the week for this batch of employees
        final querySnapshot = await _firestore
            .collection(FirebaseCollections.shifts)
            .where('employeeId', whereIn: batch)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
            .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
            .get();

        for (final doc in querySnapshot.docs) {
          final shift = ShiftModel.fromFirestore(doc);

          employeeHours[shift.employeeId] = (employeeHours[shift.employeeId] ?? 0.0) + shift.durationHours;

          // Store employee name if we don't have it yet
          if (!employeeNames.containsKey(shift.employeeId)) {
            // We'll need to get employee name from another source
            // For now, use employeeId as placeholder
            employeeNames[shift.employeeId] = shift.employeeId;
          }
        }
      }

      // Filter and create alerts for employees with >= 35 hours (near or over overtime)
      final List<OvertimeAlert> alerts = [];

      employeeHours.forEach((employeeId, hours) {
        if (hours >= 35.0) {
          final isOvertime = hours > overtimeThreshold;
          final severity = hours > overtimeThreshold
              ? OvertimeSeverity.critical
              : hours >= 38.0
                  ? OvertimeSeverity.warning
                  : OvertimeSeverity.info;

          alerts.add(OvertimeAlert(
            employeeId: employeeId,
            employeeName: employeeNames[employeeId]!,
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            totalHours: hours,
            isOvertime: isOvertime,
            overtimeHours: isOvertime ? hours - overtimeThreshold : 0.0,
            severity: severity,
          ));
        }
      });

      // Sort by total hours descending
      alerts.sort((a, b) => b.totalHours.compareTo(a.totalHours));

      return alerts;
    } catch (e) {
      throw Exception('Failed to get overtime alerts: $e');
    }
  }
}

/// Result of overtime check when creating/updating schedules
class OvertimeCheckResult {
  final double currentWeeklyHours;
  final double newShiftHours;
  final double projectedTotalHours;
  final double overtimeHours;
  final bool wouldCauseOvertime;
  final DateTime weekStartDate;
  final DateTime weekEndDate;

  OvertimeCheckResult({
    required this.currentWeeklyHours,
    required this.newShiftHours,
    required this.projectedTotalHours,
    required this.overtimeHours,
    required this.wouldCauseOvertime,
    required this.weekStartDate,
    required this.weekEndDate,
  });

  @override
  String toString() {
    return 'OvertimeCheck(current: ${currentWeeklyHours.toStringAsFixed(1)}h, '
        'new: ${newShiftHours.toStringAsFixed(1)}h, '
        'projected: ${projectedTotalHours.toStringAsFixed(1)}h, '
        'overtime: ${wouldCauseOvertime ? 'YES' : 'NO'})';
  }
}

/// Weekly hours summary for an employee
class WeeklyHoursSummary {
  final String employeeId;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final double totalScheduledHours;
  final int shiftCount;
  final int dayOffCount;
  final double paidDayOffHours;
  final bool isOvertime;
  final double overtimeHours;

  WeeklyHoursSummary({
    required this.employeeId,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.totalScheduledHours,
    required this.shiftCount,
    required this.dayOffCount,
    required this.paidDayOffHours,
    required this.isOvertime,
    required this.overtimeHours,
  });
}

/// Overtime alert for dashboard/monitoring
class OvertimeAlert {
  final String employeeId;
  final String employeeName;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final double totalHours;
  final bool isOvertime;
  final double overtimeHours;
  final OvertimeSeverity severity;

  OvertimeAlert({
    required this.employeeId,
    required this.employeeName,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.totalHours,
    required this.isOvertime,
    required this.overtimeHours,
    required this.severity,
  });
}

/// Severity level for overtime alerts
enum OvertimeSeverity {
  info,     // 35-37.9 hours (approaching)
  warning,  // 38-40 hours (close to threshold)
  critical, // >40 hours (overtime)
}
