import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/registration_request.dart';

/// Service for super admin operations on registration requests
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Gets all pending registration requests
  ///
  /// Returns a stream of pending requests for real-time updates
  Stream<List<RegistrationRequest>> getPendingRequests() {
    return _firestore
        .collection('registrationRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistrationRequest.fromFirestore(doc))
            .toList());
  }

  /// Gets all registration requests (pending, approved, rejected)
  ///
  /// Returns a stream of all requests for real-time updates
  Stream<List<RegistrationRequest>> getAllRequests() {
    return _firestore
        .collection('registrationRequests')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistrationRequest.fromFirestore(doc))
            .toList());
  }

  /// Gets a specific registration request by ID
  Future<RegistrationRequest?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore
          .collection('registrationRequests')
          .doc(requestId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return RegistrationRequest.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch registration request: $e');
    }
  }

  /// Approves a registration request
  ///
  /// This calls a Cloud Function which:
  /// - Creates company document
  /// - Creates Firebase Auth user
  /// - Creates user document
  /// - Sends welcome email
  /// - Updates registration status
  Future<void> approveRegistration(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Must be logged in to approve registrations');
      }

      // Verify user is super admin
      final isSuperAdmin = await _verifySuperAdmin(currentUser.uid);
      if (!isSuperAdmin) {
        throw Exception('Only super admins can approve registrations');
      }

      // Call Cloud Function to handle approval
      final callable = _functions.httpsCallable('approveRegistration');
      final result = await callable.call(<String, dynamic>{
        'requestId': requestId,
        'approvedBy': currentUser.uid,
      });

      if (result.data['success'] != true) {
        throw Exception(result.data['error'] ?? 'Approval failed');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Failed to approve registration: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during approval: $e');
    }
  }

  /// Rejects a registration request
  ///
  /// This calls a Cloud Function which:
  /// - Updates registration status to 'rejected'
  /// - Sends rejection email with reason
  Future<void> rejectRegistration(
    String requestId,
    String rejectionReason,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Must be logged in to reject registrations');
      }

      // Verify user is super admin
      final isSuperAdmin = await _verifySuperAdmin(currentUser.uid);
      if (!isSuperAdmin) {
        throw Exception('Only super admins can reject registrations');
      }

      if (rejectionReason.trim().isEmpty) {
        throw Exception('Rejection reason is required');
      }

      // Call Cloud Function to handle rejection
      final callable = _functions.httpsCallable('rejectRegistration');
      final result = await callable.call(<String, dynamic>{
        'requestId': requestId,
        'rejectedBy': currentUser.uid,
        'rejectionReason': rejectionReason.trim(),
      });

      if (result.data['success'] != true) {
        throw Exception(result.data['error'] ?? 'Rejection failed');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Failed to reject registration: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during rejection: $e');
    }
  }

  /// Manually updates a registration request status (for testing)
  ///
  /// This is a direct Firestore update, bypassing Cloud Functions
  /// Use only for testing or manual corrections
  Future<void> updateRegistrationStatus(
    String requestId,
    String status, {
    String? rejectionReason,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Must be logged in to update registrations');
      }

      // Verify user is super admin
      final isSuperAdmin = await _verifySuperAdmin(currentUser.uid);
      if (!isSuperAdmin) {
        throw Exception('Only super admins can update registrations');
      }

      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'approved') {
        updateData['approvedBy'] = currentUser.uid;
        updateData['approvedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'rejected') {
        updateData['rejectedBy'] = currentUser.uid;
        updateData['rejectedAt'] = FieldValue.serverTimestamp();
        if (rejectionReason != null) {
          updateData['rejectionReason'] = rejectionReason;
        }
      }

      await _firestore
          .collection('registrationRequests')
          .doc(requestId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update registration status: $e');
    }
  }

  /// Checks if current user is a super admin
  Future<bool> isSuperAdmin() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      return await _verifySuperAdmin(currentUser.uid);
    } catch (e) {
      return false;
    }
  }

  /// Verifies if a user ID is in the superAdmins collection
  Future<bool> _verifySuperAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('superAdmins').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Gets registration statistics
  Future<Map<String, int>> getRegistrationStats() async {
    try {
      final allRequests = await _firestore
          .collection('registrationRequests')
          .get();

      int pending = 0;
      int approved = 0;
      int rejected = 0;

      for (final doc in allRequests.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'pending') {
          pending++;
        } else if (status == 'approved') {
          approved++;
        } else if (status == 'rejected') {
          rejected++;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'total': allRequests.docs.length,
      };
    } catch (e) {
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
      };
    }
  }

  /// Searches registration requests by business name or owner email
  Future<List<RegistrationRequest>> searchRequests(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final queryLower = query.trim().toLowerCase();

      // Firestore doesn't support full-text search, so we fetch all and filter
      final snapshot = await _firestore
          .collection('registrationRequests')
          .orderBy('submittedAt', descending: true)
          .get();

      final results = <RegistrationRequest>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final businessName = (data['businessName'] as String?)?.toLowerCase() ?? '';
        final ownerEmail = (data['ownerEmail'] as String?)?.toLowerCase() ?? '';
        final ownerName = (data['ownerName'] as String?)?.toLowerCase() ?? '';

        if (businessName.contains(queryLower) ||
            ownerEmail.contains(queryLower) ||
            ownerName.contains(queryLower)) {
          results.add(RegistrationRequest.fromFirestore(doc));
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to search registrations: $e');
    }
  }

  /// Gets recently approved companies
  Future<List<RegistrationRequest>> getRecentlyApproved({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('registrationRequests')
          .where('status', isEqualTo: 'approved')
          .orderBy('approvedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => RegistrationRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recently approved companies: $e');
    }
  }
}
