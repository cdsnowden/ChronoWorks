import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/break_entry_model.dart';
import '../models/time_entry_model.dart';
import '../utils/constants.dart';

class BreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Start a break
  Future<BreakEntryModel> startBreak({
    required String timeEntryId,
    required String userId,
    Position? location,
    String? notes,
  }) async {
    try {
      final docRef = _firestore.collection(FirebaseCollections.breakEntries).doc();

      final breakEntry = BreakEntryModel(
        id: docRef.id,
        timeEntryId: timeEntryId,
        userId: userId,
        breakStartTime: DateTime.now(),
        breakStartLocation: location != null
            ? {'lat': location.latitude, 'lng': location.longitude}
            : null,
        notes: notes,
        createdAt: DateTime.now(),
      );

      await docRef.set(breakEntry.toMap());
      return breakEntry;
    } catch (e) {
      throw Exception('Failed to start break: $e');
    }
  }

  /// End a break
  Future<BreakEntryModel> endBreak({
    required String breakId,
    Position? location,
  }) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.breakEntries)
          .doc(breakId)
          .get();

      if (!doc.exists) {
        throw Exception('Break entry not found');
      }

      final breakEntry = BreakEntryModel.fromFirestore(doc);

      if (!breakEntry.isOnBreak) {
        throw Exception('Break already ended');
      }

      final updatedBreak = breakEntry.copyWith(
        breakEndTime: DateTime.now(),
        breakEndLocation: location != null
            ? {'lat': location.latitude, 'lng': location.longitude}
            : null,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(FirebaseCollections.breakEntries)
          .doc(breakId)
          .update({
        'breakEndTime': Timestamp.fromDate(updatedBreak.breakEndTime!),
        'breakEndLocation': updatedBreak.breakEndLocation,
        'updatedAt': Timestamp.fromDate(updatedBreak.updatedAt!),
      });

      return updatedBreak;
    } catch (e) {
      throw Exception('Failed to end break: $e');
    }
  }

  /// Get all breaks for a time entry
  Future<List<BreakEntryModel>> getBreaksForTimeEntry(String timeEntryId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.breakEntries)
          .where('timeEntryId', isEqualTo: timeEntryId)
          .orderBy('breakStartTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => BreakEntryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get breaks for time entry: $e');
    }
  }

  /// Get active break for a user (if any)
  Future<BreakEntryModel?> getActiveBreak(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.breakEntries)
          .where('userId', isEqualTo: userId)
          .where('breakEndTime', isNull: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return BreakEntryModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get active break: $e');
    }
  }

  /// Check if break compliance is needed
  Future<BreakComplianceStatus> checkBreakCompliance(TimeEntryModel timeEntry) async {
    try {
      final breaks = await getBreaksForTimeEntry(timeEntry.id);

      // Calculate total break time taken
      double totalBreakMinutes = 0.0;
      DateTime? lastBreakEnd;

      for (final breakEntry in breaks) {
        if (!breakEntry.isOnBreak) {
          totalBreakMinutes += breakEntry.durationMinutes;
          if (lastBreakEnd == null || breakEntry.breakEndTime!.isAfter(lastBreakEnd)) {
            lastBreakEnd = breakEntry.breakEndTime;
          }
        }
      }

      // Calculate hours worked since clock in (or since last break)
      final now = DateTime.now();
      final referenceTime = lastBreakEnd ?? timeEntry.clockInTime;
      final hoursSinceBreak = now.difference(referenceTime).inMinutes / 60.0;

      // Check if break is required
      final breakRequired = hoursSinceBreak >= AppConstants.hoursBeforeBreakRequired;

      // Check if approaching break requirement (5.5 hours)
      final breakWarningThreshold = AppConstants.hoursBeforeBreakRequired - 0.5;
      final breakWarning = hoursSinceBreak >= breakWarningThreshold && !breakRequired;

      // Check if minimum break requirement is met
      final minimumBreakMet = totalBreakMinutes >= AppConstants.minimumBreakMinutes;

      return BreakComplianceStatus(
        breakRequired: breakRequired,
        breakWarning: breakWarning,
        hoursSinceLastBreak: hoursSinceBreak,
        totalBreakMinutes: totalBreakMinutes,
        minimumBreakMet: minimumBreakMet,
        breakCount: breaks.length,
      );
    } catch (e) {
      throw Exception('Failed to check break compliance: $e');
    }
  }

  /// Get break summary for a time entry
  Future<BreakSummary> getBreakSummary(String timeEntryId) async {
    try {
      final breaks = await getBreaksForTimeEntry(timeEntryId);

      double totalBreakMinutes = 0.0;
      int completedBreaks = 0;
      BreakEntryModel? activeBreak;

      for (final breakEntry in breaks) {
        if (breakEntry.isOnBreak) {
          activeBreak = breakEntry;
        } else {
          totalBreakMinutes += breakEntry.durationMinutes;
          completedBreaks++;
        }
      }

      return BreakSummary(
        totalBreakMinutes: totalBreakMinutes,
        breakCount: completedBreaks,
        activeBreak: activeBreak,
        breaks: breaks,
      );
    } catch (e) {
      throw Exception('Failed to get break summary: $e');
    }
  }

  /// Get employees with break compliance issues for today
  Future<List<BreakComplianceAlert>> getBreakComplianceAlerts() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Get all active time entries (clocked in but not clocked out)
      final timeEntriesSnapshot = await _firestore
          .collection(FirebaseCollections.timeEntries)
          .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('clockOutTime', isNull: true)
          .get();

      final List<BreakComplianceAlert> alerts = [];

      for (final doc in timeEntriesSnapshot.docs) {
        final timeEntry = TimeEntryModel.fromFirestore(doc);
        final compliance = await checkBreakCompliance(timeEntry);

        if (compliance.breakRequired || compliance.breakWarning) {
          alerts.add(BreakComplianceAlert(
            userId: timeEntry.userId,
            timeEntryId: timeEntry.id,
            clockInTime: timeEntry.clockInTime,
            hoursSinceLastBreak: compliance.hoursSinceLastBreak,
            breakRequired: compliance.breakRequired,
            breakWarning: compliance.breakWarning,
          ));
        }
      }

      // Sort by hours since break (most critical first)
      alerts.sort((a, b) => b.hoursSinceLastBreak.compareTo(a.hoursSinceLastBreak));

      return alerts;
    } catch (e) {
      throw Exception('Failed to get break compliance alerts: $e');
    }
  }

  /// Delete a break entry
  Future<void> deleteBreak(String breakId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.breakEntries)
          .doc(breakId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete break: $e');
    }
  }
}

/// Break compliance status result
class BreakComplianceStatus {
  final bool breakRequired;
  final bool breakWarning;
  final double hoursSinceLastBreak;
  final double totalBreakMinutes;
  final bool minimumBreakMet;
  final int breakCount;

  BreakComplianceStatus({
    required this.breakRequired,
    required this.breakWarning,
    required this.hoursSinceLastBreak,
    required this.totalBreakMinutes,
    required this.minimumBreakMet,
    required this.breakCount,
  });

  String get statusMessage {
    if (breakRequired) {
      return 'Break required! You\'ve worked ${hoursSinceLastBreak.toStringAsFixed(1)} hours without a break.';
    } else if (breakWarning) {
      return 'Break recommended. You\'ve worked ${hoursSinceLastBreak.toStringAsFixed(1)} hours since your last break.';
    } else {
      return 'Break compliance met.';
    }
  }
}

/// Break summary for a time entry
class BreakSummary {
  final double totalBreakMinutes;
  final int breakCount;
  final BreakEntryModel? activeBreak;
  final List<BreakEntryModel> breaks;

  BreakSummary({
    required this.totalBreakMinutes,
    required this.breakCount,
    this.activeBreak,
    required this.breaks,
  });

  double get totalBreakHours => totalBreakMinutes / 60.0;

  bool get isOnBreak => activeBreak != null;

  String get formattedTotalBreak {
    if (totalBreakMinutes < 60) {
      return '${totalBreakMinutes.round()} min';
    } else {
      final hours = (totalBreakMinutes / 60).floor();
      final minutes = (totalBreakMinutes % 60).round();
      return '${hours}h ${minutes}m';
    }
  }
}

/// Break compliance alert for admin dashboard
class BreakComplianceAlert {
  final String userId;
  final String timeEntryId;
  final DateTime clockInTime;
  final double hoursSinceLastBreak;
  final bool breakRequired;
  final bool breakWarning;

  BreakComplianceAlert({
    required this.userId,
    required this.timeEntryId,
    required this.clockInTime,
    required this.hoursSinceLastBreak,
    required this.breakRequired,
    required this.breakWarning,
  });

  BreakAlertSeverity get severity {
    if (breakRequired) {
      if (hoursSinceLastBreak >= 8.0) {
        return BreakAlertSeverity.critical;
      }
      return BreakAlertSeverity.high;
    } else if (breakWarning) {
      return BreakAlertSeverity.medium;
    }
    return BreakAlertSeverity.low;
  }
}

enum BreakAlertSeverity {
  low,
  medium,
  high,
  critical,
}
