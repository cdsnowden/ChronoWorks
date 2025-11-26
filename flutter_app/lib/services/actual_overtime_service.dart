import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/time_entry_model.dart';
import '../models/shift_model.dart';
import '../models/break_entry_model.dart';
import '../services/break_service.dart';
import '../utils/constants.dart';

/// Service for monitoring actual time worked vs scheduled time
/// and predicting overtime based on employee behavior
class ActualOvertimeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BreakService _breakService = BreakService();

  // Thresholds
  static const double overtimeThreshold = 40.0; // hours per week
  static const int earlyClockInThresholdMinutes = 10; // Early by 10+ minutes
  static const int lateClockOutThresholdMinutes = 10; // Late by 10+ minutes
  static const int fullBreakMinutes = 30; // Expected break duration

  /// Get the start of the week (Sunday at 12:00 AM)
  DateTime getWeekStart(DateTime date) {
    final difference = date.weekday % 7;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: difference));
  }

  /// Get the end of the week (Saturday at 11:59 PM)
  DateTime getWeekEnd(DateTime date) {
    final weekStart = getWeekStart(date);
    return weekStart.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
  }

  /// Calculate actual hours worked this week from completed time entries
  Future<double> calculateActualWeeklyHours({
    required String employeeId,
    required DateTime weekDate,
  }) async {
    try {
      final weekStart = getWeekStart(weekDate);
      final weekEnd = getWeekEnd(weekDate);

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .where('userId', isEqualTo: employeeId)
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      double totalHours = 0.0;

      for (final doc in querySnapshot.docs) {
        final timeEntry = TimeEntryModel.fromFirestore(doc);

        // Only count completed entries (with clock out time)
        if (timeEntry.clockOutTime != null) {
          // Get break time for this entry
          final breakMinutes = await _getBreakMinutesForEntry(timeEntry.id);

          // Calculate work hours = total time - break time
          final totalMinutes = timeEntry.clockOutTime!.difference(timeEntry.clockInTime).inMinutes;
          final workMinutes = totalMinutes - breakMinutes;

          totalHours += workMinutes / 60.0;
        }
      }

      return totalHours;
    } catch (e) {
      throw Exception('Failed to calculate actual weekly hours: $e');
    }
  }

  /// Get total break minutes for a time entry
  Future<double> _getBreakMinutesForEntry(String timeEntryId) async {
    try {
      final breakQuery = await _firestore
          .collection(FirebaseCollections.breakEntries)
          .where('timeEntryId', isEqualTo: timeEntryId)
          .get();

      double totalBreakMinutes = 0.0;

      for (final doc in breakQuery.docs) {
        final breakEntry = BreakEntryModel.fromFirestore(doc);
        if (breakEntry.breakEndTime != null) {
          totalBreakMinutes += breakEntry.durationMinutes;
        }
      }

      return totalBreakMinutes;
    } catch (e) {
      return 0.0;
    }
  }

  /// Calculate remaining scheduled hours for the week
  Future<double> calculateRemainingScheduledHours({
    required String employeeId,
    required DateTime weekDate,
  }) async {
    try {
      final now = DateTime.now();
      final weekEnd = getWeekEnd(weekDate);

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .where('isDayOff', isEqualTo: false)
          .get();

      double remainingHours = 0.0;

      for (final doc in querySnapshot.docs) {
        final shift = ShiftModel.fromFirestore(doc);
        remainingHours += shift.durationHours;
      }

      return remainingHours;
    } catch (e) {
      throw Exception('Failed to calculate remaining scheduled hours: $e');
    }
  }

  /// Check if employee is currently clocked in
  Future<TimeEntryModel?> getCurrentActiveEntry(String employeeId) async {
    try {
      final activeDoc = await _firestore
          .collection(FirebaseCollections.activeClockIns)
          .doc(employeeId)
          .get();

      if (!activeDoc.exists) return null;

      final timeEntryId = activeDoc.data()!['timeEntryId'] as String;

      final timeEntryDoc = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .doc(timeEntryId)
          .get();

      if (!timeEntryDoc.exists) return null;

      return TimeEntryModel.fromFirestore(timeEntryDoc);
    } catch (e) {
      return null;
    }
  }

  /// Analyze current overtime risk for an employee
  Future<OvertimeRiskAnalysis> analyzeOvertimeRisk({
    required String employeeId,
    required DateTime date,
  }) async {
    try {
      // 1. Get actual hours worked so far this week
      final actualHoursWorked = await calculateActualWeeklyHours(
        employeeId: employeeId,
        weekDate: date,
      );

      // 2. Get remaining scheduled hours
      final remainingScheduled = await calculateRemainingScheduledHours(
        employeeId: employeeId,
        weekDate: date,
      );

      // 3. Check if currently clocked in
      final activeEntry = await getCurrentActiveEntry(employeeId);

      // 4. Calculate projected hours if currently active
      double currentShiftProjectedHours = 0.0;
      if (activeEntry != null) {
        currentShiftProjectedHours = await _projectCurrentShiftHours(
          employeeId: employeeId,
          activeEntry: activeEntry,
        );
      }

      // 5. Calculate total projected hours
      final projectedTotal = actualHoursWorked + currentShiftProjectedHours + remainingScheduled;

      // 6. Determine risk level
      final riskLevel = _calculateRiskLevel(projectedTotal);

      // 7. Get behavior violations (early clock-in, late clock-out, short breaks)
      final violations = await _analyzeWeeklyViolations(employeeId, date);

      // 8. Generate remediation strategies
      final strategies = await _generateRemediationStrategies(
        employeeId: employeeId,
        actualHours: actualHoursWorked,
        projectedTotal: projectedTotal,
        violations: violations,
        date: date,
      );

      return OvertimeRiskAnalysis(
        employeeId: employeeId,
        weekStartDate: getWeekStart(date),
        weekEndDate: getWeekEnd(date),
        actualHoursWorked: actualHoursWorked,
        currentShiftProjectedHours: currentShiftProjectedHours,
        remainingScheduledHours: remainingScheduled,
        projectedTotalHours: projectedTotal,
        overtimeHours: projectedTotal > overtimeThreshold ? projectedTotal - overtimeThreshold : 0.0,
        riskLevel: riskLevel,
        isCurrentlyActive: activeEntry != null,
        violations: violations,
        remediationStrategies: strategies,
      );
    } catch (e) {
      throw Exception('Failed to analyze overtime risk: $e');
    }
  }

  /// Project hours for currently active shift
  Future<double> _projectCurrentShiftHours({
    required String employeeId,
    required TimeEntryModel activeEntry,
  }) async {
    try {
      // Get the scheduled shift for today
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final shiftQuery = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('startTime', isLessThan: Timestamp.fromDate(todayEnd))
          .where('isDayOff', isEqualTo: false)
          .limit(1)
          .get();

      if (shiftQuery.docs.isEmpty) {
        // No scheduled shift, project to current time
        final breakMinutes = await _getBreakMinutesForEntry(activeEntry.id);
        final workMinutes = now.difference(activeEntry.clockInTime).inMinutes - breakMinutes;
        return workMinutes / 60.0;
      }

      final shift = ShiftModel.fromFirestore(shiftQuery.docs.first);

      // Project to scheduled end time (or current time if past scheduled end)
      final projectedEndTime = shift.endTime!.isBefore(now) ? now : shift.endTime!;

      // Calculate projected work time minus breaks
      final breakMinutes = await _getBreakMinutesForEntry(activeEntry.id);
      final projectedMinutes = projectedEndTime.difference(activeEntry.clockInTime).inMinutes;
      final projectedWorkMinutes = projectedMinutes - breakMinutes;

      return projectedWorkMinutes / 60.0;
    } catch (e) {
      // Default to current elapsed time
      final breakMinutes = await _getBreakMinutesForEntry(activeEntry.id);
      final workMinutes = DateTime.now().difference(activeEntry.clockInTime).inMinutes - breakMinutes;
      return workMinutes / 60.0;
    }
  }

  /// Calculate risk level based on projected hours
  OvertimeRiskLevel _calculateRiskLevel(double projectedHours) {
    if (projectedHours >= overtimeThreshold) {
      return OvertimeRiskLevel.critical; // Already at/over overtime
    } else if (projectedHours >= 38.0) {
      return OvertimeRiskLevel.high; // 38-39.99 hours
    } else if (projectedHours >= 35.0) {
      return OvertimeRiskLevel.medium; // 35-37.99 hours
    } else {
      return OvertimeRiskLevel.low; // Under 35 hours
    }
  }

  /// Analyze weekly violations (early clock-ins, late clock-outs, short breaks)
  Future<List<TimeViolation>> _analyzeWeeklyViolations(
    String employeeId,
    DateTime weekDate,
  ) async {
    try {
      final weekStart = getWeekStart(weekDate);
      final weekEnd = getWeekEnd(weekDate);

      final timeEntries = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .where('userId', isEqualTo: employeeId)
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      final List<TimeViolation> violations = [];

      for (final doc in timeEntries.docs) {
        final timeEntry = TimeEntryModel.fromFirestore(doc);

        // Get corresponding shift for this time entry
        final shift = await _getShiftForTimeEntry(timeEntry);

        if (shift != null) {
          // Check for early clock-in
          final earlyMinutes = shift.startTime!.difference(timeEntry.clockInTime).inMinutes;
          if (earlyMinutes >= earlyClockInThresholdMinutes) {
            violations.add(TimeViolation(
              type: ViolationType.earlyClockIn,
              date: timeEntry.clockInTime,
              minutesDifference: earlyMinutes,
              description: 'Clocked in $earlyMinutes minutes early',
            ));
          }

          // Check for late clock-out
          if (timeEntry.clockOutTime != null && shift.endTime != null) {
            final lateMinutes = timeEntry.clockOutTime!.difference(shift.endTime!).inMinutes;
            if (lateMinutes >= lateClockOutThresholdMinutes) {
              violations.add(TimeViolation(
                type: ViolationType.lateClockOut,
                date: timeEntry.clockOutTime!,
                minutesDifference: lateMinutes,
                description: 'Clocked out $lateMinutes minutes late',
              ));
            }
          }

          // Check for short/missing break
          if (timeEntry.clockOutTime != null) {
            final shiftDuration = timeEntry.clockOutTime!.difference(timeEntry.clockInTime).inHours;
            if (shiftDuration >= 6.0) {
              // Shifts over 6 hours should have a break
              final breakMinutes = await _getBreakMinutesForEntry(timeEntry.id);
              if (breakMinutes < fullBreakMinutes) {
                violations.add(TimeViolation(
                  type: ViolationType.shortBreak,
                  date: timeEntry.clockInTime,
                  minutesDifference: fullBreakMinutes - breakMinutes.round(),
                  description: 'Break was ${fullBreakMinutes - breakMinutes.round()} minutes short',
                ));
              }
            }
          }
        }
      }

      return violations;
    } catch (e) {
      return [];
    }
  }

  /// Get the scheduled shift that corresponds to a time entry
  Future<ShiftModel?> _getShiftForTimeEntry(TimeEntryModel timeEntry) async {
    try {
      final entryDate = timeEntry.clockInTime;
      final dayStart = DateTime(entryDate.year, entryDate.month, entryDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final shiftQuery = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: timeEntry.userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('startTime', isLessThan: Timestamp.fromDate(dayEnd))
          .where('isDayOff', isEqualTo: false)
          .limit(1)
          .get();

      if (shiftQuery.docs.isEmpty) return null;

      return ShiftModel.fromFirestore(shiftQuery.docs.first);
    } catch (e) {
      return null;
    }
  }

  /// Generate remediation strategies
  Future<List<RemediationStrategy>> _generateRemediationStrategies({
    required String employeeId,
    required double actualHours,
    required double projectedTotal,
    required List<TimeViolation> violations,
    required DateTime date,
  }) async {
    final strategies = <RemediationStrategy>[];

    // Only generate strategies if at risk
    if (projectedTotal < 35.0) return strategies;

    final overtimeAmount = projectedTotal - overtimeThreshold;

    // Strategy 1: Clock in/out on time
    final behaviorViolationMinutes = violations.fold<int>(
      0,
      (sum, v) => sum + (v.type != ViolationType.shortBreak ? v.minutesDifference : 0),
    );

    if (behaviorViolationMinutes > 0) {
      strategies.add(RemediationStrategy(
        type: StrategyType.clockOnTime,
        description: 'Clock in and out at scheduled times',
        potentialHoursSaved: behaviorViolationMinutes / 60.0,
        priority: 1,
        details: 'You have clocked in early or out late ${behaviorViolationMinutes} minutes this week. '
            'Following your exact schedule would save ${(behaviorViolationMinutes / 60.0).toStringAsFixed(1)} hours.',
      ));
    }

    // Strategy 2: Take full breaks
    final missedBreakMinutes = violations
        .where((v) => v.type == ViolationType.shortBreak)
        .fold<int>(0, (sum, v) => sum + v.minutesDifference);

    if (missedBreakMinutes > 0) {
      strategies.add(RemediationStrategy(
        type: StrategyType.takeFullBreaks,
        description: 'Take your full break periods',
        potentialHoursSaved: missedBreakMinutes / 60.0,
        priority: 2,
        details: 'You have missed ${missedBreakMinutes} minutes of break time this week. '
            'Taking full breaks would reduce your hours by ${(missedBreakMinutes / 60.0).toStringAsFixed(1)} hours.',
      ));
    }

    // Strategy 3: Shift swap if still over after other strategies
    final hoursSavedFromBehavior = (behaviorViolationMinutes + missedBreakMinutes) / 60.0;
    if (projectedTotal - hoursSavedFromBehavior >= overtimeThreshold) {
      final swapCandidates = await _findShiftSwapCandidates(
        employeeId: employeeId,
        weekDate: date,
        hoursNeeded: overtimeAmount - hoursSavedFromBehavior,
      );

      if (swapCandidates.isNotEmpty) {
        strategies.add(RemediationStrategy(
          type: StrategyType.shiftSwap,
          description: 'Swap shifts with an available employee',
          potentialHoursSaved: swapCandidates.first.shiftHours,
          priority: 3,
          details: 'Found ${swapCandidates.length} potential shift swap candidate(s). '
              'Swapping would save ${swapCandidates.first.shiftHours.toStringAsFixed(1)} hours.',
          swapCandidates: swapCandidates,
        ));
      }
    }

    return strategies;
  }

  /// Find potential shift swap candidates
  Future<List<ShiftSwapCandidate>> _findShiftSwapCandidates({
    required String employeeId,
    required DateTime weekDate,
    required double hoursNeeded,
  }) async {
    try {
      final weekStart = getWeekStart(weekDate);
      final weekEnd = getWeekEnd(weekDate);

      // Get all remaining shifts for this employee
      final now = DateTime.now();
      final employeeShiftsQuery = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .where('isDayOff', isEqualTo: false)
          .get();

      final List<ShiftSwapCandidate> candidates = [];

      // For each shift, find employees who could take it
      for (final shiftDoc in employeeShiftsQuery.docs) {
        final shift = ShiftModel.fromFirestore(shiftDoc);

        // Get all employees
        final usersQuery = await _firestore
            .collection(FirebaseCollections.users)
            .where('role', isEqualTo: 'employee')
            .get();

        for (final userDoc in usersQuery.docs) {
          final candidateId = userDoc.id;

          // Skip self
          if (candidateId == employeeId) continue;

          // Check if candidate would be under overtime after taking this shift
          final candidateProjected = await calculateActualWeeklyHours(
            employeeId: candidateId,
            weekDate: weekDate,
          );

          final candidateRemaining = await calculateRemainingScheduledHours(
            employeeId: candidateId,
            weekDate: weekDate,
          );

          final candidateTotalWithShift = candidateProjected + candidateRemaining + shift.durationHours;

          // Only suggest if candidate would still be under overtime
          if (candidateTotalWithShift <= overtimeThreshold) {
            candidates.add(ShiftSwapCandidate(
              candidateId: candidateId,
              candidateName: userDoc.data()['fullName'] ?? 'Unknown',
              shiftId: shift.id,
              shiftDate: shift.startTime!,
              shiftHours: shift.durationHours,
              candidateCurrentHours: candidateProjected + candidateRemaining,
              candidateHoursAfterSwap: candidateTotalWithShift,
            ));
          }
        }
      }

      // Sort by candidates with most available capacity
      candidates.sort((a, b) => a.candidateCurrentHours.compareTo(b.candidateCurrentHours));

      return candidates;
    } catch (e) {
      return [];
    }
  }

  /// Get all employees at risk of overtime
  Future<List<String>> getEmployeesAtRisk(DateTime weekDate) async {
    try {
      // Get all employees
      final usersQuery = await _firestore
          .collection(FirebaseCollections.users)
          .where('role', isEqualTo: 'employee')
          .get();

      final atRisk = <String>[];

      for (final userDoc in usersQuery.docs) {
        final analysis = await analyzeOvertimeRisk(
          employeeId: userDoc.id,
          date: weekDate,
        );

        if (analysis.riskLevel != OvertimeRiskLevel.low) {
          atRisk.add(userDoc.id);
        }
      }

      return atRisk;
    } catch (e) {
      return [];
    }
  }
}

/// Result of overtime risk analysis
class OvertimeRiskAnalysis {
  final String employeeId;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final double actualHoursWorked;
  final double currentShiftProjectedHours;
  final double remainingScheduledHours;
  final double projectedTotalHours;
  final double overtimeHours;
  final OvertimeRiskLevel riskLevel;
  final bool isCurrentlyActive;
  final List<TimeViolation> violations;
  final List<RemediationStrategy> remediationStrategies;

  OvertimeRiskAnalysis({
    required this.employeeId,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.actualHoursWorked,
    required this.currentShiftProjectedHours,
    required this.remainingScheduledHours,
    required this.projectedTotalHours,
    required this.overtimeHours,
    required this.riskLevel,
    required this.isCurrentlyActive,
    required this.violations,
    required this.remediationStrategies,
  });

  String get riskLevelText {
    switch (riskLevel) {
      case OvertimeRiskLevel.critical:
        return 'Critical - Overtime Imminent';
      case OvertimeRiskLevel.high:
        return 'High Risk';
      case OvertimeRiskLevel.medium:
        return 'Moderate Risk';
      case OvertimeRiskLevel.low:
        return 'Low Risk';
    }
  }

  @override
  String toString() {
    return 'OvertimeRiskAnalysis(employee: $employeeId, projected: ${projectedTotalHours.toStringAsFixed(1)}h, risk: $riskLevelText)';
  }
}

/// Overtime risk levels
enum OvertimeRiskLevel {
  low,      // < 35 hours
  medium,   // 35-37.99 hours
  high,     // 38-39.99 hours
  critical, // >= 40 hours
}

/// Time violation (early clock-in, late clock-out, short break)
class TimeViolation {
  final ViolationType type;
  final DateTime date;
  final int minutesDifference;
  final String description;

  TimeViolation({
    required this.type,
    required this.date,
    required this.minutesDifference,
    required this.description,
  });
}

/// Violation types
enum ViolationType {
  earlyClockIn,
  lateClockOut,
  shortBreak,
}

/// Remediation strategy
class RemediationStrategy {
  final StrategyType type;
  final String description;
  final double potentialHoursSaved;
  final int priority;
  final String details;
  final List<ShiftSwapCandidate>? swapCandidates;

  RemediationStrategy({
    required this.type,
    required this.description,
    required this.potentialHoursSaved,
    required this.priority,
    required this.details,
    this.swapCandidates,
  });
}

/// Strategy types
enum StrategyType {
  clockOnTime,
  takeFullBreaks,
  shiftSwap,
}

/// Shift swap candidate
class ShiftSwapCandidate {
  final String candidateId;
  final String candidateName;
  final String shiftId;
  final DateTime shiftDate;
  final double shiftHours;
  final double candidateCurrentHours;
  final double candidateHoursAfterSwap;

  ShiftSwapCandidate({
    required this.candidateId,
    required this.candidateName,
    required this.shiftId,
    required this.shiftDate,
    required this.shiftHours,
    required this.candidateCurrentHours,
    required this.candidateHoursAfterSwap,
  });
}
