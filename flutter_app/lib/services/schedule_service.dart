import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_model.dart';
import '../utils/constants.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new shift
  Future<ShiftModel> createShift({
    required String employeeId,
    DateTime? startTime,
    DateTime? endTime,
    required String createdBy,
    String? notes,
    String? location,
    bool isPublished = false,
    bool isDayOff = false,
    String? dayOffType,
    double? paidHours,
  }) async {
    try {
      // Validate shift based on type
      if (isDayOff) {
        // Day off shifts don't need time validation
      } else {
        // Regular shifts need valid times
        if (startTime == null || endTime == null) {
          throw Exception('Start time and end time are required for regular shifts');
        }

        if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
          throw Exception('End time must be after start time');
        }

        // Check for conflicts only for regular shifts
        final hasConflict = await checkShiftConflict(
          employeeId: employeeId,
          startTime: startTime,
          endTime: endTime,
        );

        if (hasConflict) {
          throw Exception(
              'This shift conflicts with an existing shift for this employee');
        }
      }

      final docRef = _firestore.collection(FirebaseCollections.shifts).doc();

      final shift = ShiftModel(
        id: docRef.id,
        employeeId: employeeId,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
        location: location,
        isPublished: isPublished,
        isDayOff: isDayOff,
        dayOffType: dayOffType,
        paidHours: paidHours,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      await docRef.set(shift.toMap());
      return shift;
    } catch (e) {
      throw Exception('Failed to create shift: $e');
    }
  }

  // Update an existing shift
  Future<ShiftModel> updateShift({
    required String shiftId,
    String? employeeId,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    String? location,
    bool? isPublished,
  }) async {
    try {
      final docRef =
          _firestore.collection(FirebaseCollections.shifts).doc(shiftId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Shift not found');
      }

      final currentShift = ShiftModel.fromFirestore(doc);

      // If times are changing, validate and check for conflicts (only for regular shifts, not day offs)
      if (!currentShift.isDayOff) {
        final newStartTime = startTime ?? currentShift.startTime;
        final newEndTime = endTime ?? currentShift.endTime;
        final newEmployeeId = employeeId ?? currentShift.employeeId;

        if (newStartTime != null && newEndTime != null) {
          if (newEndTime.isBefore(newStartTime) ||
              newEndTime.isAtSameMomentAs(newStartTime)) {
            throw Exception('End time must be after start time');
          }

          // Check for conflicts (excluding this shift)
          final hasConflict = await checkShiftConflict(
            employeeId: newEmployeeId,
            startTime: newStartTime,
            endTime: newEndTime,
            excludeShiftId: shiftId,
          );

          if (hasConflict) {
            throw Exception(
                'This shift conflicts with an existing shift for this employee');
          }
        }
      }

      final updatedShift = currentShift.copyWith(
        employeeId: employeeId,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
        location: location,
        isPublished: isPublished,
        updatedAt: DateTime.now(),
      );

      await docRef.update(updatedShift.toMap());
      return updatedShift;
    } catch (e) {
      throw Exception('Failed to update shift: $e');
    }
  }

  // Delete a shift
  Future<void> deleteShift(String shiftId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.shifts)
          .doc(shiftId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete shift: $e');
    }
  }

  // Publish a shift (make it visible to employee)
  Future<void> publishShift(String shiftId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.shifts)
          .doc(shiftId)
          .update({'isPublished': true, 'updatedAt': Timestamp.now()});
    } catch (e) {
      throw Exception('Failed to publish shift: $e');
    }
  }

  // Unpublish a shift
  Future<void> unpublishShift(String shiftId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.shifts)
          .doc(shiftId)
          .update({'isPublished': false, 'updatedAt': Timestamp.now()});
    } catch (e) {
      throw Exception('Failed to unpublish shift: $e');
    }
  }

  // Publish multiple shifts at once
  Future<void> publishShifts(List<String> shiftIds) async {
    try {
      final batch = _firestore.batch();
      for (final shiftId in shiftIds) {
        final docRef =
            _firestore.collection(FirebaseCollections.shifts).doc(shiftId);
        batch.update(docRef, {'isPublished': true, 'updatedAt': Timestamp.now()});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to publish shifts: $e');
    }
  }

  // Get shifts for a specific employee
  Stream<List<ShiftModel>> getEmployeeShiftsStream(String employeeId,
      {bool publishedOnly = false}) {
    Query query = _firestore
        .collection(FirebaseCollections.shifts)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('startTime', descending: false);

    if (publishedOnly) {
      query = query.where('isPublished', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get shifts for a specific employee within a date range
  Stream<List<ShiftModel>> getEmployeeShiftsByDateRange({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
    bool publishedOnly = false,
  }) {
    Query query = _firestore
        .collection(FirebaseCollections.shifts)
        .where('employeeId', isEqualTo: employeeId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startTime', descending: false);

    if (publishedOnly) {
      query = query.where('isPublished', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get all shifts for employees in a company (admin view)
  // Note: This method should be called with a list of employee IDs from the company
  // to ensure proper multi-tenancy isolation
  Stream<List<ShiftModel>> getShiftsForEmployees(List<String> employeeIds) {
    if (employeeIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(FirebaseCollections.shifts)
        .where('employeeId', whereIn: employeeIds.take(10).toList()) // Firestore limit of 10 for whereIn
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get all shifts within a date range for employees in a company (admin view)
  // Note: This method should be called with a list of employee IDs from the company
  // to ensure proper multi-tenancy isolation
  Stream<List<ShiftModel>> getShiftsByDateRangeForEmployees({
    required DateTime startDate,
    required DateTime endDate,
    required List<String> employeeIds,
  }) {
    if (employeeIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(FirebaseCollections.shifts)
        .where('employeeId', whereIn: employeeIds.take(10).toList()) // Firestore limit of 10 for whereIn
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get a specific shift by ID
  Future<ShiftModel?> getShiftById(String shiftId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.shifts)
          .doc(shiftId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return ShiftModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get shift: $e');
    }
  }

  // Check if a shift conflicts with existing shifts for an employee
  Future<bool> checkShiftConflict({
    required String employeeId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeShiftId,
  }) async {
    try {
      // Query for shifts that could potentially overlap
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .get();

      for (final doc in querySnapshot.docs) {
        // Skip the shift we're excluding (for updates)
        if (excludeShiftId != null && doc.id == excludeShiftId) {
          continue;
        }

        final shift = ShiftModel.fromFirestore(doc);

        // Skip day off shifts - they don't conflict with regular shifts
        if (shift.isDayOff || shift.startTime == null || shift.endTime == null) {
          continue;
        }

        // Check for overlap
        // Overlap occurs if:
        // 1. New shift starts during existing shift
        // 2. New shift ends during existing shift
        // 3. New shift completely encompasses existing shift
        final hasOverlap = (startTime.isBefore(shift.endTime!) &&
                startTime.isAfter(shift.startTime!)) || // starts during
            (endTime.isBefore(shift.endTime!) &&
                endTime.isAfter(shift.startTime!)) || // ends during
            (startTime.isBefore(shift.startTime!) &&
                endTime.isAfter(shift.endTime!)) || // encompasses
            (startTime.isAtSameMomentAs(shift.startTime!)) || // exact start match
            (endTime.isAtSameMomentAs(shift.endTime!)); // exact end match

        if (hasOverlap) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to check shift conflict: $e');
    }
  }

  // Get total scheduled hours for an employee in a date range
  Future<double> getScheduledHours({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalHours = 0.0;
      for (final doc in querySnapshot.docs) {
        final shift = ShiftModel.fromFirestore(doc);
        totalHours += shift.durationHours;
      }

      return totalHours;
    } catch (e) {
      throw Exception('Failed to calculate scheduled hours: $e');
    }
  }

  // Get upcoming shifts for an employee (next 7 days)
  Future<List<ShiftModel>> getUpcomingShifts(String employeeId) async {
    try {
      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('isPublished', isEqualTo: true)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(nextWeek))
          .orderBy('startTime', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => ShiftModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get upcoming shifts: $e');
    }
  }

  // Get today's shift for an employee
  Future<ShiftModel?> getTodayShift(String employeeId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shifts)
          .where('employeeId', isEqualTo: employeeId)
          .where('isPublished', isEqualTo: true)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return ShiftModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get today\'s shift: $e');
    }
  }
}
