import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user data from Firestore
  Future<UserModel?> getCurrentUser() async {
    try {
      final firebaseUser = currentFirebaseUser;
      if (firebaseUser == null) return null;

      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      ErrorHandler.logError(e, null);
      return null;
    }
  }

  // Check if this is the first user (no admin exists)
  Future<bool> isFirstUser() async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('role', isEqualTo: UserRoles.admin)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      ErrorHandler.logError(e, null);
      return false;
    }
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Get user data from Firestore (users collection)
      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(userCredential.user!.uid)
          .get();

      if (!doc.exists) {
        // Check if this is an Account Manager
        final amDoc = await _firestore
            .collection('accountManagers')
            .doc(userCredential.user!.uid)
            .get();

        if (!amDoc.exists) {
          throw Exception('User data not found. Please contact administrator.');
        }

        // Account Manager found - create a UserModel from their data
        final amData = amDoc.data() as Map<String, dynamic>;
        final user = UserModel(
          id: userCredential.user!.uid,
          email: amData['email'] ?? email,
          firstName: amData['displayName']?.split(' ').first ?? 'Account',
          lastName: amData['displayName']?.split(' ').last ?? 'Manager',
          role: 'account_manager',
          companyId: '', // Account managers don't belong to a single company
          phoneNumber: amData['phone'],
          employmentType: EmploymentTypes.fullTime,
          hourlyRate: 0.0,
          isActive: amData['status'] == 'active',
          createdAt: (amData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );

        return user;
      }

      final user = UserModel.fromFirestore(doc);

      // Check if user is active
      if (!user.isActive) {
        await signOut();
        throw Exception('Your account has been deactivated. Please contact administrator.');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(ErrorHandler.getAuthErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Create first admin account (for new company signup)
  Future<UserModel> createFirstAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String companyName,
    String? phoneNumber,
    String subscriptionPlan = 'free',
  }) async {
    try {
      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create company document first
      final companyRef = _firestore.collection('companies').doc();
      final companyId = companyRef.id;

      await companyRef.set({
        'id': companyId,
        'businessName': companyName.trim(),
        'ownerName': '${firstName.trim()} ${lastName.trim()}',
        'ownerId': uid,
        'status': 'active',
        'subscriptionPlan': subscriptionPlan,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      // Create user document in Firestore
      final user = UserModel(
        id: uid,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: UserRoles.admin,
        companyId: companyId,
        phoneNumber: phoneNumber?.trim(),
        employmentType: EmploymentTypes.fullTime,
        hourlyRate: 0.0, // Admins typically don't have hourly rate
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(FirebaseCollections.users)
          .doc(uid)
          .set(user.toMap());

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(ErrorHandler.getAuthErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Create new user account (by admin or manager)
  Future<UserModel> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    required String companyId,
    required String employmentType,
    required double hourlyRate,
    String? phoneNumber,
    String? managerId,
    Map<String, double>? workLocation,
    bool isKeyholder = false,
    DateTime? hireDate,
  }) async{
    try {
      // Validate role
      if (role != UserRoles.admin &&
          role != UserRoles.manager &&
          role != UserRoles.employee) {
        throw Exception('Invalid role specified.');
      }

      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create user document in Firestore
      final user = UserModel(
        id: uid,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
        companyId: companyId,
        phoneNumber: phoneNumber?.trim(),
        employmentType: employmentType,
        hourlyRate: hourlyRate,
        isActive: true,
        isKeyholder: isKeyholder,
        requiresPasswordChange: true, // Force password change on first login
        createdAt: DateTime.now(),
        managerId: managerId,
        workLocation: workLocation,
        hireDate: hireDate,
      );

      await _firestore
          .collection(FirebaseCollections.users)
          .doc(uid)
          .set(user.toMap());

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(ErrorHandler.getAuthErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Update user profile
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(user.id)
          .update(user.copyWith(updatedAt: DateTime.now()).toMap());
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(ErrorHandler.getAuthErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Change password (when user is logged in)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentFirebaseUser;
      if (user == null) {
        throw Exception('No user is currently signed in.');
      }

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(ErrorHandler.getAuthErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Deactivate user (soft delete)
  Future<void> deactivateUser(String userId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Reactivate user
  Future<void> reactivateUser(String userId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .update({
        'isActive': true,
        'updatedAt': Timestamp.now(),
      });
    } on FirebaseException catch (e) {
      throw Exception(ErrorHandler.getFirestoreErrorMessage(e));
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      ErrorHandler.logError(e, null);
      return null;
    }
  }

  // Get all users (for admin)
  Future<List<UserModel>> getAllUsers(String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('companyId', isEqualTo: companyId)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Sort in memory to avoid index requirement
      users.sort((a, b) => a.lastName.compareTo(b.lastName));

      return users;
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }

  // Get users by role
  Future<List<UserModel>> getUsersByRole(String role, String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('role', isEqualTo: role)
          .where('companyId', isEqualTo: companyId)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Sort in memory to avoid index requirement
      users.sort((a, b) => a.lastName.compareTo(b.lastName));

      return users;
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }

  // Get employees managed by a manager
  Future<List<UserModel>> getEmployeesByManager(String managerId, String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('managerId', isEqualTo: managerId)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Sort in memory to avoid index requirement
      users.sort((a, b) => a.lastName.compareTo(b.lastName));

      return users;
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      ErrorHandler.logError(e, null);
      throw Exception('Failed to sign out. Please try again.');
    }
  }
}
