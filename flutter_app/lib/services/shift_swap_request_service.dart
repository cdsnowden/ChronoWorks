import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_swap_request_model.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class ShiftSwapRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a coverage request (someone to cover a shift)
  Future<ShiftSwapRequestModel> createCoverageRequest({
    required String requesterId,
    required String requesterName,
    required ShiftModel originalShift,
    String? targetEmployeeId,
    String? targetEmployeeName,
    String? reason,
    required String companyId,
  }) async {
    try {
      // Validate that shift is in the future
      if (originalShift.startTime != null &&
          originalShift.startTime!.isBefore(DateTime.now())) {
        throw Exception('Cannot request coverage for a past shift');
      }

      // Ensure shift is not a day off
      if (originalShift.isDayOff) {
        throw Exception('Cannot request coverage for a day off');
      }

      // Validate keyholder requirements
      await _validateKeyholderRequirement(
        requesterId: requesterId,
        targetEmployeeId: targetEmployeeId,
      );

      final docRef =
          _firestore.collection(FirebaseCollections.shiftSwapRequests).doc();

      final request = ShiftSwapRequestModel(
        id: docRef.id,
        requestType: 'coverage',
        requesterId: requesterId,
        requesterName: requesterName,
        originalShiftId: originalShift.id,
        originalShiftDate: originalShift.startTime ?? originalShift.createdAt,
        originalShiftStartTime: _formatTime(originalShift.startTime),
        originalShiftEndTime: _formatTime(originalShift.endTime),
        targetEmployeeId: targetEmployeeId,
        targetEmployeeName: targetEmployeeName,
        reason: reason,
        status: 'pending',
        createdAt: DateTime.now(),
        companyId: companyId,
      );

      await docRef.set(request.toMap());
      return request;
    } catch (e) {
      throw Exception('Failed to create coverage request: $e');
    }
  }

  // Create a shift swap request (exchange shifts with another employee)
  Future<ShiftSwapRequestModel> createSwapRequest({
    required String requesterId,
    required String requesterName,
    required ShiftModel originalShift,
    required String targetEmployeeId,
    required String targetEmployeeName,
    required ShiftModel replacementShift,
    String? reason,
    required String companyId,
  }) async {
    try {
      // Validate that both shifts are in the future
      if (originalShift.startTime != null &&
          originalShift.startTime!.isBefore(DateTime.now())) {
        throw Exception('Cannot swap a past shift');
      }

      if (replacementShift.startTime != null &&
          replacementShift.startTime!.isBefore(DateTime.now())) {
        throw Exception('Cannot swap with a past shift');
      }

      // Ensure shifts are not day offs
      if (originalShift.isDayOff || replacementShift.isDayOff) {
        throw Exception('Cannot swap day off shifts');
      }

      // Verify that replacement shift belongs to the target employee
      if (replacementShift.employeeId != targetEmployeeId) {
        throw Exception('Replacement shift must belong to the target employee');
      }

      // Validate keyholder requirements
      await _validateKeyholderRequirement(
        requesterId: requesterId,
        targetEmployeeId: targetEmployeeId,
      );

      final docRef =
          _firestore.collection(FirebaseCollections.shiftSwapRequests).doc();

      final request = ShiftSwapRequestModel(
        id: docRef.id,
        requestType: 'swap',
        requesterId: requesterId,
        requesterName: requesterName,
        originalShiftId: originalShift.id,
        originalShiftDate: originalShift.startTime ?? originalShift.createdAt,
        originalShiftStartTime: _formatTime(originalShift.startTime),
        originalShiftEndTime: _formatTime(originalShift.endTime),
        targetEmployeeId: targetEmployeeId,
        targetEmployeeName: targetEmployeeName,
        replacementShiftId: replacementShift.id,
        replacementShiftDate:
            replacementShift.startTime ?? replacementShift.createdAt,
        replacementShiftStartTime: _formatTime(replacementShift.startTime),
        replacementShiftEndTime: _formatTime(replacementShift.endTime),
        reason: reason,
        status: 'pending',
        createdAt: DateTime.now(),
        companyId: companyId,
      );

      await docRef.set(request.toMap());
      return request;
    } catch (e) {
      throw Exception('Failed to create swap request: $e');
    }
  }

  // Cancel a request (by the requester, only if pending)
  Future<void> cancelRequest(String requestId) async {
    try {
      final docRef = _firestore
          .collection(FirebaseCollections.shiftSwapRequests)
          .doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      final request = ShiftSwapRequestModel.fromFirestore(doc);

      // Only allow cancellation if still pending
      if (request.status != 'pending') {
        throw Exception('Cannot cancel a request that has been reviewed');
      }

      await docRef.update({
        'status': 'cancelled',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }

  // Approve a swap/coverage request
  Future<void> approveRequest({
    required String requestId,
    required String reviewerId,
    required String reviewerName,
    String? reviewNotes,
  }) async {
    try {
      final docRef = _firestore
          .collection(FirebaseCollections.shiftSwapRequests)
          .doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      final request = ShiftSwapRequestModel.fromFirestore(doc);

      // Only approve if pending
      if (request.status != 'pending') {
        throw Exception('Can only approve pending requests');
      }

      // Update the request status
      await docRef.update({
        'status': 'approved',
        'reviewedBy': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewNotes': reviewNotes,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Execute the shift changes
      await _executeShiftChanges(request);
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  // Deny a swap/coverage request
  Future<void> denyRequest({
    required String requestId,
    required String reviewerId,
    required String reviewerName,
    String? reviewNotes,
  }) async {
    try {
      await _firestore
          .collection(FirebaseCollections.shiftSwapRequests)
          .doc(requestId)
          .update({
        'status': 'denied',
        'reviewedBy': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewNotes': reviewNotes,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to deny request: $e');
    }
  }

  // Execute shift changes after approval
  Future<void> _executeShiftChanges(ShiftSwapRequestModel request) async {
    try {
      if (request.requestType == 'swap') {
        // For swaps, exchange the employeeId of both shifts
        await _firestore.runTransaction((transaction) async {
          final originalShiftRef =
              _firestore.collection(FirebaseCollections.shifts).doc(request.originalShiftId);
          final replacementShiftRef = _firestore
              .collection(FirebaseCollections.shifts)
              .doc(request.replacementShiftId);

          final originalShiftDoc = await transaction.get(originalShiftRef);
          final replacementShiftDoc = await transaction.get(replacementShiftRef);

          if (!originalShiftDoc.exists || !replacementShiftDoc.exists) {
            throw Exception('One or both shifts no longer exist');
          }

          // Swap employee IDs
          transaction.update(originalShiftRef, {
            'employeeId': request.targetEmployeeId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

          transaction.update(replacementShiftRef, {
            'employeeId': request.requesterId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        });
      } else if (request.requestType == 'coverage') {
        // For coverage, update the original shift to the target employee
        if (request.targetEmployeeId != null) {
          await _firestore
              .collection(FirebaseCollections.shifts)
              .doc(request.originalShiftId)
              .update({
            'employeeId': request.targetEmployeeId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }
    } catch (e) {
      throw Exception('Failed to execute shift changes: $e');
    }
  }

  // Delete a request (hard delete)
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.shiftSwapRequests)
          .doc(requestId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete request: $e');
    }
  }

  // Get all requests made by a specific employee
  Stream<List<ShiftSwapRequestModel>> getEmployeeRequests(String employeeId) {
    return _firestore
        .collection(FirebaseCollections.shiftSwapRequests)
        .where('requesterId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftSwapRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get all requests targeted to a specific employee
  Stream<List<ShiftSwapRequestModel>> getTargetedRequests(String employeeId) {
    return _firestore
        .collection(FirebaseCollections.shiftSwapRequests)
        .where('targetEmployeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftSwapRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get pending requests for a company (for managers/admins)
  Stream<List<ShiftSwapRequestModel>> getPendingRequests(String companyId) {
    return _firestore
        .collection(FirebaseCollections.shiftSwapRequests)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftSwapRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get all requests for a company
  Stream<List<ShiftSwapRequestModel>> getAllCompanyRequests(String companyId) {
    return _firestore
        .collection(FirebaseCollections.shiftSwapRequests)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftSwapRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get open coverage requests (not targeted to a specific employee)
  Stream<List<ShiftSwapRequestModel>> getOpenCoverageRequests(
      String companyId) {
    return _firestore
        .collection(FirebaseCollections.shiftSwapRequests)
        .where('companyId', isEqualTo: companyId)
        .where('requestType', isEqualTo: 'coverage')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftSwapRequestModel.fromFirestore(doc))
          .where((request) => request.targetEmployeeId == null)
          .toList();
    });
  }

  // Get a specific request by ID
  Future<ShiftSwapRequestModel?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.shiftSwapRequests)
          .doc(requestId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return ShiftSwapRequestModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get request: $e');
    }
  }

  // Get statistics for a company
  Future<Map<String, int>> getCompanyStatistics(String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.shiftSwapRequests)
          .where('companyId', isEqualTo: companyId)
          .get();

      int pending = 0;
      int approved = 0;
      int denied = 0;
      int cancelled = 0;
      int swaps = 0;
      int coverage = 0;

      for (final doc in querySnapshot.docs) {
        final request = ShiftSwapRequestModel.fromFirestore(doc);

        // Count by status
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
          case 'cancelled':
            cancelled++;
            break;
        }

        // Count by type
        if (request.requestType == 'swap') {
          swaps++;
        } else if (request.requestType == 'coverage') {
          coverage++;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'denied': denied,
        'cancelled': cancelled,
        'swaps': swaps,
        'coverage': coverage,
        'total': querySnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  // Helper method to validate keyholder requirements
  Future<void> _validateKeyholderRequirement({
    required String requesterId,
    String? targetEmployeeId,
  }) async {
    // Get requester user info
    final requesterDoc =
        await _firestore.collection(FirebaseCollections.users).doc(requesterId).get();
    if (!requesterDoc.exists) {
      throw Exception('Requester not found');
    }
    final requester = UserModel.fromFirestore(requesterDoc);

    // If requester is a keyholder, target must also be a keyholder
    if (requester.isKeyholder) {
      if (targetEmployeeId == null) {
        throw Exception(
            'Keyholders cannot create open coverage requests. '
            'You must specify another keyholder to cover your shift.');
      }

      // Get target employee info
      final targetDoc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(targetEmployeeId)
          .get();
      if (!targetDoc.exists) {
        throw Exception('Target employee not found');
      }
      final targetEmployee = UserModel.fromFirestore(targetDoc);

      if (!targetEmployee.isKeyholder) {
        throw Exception(
            'You are a keyholder, so your replacement must also be a keyholder. '
            '${targetEmployee.fullName} is not a keyholder.');
      }
    }
  }

  // Helper method to format time from DateTime
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}
