import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/time_off_request_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'blocked_dates_service.dart';
import 'pto_service.dart';

class TimeOffRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BlockedDatesService _blockedDatesService = BlockedDatesService();
  final PtoService _ptoService = PtoService();

  // Create a new time-off request with enhanced validation
  Future<TimeOffRequestModel> createRequest({
    required String employeeId,
    required String employeeName,
    required DateTime startDate,
    required DateTime endDate,
    required String type,
    String? reason,
    required String companyId,
  }) async {
    try {
      // Validate dates
      if (endDate.isBefore(startDate)) {
        throw Exception('End date must be after start date');
      }

      // Check PTO eligibility and balance for paid time off requests
      if (type == 'paid') {
        final employeeDoc = await _firestore
            .collection(FirebaseCollections.users)
            .doc(employeeId)
            .get();

        if (!employeeDoc.exists) {
          throw Exception('Employee not found');
        }

        final employee = UserModel.fromFirestore(employeeDoc);

        if (!employee.isPtoEligible) {
          final eligibilityDate = employee.ptoEligibilityDate;
          throw Exception(
              'You are not eligible for Paid Time Off until ${eligibilityDate.year}-${eligibilityDate.month.toString().padLeft(2, '0')}-${eligibilityDate.day.toString().padLeft(2, '0')} (after 1 year of employment)');
        }

        // Calculate hours requested
        final requestedHours = _ptoService.calculateRequestHours(
          startDate: startDate,
          endDate: endDate,
        );

        // Check PTO balance
        final canRequest = await _ptoService.canRequestHours(
          employeeId: employeeId,
          companyId: companyId,
          hours: requestedHours,
          requestDate: startDate,
        );

        if (!canRequest) {
          // Get current balance for error message
          final balance = await _ptoService.getCurrentBalance(employeeId, companyId);
          final availableHours = balance?.availableHours ?? 0;
          throw Exception(
            'Insufficient PTO balance. You have ${availableHours.toStringAsFixed(1)} hours available, '
            'but this request requires ${requestedHours.toStringAsFixed(1)} hours.'
          );
        }
      }

      // NEW: Check for blackout dates
      final blockedDates = await _blockedDatesService.getBlockedDatesInRange(
        companyId: companyId,
        startDate: startDate,
        endDate: endDate,
      );

      if (blockedDates.isNotEmpty) {
        final blockedDateStrings = blockedDates.map((date) {
          return '${date.month}/${date.day}/${date.year}';
        }).join(', ');

        throw Exception(
            'Your request includes blackout dates when time off is not allowed: $blockedDateStrings\n\nPlease select different dates or contact your manager.');
      }

      // Check for overlapping requests for same employee
      final hasOverlap = await checkOverlappingRequest(
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );

      if (hasOverlap) {
        throw Exception('You already have a time-off request for these dates');
      }

      final docRef = _firestore.collection(FirebaseCollections.timeOffRequests).doc();

      final request = TimeOffRequestModel(
        id: docRef.id,
        employeeId: employeeId,
        employeeName: employeeName,
        startDate: startDate,
        endDate: endDate,
        type: type,
        reason: reason,
        status: 'pending',
        createdAt: DateTime.now(),
        companyId: companyId,
      );

      await docRef.set(request.toMap());

      // Reserve PTO hours for paid time off requests
      if (type == 'paid') {
        final requestedHours = _ptoService.calculateRequestHours(
          startDate: startDate,
          endDate: endDate,
        );
        await _ptoService.reservePtoHours(
          employeeId: employeeId,
          companyId: companyId,
          requestId: docRef.id,
          hours: requestedHours,
          requestDate: startDate,
        );
      }

      return request;
    } catch (e) {
      throw Exception('Failed to create time-off request: $e');
    }
  }

  // Update an existing time-off request (only if still pending)
  Future<void> updateRequest({
    required String requestId,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? reason,
  }) async {
    try {
      final docRef = _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      final request = TimeOffRequestModel.fromFirestore(doc);

      // Only allow updates if still pending
      if (request.status != 'pending') {
        throw Exception('Cannot update a request that has been reviewed');
      }

      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
      if (type != null) updates['type'] = type;
      if (reason != null) updates['reason'] = reason;

      // Validate dates if either changed
      if (startDate != null || endDate != null) {
        final newStartDate = startDate ?? request.startDate;
        final newEndDate = endDate ?? request.endDate;

        if (newEndDate.isBefore(newStartDate)) {
          throw Exception('End date must be after start date');
        }

        // NEW: Check for blackout dates
        final blockedDates = await _blockedDatesService.getBlockedDatesInRange(
          companyId: request.companyId,
          startDate: newStartDate,
          endDate: newEndDate,
        );

        if (blockedDates.isNotEmpty) {
          final blockedDateStrings = blockedDates.map((date) {
            return '${date.month}/${date.day}/${date.year}';
          }).join(', ');

          throw Exception(
              'Your request includes blackout dates: $blockedDateStrings');
        }

        // Check for overlapping requests (excluding this one)
        final hasOverlap = await checkOverlappingRequest(
          employeeId: request.employeeId,
          startDate: newStartDate,
          endDate: newEndDate,
          excludeRequestId: requestId,
        );

        if (hasOverlap) {
          throw Exception('You already have a time-off request for these dates');
        }
      }

      await docRef.update(updates);
    } catch (e) {
      throw Exception('Failed to update time-off request: $e');
    }
  }

  // Cancel a time-off request (soft delete - mark as denied by employee)
  Future<void> cancelRequest(String requestId) async {
    try {
      final docRef = _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      final request = TimeOffRequestModel.fromFirestore(doc);

      // Only allow cancellation if still pending
      if (request.status != 'pending') {
        throw Exception('Cannot cancel a request that has been reviewed');
      }

      await docRef.update({
        'status': 'denied',
        'reviewNotes': 'Cancelled by employee',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Release reserved PTO hours for paid time off
      if (request.type == 'paid') {
        final requestedHours = _ptoService.calculateRequestHours(
          startDate: request.startDate,
          endDate: request.endDate,
        );
        await _ptoService.releasePtoHours(
          employeeId: request.employeeId,
          companyId: request.companyId,
          requestId: requestId,
          hours: requestedHours,
          requestDate: request.startDate,
        );
      }
    } catch (e) {
      throw Exception('Failed to cancel time-off request: $e');
    }
  }

  // Approve a time-off request
  Future<void> approveRequest({
    required String requestId,
    required String reviewerId,
    required String reviewerName,
    String? reviewNotes,
  }) async {
    try {
      final docRef = _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      final request = TimeOffRequestModel.fromFirestore(doc);

      await docRef.update({
        'status': 'approved',
        'reviewedBy': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewNotes': reviewNotes,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Confirm PTO usage for paid time off (moves from pending to used)
      if (request.type == 'paid') {
        final requestedHours = _ptoService.calculateRequestHours(
          startDate: request.startDate,
          endDate: request.endDate,
        );
        await _ptoService.confirmPtoUsage(
          employeeId: request.employeeId,
          companyId: request.companyId,
          requestId: requestId,
          hours: requestedHours,
          requestDate: request.startDate,
        );
      }
    } catch (e) {
      throw Exception('Failed to approve time-off request: $e');
    }
  }

  // Deny a time-off request
  Future<void> denyRequest({
    required String requestId,
    required String reviewerId,
    required String reviewerName,
    String? reviewNotes,
  }) async {
    try {
      final docRef = _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      final request = TimeOffRequestModel.fromFirestore(doc);

      await docRef.update({
        'status': 'denied',
        'reviewedBy': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewNotes': reviewNotes,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Release reserved PTO hours for paid time off
      if (request.type == 'paid') {
        final requestedHours = _ptoService.calculateRequestHours(
          startDate: request.startDate,
          endDate: request.endDate,
        );
        await _ptoService.releasePtoHours(
          employeeId: request.employeeId,
          companyId: request.companyId,
          requestId: requestId,
          hours: requestedHours,
          requestDate: request.startDate,
        );
      }
    } catch (e) {
      throw Exception('Failed to deny time-off request: $e');
    }
  }

  // Delete a time-off request (hard delete)
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .doc(requestId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete time-off request: $e');
    }
  }

  // Get all requests for a specific employee
  Stream<List<TimeOffRequestModel>> getEmployeeRequests(String employeeId) {
    return _firestore
        .collection(FirebaseCollections.timeOffRequests)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get pending requests for a company (for managers/admins)
  Stream<List<TimeOffRequestModel>> getPendingRequests(String companyId) {
    return _firestore
        .collection(FirebaseCollections.timeOffRequests)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get all requests for a company
  Stream<List<TimeOffRequestModel>> getAllCompanyRequests(String companyId) {
    return _firestore
        .collection(FirebaseCollections.timeOffRequests)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get approved time-off for a date range (for schedule conflict checking)
  Future<List<TimeOffRequestModel>> getApprovedTimeOffForDateRange({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'approved')
          .get();

      // Filter in memory for date overlap
      // (Firestore can't do complex date range queries efficiently)
      return querySnapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .where((request) {
            // Check if the request overlaps with the given date range
            return request.startDate.isBefore(endDate) &&
                   request.endDate.isAfter(startDate);
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to get approved time-off: $e');
    }
  }

  // Get approved time-off for a specific employee on a specific date
  Future<TimeOffRequestModel?> getApprovedTimeOffForDate({
    required String employeeId,
    required DateTime date,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: 'approved')
          .get();

      // Filter in memory for date overlap
      for (final doc in querySnapshot.docs) {
        final request = TimeOffRequestModel.fromFirestore(doc);

        // Check if the given date falls within the request's date range
        if ((request.startDate.isBefore(endOfDay) ||
             request.startDate.isAtSameMomentAs(startOfDay)) &&
            (request.endDate.isAfter(startOfDay) ||
             request.endDate.isAtSameMomentAs(startOfDay))) {
          return request;
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to check time-off for date: $e');
    }
  }

  // Check if a date range overlaps with existing requests
  Future<bool> checkOverlappingRequest({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
    String? excludeRequestId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .where('employeeId', isEqualTo: employeeId)
          .get();

      for (final doc in querySnapshot.docs) {
        // Skip the excluded request (for updates)
        if (excludeRequestId != null && doc.id == excludeRequestId) {
          continue;
        }

        final request = TimeOffRequestModel.fromFirestore(doc);

        // Only check pending and approved requests
        if (request.status != 'pending' && request.status != 'approved') {
          continue;
        }

        // Check for overlap
        // Overlap occurs if:
        // 1. New request starts during existing request
        // 2. New request ends during existing request
        // 3. New request completely encompasses existing request
        final hasOverlap = (startDate.isBefore(request.endDate) &&
                startDate.isAfter(request.startDate)) || // starts during
            (endDate.isBefore(request.endDate) &&
                endDate.isAfter(request.startDate)) || // ends during
            (startDate.isBefore(request.startDate) &&
                endDate.isAfter(request.endDate)) || // encompasses
            (startDate.isAtSameMomentAs(request.startDate)) || // exact start match
            (endDate.isAtSameMomentAs(request.endDate)); // exact end match

        if (hasOverlap) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to check overlapping requests: $e');
    }
  }

  // NEW: Get conflicting time-off requests from OTHER employees
  // This shows managers/admins if other employees have time off during the same period
  Future<List<TimeOffRequestModel>> getConflictingRequests({
    required String companyId,
    required String excludeEmployeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .where('companyId', isEqualTo: companyId)
          .get();

      final conflicts = <TimeOffRequestModel>[];

      for (final doc in querySnapshot.docs) {
        final request = TimeOffRequestModel.fromFirestore(doc);

        // Skip requests from the same employee
        if (request.employeeId == excludeEmployeeId) {
          continue;
        }

        // Only include approved or pending requests
        if (request.status != 'approved' && request.status != 'pending') {
          continue;
        }

        // Check for date overlap
        final hasOverlap = (startDate.isBefore(request.endDate) &&
                startDate.isAfter(request.startDate)) ||
            (endDate.isBefore(request.endDate) &&
                endDate.isAfter(request.startDate)) ||
            (startDate.isBefore(request.startDate) &&
                endDate.isAfter(request.endDate)) ||
            (startDate.isAtSameMomentAs(request.startDate)) ||
            (endDate.isAtSameMomentAs(request.endDate));

        if (hasOverlap) {
          conflicts.add(request);
        }
      }

      return conflicts;
    } catch (e) {
      throw Exception('Failed to get conflicting requests: $e');
    }
  }

  // Get a specific request by ID
  Future<TimeOffRequestModel?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .doc(requestId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return TimeOffRequestModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get time-off request: $e');
    }
  }

  // Get upcoming approved time-off for an employee
  Future<List<TimeOffRequestModel>> getUpcomingTimeOff(String employeeId) async {
    try {
      final now = DateTime.now();

      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: 'approved')
          .get();

      // Filter for future dates
      return querySnapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .where((request) => request.endDate.isAfter(now))
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
    } catch (e) {
      throw Exception('Failed to get upcoming time-off: $e');
    }
  }

  // Get statistics for a company
  Future<Map<String, int>> getCompanyStatistics(String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.timeOffRequests)
          .where('companyId', isEqualTo: companyId)
          .get();

      int pending = 0;
      int approved = 0;
      int denied = 0;

      for (final doc in querySnapshot.docs) {
        final request = TimeOffRequestModel.fromFirestore(doc);
        switch (request.status) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            break;
          case 'denied':
            denied++;
            break;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'denied': denied,
        'total': querySnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  // Get pending requests for a manager's team members
  Stream<List<TimeOffRequestModel>> getPendingRequestsByManager(String managerId) {
    return _firestore
        .collection(FirebaseCollections.timeOffRequests)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      // Get employee IDs who report to this manager
      final employeeIds = await _getManagerTeamEmployeeIds(managerId);

      // Filter requests to only those from team members
      return snapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .where((request) => employeeIds.contains(request.employeeId))
          .toList();
    });
  }

  // Get all requests for a manager's team members
  Stream<List<TimeOffRequestModel>> getAllRequestsByManager(String managerId) {
    return _firestore
        .collection(FirebaseCollections.timeOffRequests)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      // Get employee IDs who report to this manager
      final employeeIds = await _getManagerTeamEmployeeIds(managerId);

      // Filter requests to only those from team members
      return snapshot.docs
          .map((doc) => TimeOffRequestModel.fromFirestore(doc))
          .where((request) => employeeIds.contains(request.employeeId))
          .toList();
    });
  }

  // Helper method to get employee IDs that report to a manager
  Future<List<String>> _getManagerTeamEmployeeIds(String managerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('managerId', isEqualTo: managerId)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting manager team employee IDs: $e');
      return [];
    }
  }
}
