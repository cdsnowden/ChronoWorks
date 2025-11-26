import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/account_manager.dart';

class AccountManagerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _accountManagersCollection =>
      _firestore.collection('accountManagers');

  CollectionReference get _usersCollection => _firestore.collection('users');

  CollectionReference get _companiesCollection =>
      _firestore.collection('companies');

  /// Create a new Account Manager using Cloud Function
  /// This ensures the current user doesn't get logged out
  Future<String> createAccountManager({
    required String email,
    required String displayName,
    required String password,
    String? phoneNumber,
    int maxAssignedCompanies = 100,
  }) async {
    try {
      // Call the Cloud Function to create Account Manager
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('createAccountManager');

      final result = await callable.call({
        'email': email,
        'displayName': displayName,
        'password': password,
        'phoneNumber': phoneNumber,
        'maxAssignedCompanies': maxAssignedCompanies,
      });

      // Check if successful
      if (result.data['success'] == true) {
        return result.data['accountManagerId'] as String;
      } else {
        throw Exception(result.data['message'] ?? 'Unknown error');
      }
    } catch (e) {
      // Handle FirebaseFunctionsException
      if (e is FirebaseFunctionsException) {
        throw Exception('Failed to create Account Manager: ${e.message}');
      }
      throw Exception('Failed to create Account Manager: $e');
    }
  }

  /// Get Account Manager by ID
  Future<AccountManager?> getAccountManager(String id) async {
    try {
      DocumentSnapshot doc = await _accountManagersCollection.doc(id).get();
      if (doc.exists) {
        return AccountManager.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get Account Manager: $e');
    }
  }

  /// Get all Account Managers
  Stream<List<AccountManager>> getAllAccountManagers() {
    return _accountManagersCollection
        .where('status', isEqualTo: 'active')
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AccountManager.fromFirestore(doc))
            .toList());
  }

  /// Alias for getAllAccountManagers (for consistency)
  Stream<List<AccountManager>> getAccountManagersStream() {
    return getAllAccountManagers();
  }

  /// Get Account Manager by current user
  Future<AccountManager?> getCurrentAccountManager() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return getAccountManager(uid);
  }

  /// Update Account Manager profile
  Future<void> updateAccountManager(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _accountManagersCollection.doc(id).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update Account Manager: $e');
    }
  }

  /// Assign a company to an Account Manager
  Future<void> assignCompanyToManager({
    required String accountManagerId,
    required String companyId,
  }) async {
    try {
      // Get Account Manager to check capacity
      AccountManager? am = await getAccountManager(accountManagerId);
      if (am == null) {
        throw Exception('Account Manager not found');
      }

      if (am.isAtCapacity) {
        throw Exception(
            'Account Manager is at capacity (${am.maxAssignedCompanies} customers)');
      }

      // Get company details
      DocumentSnapshot companyDoc =
          await _companiesCollection.doc(companyId).get();
      if (!companyDoc.exists) {
        throw Exception('Company not found');
      }

      Map<String, dynamic> companyData =
          companyDoc.data() as Map<String, dynamic>;

      // Update Account Manager - add company to assignedCompanies
      await _accountManagersCollection.doc(accountManagerId).update({
        'assignedCompanies': FieldValue.arrayUnion([companyId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Company - set assignedAccountManager
      await _companiesCollection.doc(companyId).update({
        'assignedAccountManager': {
          'id': accountManagerId,
          'name': am.displayName,
          'email': am.email,
          'assignedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update metrics
      await _updateAccountManagerMetrics(accountManagerId);
    } catch (e) {
      throw Exception('Failed to assign company: $e');
    }
  }

  /// Unassign a company from an Account Manager
  Future<void> unassignCompanyFromManager({
    required String accountManagerId,
    required String companyId,
  }) async {
    try {
      // Update Account Manager - remove company from assignedCompanies
      await _accountManagersCollection.doc(accountManagerId).update({
        'assignedCompanies': FieldValue.arrayRemove([companyId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Company - remove assignedAccountManager
      await _companiesCollection.doc(companyId).update({
        'assignedAccountManager': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update metrics
      await _updateAccountManagerMetrics(accountManagerId);
    } catch (e) {
      throw Exception('Failed to unassign company: $e');
    }
  }

  /// Reassign company to different Account Manager
  Future<void> reassignCompany({
    required String companyId,
    required String newAccountManagerId,
  }) async {
    try {
      // Get company to find current Account Manager
      DocumentSnapshot companyDoc =
          await _companiesCollection.doc(companyId).get();
      if (!companyDoc.exists) {
        throw Exception('Company not found');
      }

      Map<String, dynamic> companyData =
          companyDoc.data() as Map<String, dynamic>;

      // If already assigned, unassign first
      if (companyData.containsKey('assignedAccountManager')) {
        String oldAccountManagerId =
            companyData['assignedAccountManager']['id'];
        await unassignCompanyFromManager(
          accountManagerId: oldAccountManagerId,
          companyId: companyId,
        );
      }

      // Assign to new Account Manager
      await assignCompanyToManager(
        accountManagerId: newAccountManagerId,
        companyId: companyId,
      );
    } catch (e) {
      throw Exception('Failed to reassign company: $e');
    }
  }

  /// Get companies assigned to an Account Manager
  Stream<List<Map<String, dynamic>>> getAssignedCompanies(
      String accountManagerId) {
    return _companiesCollection
        .where('assignedAccountManager.id', isEqualTo: accountManagerId)
        .orderBy('businessName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>
            }).toList());
  }

  /// Update Account Manager metrics (internal)
  Future<void> _updateAccountManagerMetrics(String accountManagerId) async {
    try {
      // Get all assigned companies
      QuerySnapshot companiesSnapshot = await _companiesCollection
          .where('assignedAccountManager.id', isEqualTo: accountManagerId)
          .get();

      int totalAssigned = companiesSnapshot.docs.length;
      int activeCustomers = 0;
      int trialCustomers = 0;
      int paidCustomers = 0;

      for (var doc in companiesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Check if active (logged in last 7 days)
        if (data.containsKey('healthMetrics')) {
          int daysSinceLastLogin =
              data['healthMetrics']['daysSinceLastLogin'] ?? 999;
          if (daysSinceLastLogin <= 7) {
            activeCustomers++;
          }
        }

        // Check plan status
        String status = data['status'] ?? '';
        String planId = data['subscriptionPlan'] ?? '';

        if (status == 'trial' || planId == 'trial') {
          trialCustomers++;
        } else if (status == 'active') {
          paidCustomers++;
        }
      }

      // Calculate average response time (would need support tickets data)
      // For now, keep existing value

      // Update metrics
      await _accountManagersCollection.doc(accountManagerId).update({
        'metrics.totalAssignedCustomers': totalAssigned,
        'metrics.activeCustomers': activeCustomers,
        'metrics.trialCustomers': trialCustomers,
        'metrics.paidCustomers': paidCustomers,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to update metrics: $e');
      // Don't throw - metrics update is non-critical
    }
  }

  /// Manually update metrics (can be called by cron job)
  Future<void> updateMetricsForAll() async {
    try {
      QuerySnapshot amsSnapshot =
          await _accountManagersCollection.where('status', isEqualTo: 'active').get();

      for (var doc in amsSnapshot.docs) {
        await _updateAccountManagerMetrics(doc.id);
      }
    } catch (e) {
      print('Failed to update all metrics: $e');
    }
  }

  /// Deactivate Account Manager (don't delete, just mark inactive)
  Future<void> deactivateAccountManager(String id) async {
    try {
      await _accountManagersCollection.doc(id).update({
        'status': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to deactivate Account Manager: $e');
    }
  }

  /// Reactivate Account Manager
  Future<void> reactivateAccountManager(String id) async {
    try {
      await _accountManagersCollection.doc(id).update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reactivate Account Manager: $e');
    }
  }

  /// Delete an Account Manager permanently (only if no companies assigned)
  Future<void> deleteAccountManager(String id) async {
    try {
      // Get Account Manager document first
      final amDoc = await _accountManagersCollection.doc(id).get();
      if (!amDoc.exists) {
        throw Exception('Account Manager not found');
      }

      final amData = amDoc.data() as Map<String, dynamic>;

      // Double-check no assigned companies
      final assignedCompanies = amData['assignedCompanies'] as List<dynamic>? ?? [];
      if (assignedCompanies.isNotEmpty) {
        throw Exception('Cannot delete Account Manager with ${assignedCompanies.length} assigned companies. Please reassign all companies first.');
      }

      // Delete the user document from users collection
      await _usersCollection.doc(id).delete();

      // Delete the Account Manager document
      await _accountManagersCollection.doc(id).delete();

      print('Account Manager deleted successfully: $id');
    } catch (e) {
      print('Error deleting Account Manager: $e');
      rethrow;
    }
  }

  /// Get Account Managers with capacity (for assignment)
  Future<List<AccountManager>> getAccountManagersWithCapacity() async {
    try {
      QuerySnapshot snapshot = await _accountManagersCollection
          .where('status', isEqualTo: 'active')
          .get();

      List<AccountManager> ams = snapshot.docs
          .map((doc) => AccountManager.fromFirestore(doc))
          .where((am) => !am.isAtCapacity)
          .toList();

      // Sort by current capacity (least loaded first)
      ams.sort((a, b) => a.assignedCount.compareTo(b.assignedCount));

      return ams;
    } catch (e) {
      throw Exception('Failed to get Account Managers: $e');
    }
  }

  /// Auto-assign company to Account Manager with least load
  Future<void> autoAssignCompany(String companyId) async {
    try {
      List<AccountManager> availableAMs = await getAccountManagersWithCapacity();

      if (availableAMs.isEmpty) {
        throw Exception('No Account Managers available with capacity');
      }

      // Assign to AM with least customers
      await assignCompanyToManager(
        accountManagerId: availableAMs.first.id,
        companyId: companyId,
      );
    } catch (e) {
      throw Exception('Failed to auto-assign company: $e');
    }
  }

  /// Request company deletion (AM submits request to Super Admin)
  Future<void> requestCompanyDeletion({
    required String companyId,
    required String companyName,
    required String accountManagerId,
    required String reason,
  }) async {
    try {
      // Get Account Manager details
      final am = await getAccountManager(accountManagerId);
      if (am == null) {
        throw Exception('Account Manager not found');
      }

      // Create deletion request
      await _firestore.collection('deletionRequests').add({
        'type': 'company',
        'companyId': companyId,
        'companyName': companyName,
        'requestedBy': {
          'id': accountManagerId,
          'name': am.displayName,
          'email': am.email,
          'role': 'accountManager',
        },
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Deletion request created for company: $companyId');
    } catch (e) {
      print('Error creating deletion request: $e');
      rethrow;
    }
  }
}
