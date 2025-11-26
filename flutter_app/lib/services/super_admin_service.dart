import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing super admin features
class SuperAdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if the current user is a super admin
  Future<bool> isSuperAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final superAdminDoc = await _firestore
          .collection('superAdmins')
          .doc(user.uid)
          .get();

      return superAdminDoc.exists;
    } catch (e) {
      // Silently handle permission denied - expected for non-super-admin users
      // Only print if it's NOT a permission error
      if (!e.toString().contains('permission-denied')) {
        print('Error checking super admin status: $e');
      }
      return false;
    }
  }

  /// Get all registration requests
  Future<List<RegistrationRequest>> getRegistrationRequests({
    String? status,
  }) async {
    try {
      Query query = _firestore.collection('registrationRequests');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => RegistrationRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting registration requests: $e');
      rethrow;
    }
  }

  /// Get all companies
  Future<List<CompanyInfo>> getAllCompanies() async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CompanyInfo.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting companies: $e');
      rethrow;
    }
  }

  /// Get system statistics
  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      // Get counts in parallel
      final results = await Future.wait([
        _firestore.collection('companies').count().get(),
        _firestore.collection('users').count().get(),
        _firestore
            .collection('registrationRequests')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
      ]);

      final companiesSnapshot = await _firestore.collection('companies').get();

      // Count active subscriptions by plan
      final planCounts = <String, int>{};
      for (var doc in companiesSnapshot.docs) {
        final plan = doc.data()['currentPlan'] ?? 'free';
        planCounts[plan] = (planCounts[plan] ?? 0) + 1;
      }

      return {
        'totalCompanies': results[0].count ?? 0,
        'totalUsers': results[1].count ?? 0,
        'pendingRequests': results[2].count ?? 0,
        'planDistribution': planCounts,
      };
    } catch (e) {
      print('Error getting system stats: $e');
      rethrow;
    }
  }

  /// Archive a company (set status to archived)
  Future<void> archiveCompany(String companyId) async {
    try {
      await _firestore.collection('companies').doc(companyId).update({
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Company archived successfully: $companyId');
    } catch (e) {
      print('Error archiving company: $e');
      rethrow;
    }
  }

  /// Unarchive a company (restore to active status)
  Future<void> unarchiveCompany(String companyId) async {
    try {
      await _firestore.collection('companies').doc(companyId).update({
        'status': 'active',
        'archivedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Company unarchived successfully: $companyId');
    } catch (e) {
      print('Error unarchiving company: $e');
      rethrow;
    }
  }

  /// Delete a company and clean up related data (PERMANENT)
  Future<void> deleteCompany(String companyId) async {
    try {
      // Get company data first
      final companyDoc = await _firestore.collection('companies').doc(companyId).get();
      if (!companyDoc.exists) {
        throw Exception('Company not found');
      }

      final companyData = companyDoc.data()!;

      // If company has an assigned Account Manager, remove it from AM's list
      if (companyData.containsKey('assignedAccountManager') &&
          companyData['assignedAccountManager'] != null) {
        final amId = companyData['assignedAccountManager']['id'] as String;

        await _firestore.collection('accountManagers').doc(amId).update({
          'assignedCompanies': FieldValue.arrayRemove([companyId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Delete all users in this company
      final usersSnapshot = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        await userDoc.reference.delete();
      }

      // Delete all time entries
      final timeEntriesSnapshot = await _firestore
          .collection('timeEntries')
          .where('companyId', isEqualTo: companyId)
          .get();

      for (var entryDoc in timeEntriesSnapshot.docs) {
        await entryDoc.reference.delete();
      }

      // Delete the company document
      await _firestore.collection('companies').doc(companyId).delete();

      print('Company deleted successfully: $companyId');
    } catch (e) {
      print('Error deleting company: $e');
      rethrow;
    }
  }

  /// Get pending deletion requests
  Future<List<DeletionRequest>> getDeletionRequests({String? status}) async {
    try {
      Query query = _firestore.collection('deletionRequests');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => DeletionRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Handle index building error gracefully
      if (e.toString().contains('index is currently building')) {
        print('Index is building, returning empty list temporarily');
        return [];
      }
      print('Error getting deletion requests: $e');
      rethrow;
    }
  }

  /// Approve deletion request - archive the company
  Future<void> approveDeletionRequestAsArchive(String requestId, String companyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Archive the company
      await archiveCompany(companyId);

      // Update the request status
      await _firestore.collection('deletionRequests').doc(requestId).update({
        'status': 'approved_archived',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Deletion request approved as archive: $requestId');
    } catch (e) {
      print('Error approving deletion request as archive: $e');
      rethrow;
    }
  }

  /// Approve deletion request - permanently delete the company
  Future<void> approveDeletionRequestAsDelete(String requestId, String companyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Delete the company permanently
      await deleteCompany(companyId);

      // Update the request status
      await _firestore.collection('deletionRequests').doc(requestId).update({
        'status': 'approved_deleted',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Deletion request approved as delete: $requestId');
    } catch (e) {
      print('Error approving deletion request as delete: $e');
      rethrow;
    }
  }

  /// Reject deletion request
  Future<void> rejectDeletionRequest(String requestId, String rejectionReason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Update the request status
      await _firestore.collection('deletionRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Deletion request rejected: $requestId');
    } catch (e) {
      print('Error rejecting deletion request: $e');
      rethrow;
    }
  }
}

/// Deletion request model
class DeletionRequest {
  final String id;
  final String type; // 'company' or 'accountManager'
  final String companyId;
  final String companyName;
  final Map<String, dynamic> requestedBy;
  final String reason;
  final String status; // 'pending', 'approved_archived', 'approved_deleted', 'rejected'
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? rejectionReason;

  DeletionRequest({
    required this.id,
    required this.type,
    required this.companyId,
    required this.companyName,
    required this.requestedBy,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
  });

  factory DeletionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeletionRequest(
      id: doc.id,
      type: data['type'] ?? 'company',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      requestedBy: data['requestedBy'] ?? {},
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      processedBy: data['processedBy'],
      rejectionReason: data['rejectionReason'],
    );
  }
}

/// Registration request model
class RegistrationRequest {
  final String id;
  final String businessName;
  final String ownerName;
  final String ownerEmail;
  final String phoneNumber;
  final String address;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? rejectionReason;

  RegistrationRequest({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.ownerEmail,
    required this.phoneNumber,
    required this.address,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
  });

  factory RegistrationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Format address from map to string
    String formattedAddress = '';
    if (data['address'] != null) {
      final addr = data['address'];
      if (addr is Map) {
        final street = addr['street'] ?? '';
        final city = addr['city'] ?? '';
        final state = addr['state'] ?? '';
        final zip = addr['zip'] ?? '';
        formattedAddress = '$street, $city, $state $zip';
      } else {
        formattedAddress = addr.toString();
      }
    }

    return RegistrationRequest(
      id: doc.id,
      businessName: data['businessName'] ?? '',
      ownerName: data['ownerName'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      phoneNumber: data['ownerPhone'] ?? data['phoneNumber'] ?? '',
      address: formattedAddress,
      status: data['status'] ?? 'pending',
      createdAt: (data['submittedAt'] ?? data['createdAt'] as Timestamp).toDate(),
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      processedBy: data['processedBy'],
      rejectionReason: data['rejectionReason'],
    );
  }
}

/// Company info model for super admin
class CompanyInfo {
  final String id;
  final String businessName;
  final String ownerName;
  final String ownerEmail;
  final String currentPlan;
  final String status;
  final DateTime createdAt;
  final int? maxEmployees;
  final bool hasAccountManager;

  CompanyInfo({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.ownerEmail,
    required this.currentPlan,
    required this.status,
    required this.createdAt,
    this.maxEmployees,
    required this.hasAccountManager,
  });

  factory CompanyInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyInfo(
      id: doc.id,
      businessName: data['businessName'] ?? '',
      ownerName: data['ownerName'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      currentPlan: data['currentPlan'] ?? 'free',
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      maxEmployees: data['maxEmployees'],
      hasAccountManager: data.containsKey('assignedAccountManager') &&
          data['assignedAccountManager'] != null,
    );
  }
}
