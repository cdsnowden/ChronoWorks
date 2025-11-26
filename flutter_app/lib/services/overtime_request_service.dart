import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/overtime_request_model.dart';
import '../utils/constants.dart';

class OvertimeRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new overtime request
  Future<OvertimeRequestModel> createOvertimeRequest({
    required String shiftId,
    required String employeeId,
    required String employeeName,
    required String managerId,
    required String managerName,
    required DateTime shiftStartTime,
    required DateTime shiftEndTime,
    required double shiftHours,
    required double weeklyHoursBeforeShift,
    required double projectedWeeklyHours,
    required double overtimeHours,
    required DateTime weekStartDate,
    required DateTime weekEndDate,
  }) async {
    try {
      final docRef = _firestore.collection(FirebaseCollections.overtimeRequests).doc();

      final overtimeRequest = OvertimeRequestModel(
        id: docRef.id,
        shiftId: shiftId,
        employeeId: employeeId,
        employeeName: employeeName,
        managerId: managerId,
        managerName: managerName,
        shiftStartTime: shiftStartTime,
        shiftEndTime: shiftEndTime,
        shiftHours: shiftHours,
        weeklyHoursBeforeShift: weeklyHoursBeforeShift,
        projectedWeeklyHours: projectedWeeklyHours,
        overtimeHours: overtimeHours,
        weekStartDate: weekStartDate,
        weekEndDate: weekEndDate,
        status: 'pending',
        createdAt: DateTime.now(),
        smsNotificationSent: false,
      );

      await docRef.set(overtimeRequest.toMap());
      return overtimeRequest;
    } catch (e) {
      throw Exception('Failed to create overtime request: $e');
    }
  }

  /// Get all pending overtime requests
  Stream<List<OvertimeRequestModel>> getPendingOvertimeRequests() {
    return _firestore
        .collection(FirebaseCollections.overtimeRequests)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OvertimeRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get all overtime requests (for admin view)
  Stream<List<OvertimeRequestModel>> getAllOvertimeRequests() {
    return _firestore
        .collection(FirebaseCollections.overtimeRequests)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OvertimeRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get overtime requests for a specific employee
  Stream<List<OvertimeRequestModel>> getEmployeeOvertimeRequests(String employeeId) {
    return _firestore
        .collection(FirebaseCollections.overtimeRequests)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OvertimeRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get overtime requests created by a specific manager
  Stream<List<OvertimeRequestModel>> getManagerOvertimeRequests(String managerId) {
    return _firestore
        .collection(FirebaseCollections.overtimeRequests)
        .where('managerId', isEqualTo: managerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OvertimeRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Approve an overtime request
  Future<void> approveOvertimeRequest({
    required String overtimeRequestId,
    required String adminId,
  }) async {
    try {
      await _firestore
          .collection(FirebaseCollections.overtimeRequests)
          .doc(overtimeRequestId)
          .update({
        'status': 'approved',
        'approvedBy': adminId,
        'approvedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to approve overtime request: $e');
    }
  }

  /// Reject an overtime request
  Future<void> rejectOvertimeRequest({
    required String overtimeRequestId,
    required String adminId,
    String? rejectionReason,
  }) async {
    try {
      await _firestore
          .collection(FirebaseCollections.overtimeRequests)
          .doc(overtimeRequestId)
          .update({
        'status': 'rejected',
        'approvedBy': adminId,
        'approvedAt': Timestamp.now(),
        'rejectionReason': rejectionReason ?? 'No reason provided',
      });
    } catch (e) {
      throw Exception('Failed to reject overtime request: $e');
    }
  }

  /// Get a specific overtime request by ID
  Future<OvertimeRequestModel?> getOvertimeRequestById(String overtimeRequestId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.overtimeRequests)
          .doc(overtimeRequestId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return OvertimeRequestModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get overtime request: $e');
    }
  }

  /// Mark SMS notification as sent
  Future<void> markSmsNotificationSent(String overtimeRequestId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.overtimeRequests)
          .doc(overtimeRequestId)
          .update({
        'smsNotificationSent': true,
      });
    } catch (e) {
      throw Exception('Failed to mark SMS notification as sent: $e');
    }
  }

  /// Get count of pending overtime requests
  Future<int> getPendingOvertimeRequestsCount() async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.overtimeRequests)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Failed to get pending overtime requests count: $e');
    }
  }
}
