import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import 'auth_service.dart';

class EmployeeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Get all employees (for admin)
  Stream<List<UserModel>> getAllEmployeesStream(String companyId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing a Firestore index
          users.sort((a, b) => a.lastName.compareTo(b.lastName));
          return users;
        });
  }

  // Get employees by company ID (for multi-tenant filtering)
  Stream<List<UserModel>> getEmployeesByCompanyStream(String companyId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing a Firestore index
          users.sort((a, b) => a.lastName.compareTo(b.lastName));
          return users;
        });
  }

  // Get employees by role
  Stream<List<UserModel>> getEmployeesByRoleStream(String role, String companyId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .where('role', isEqualTo: role)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing a Firestore index
          users.sort((a, b) => a.lastName.compareTo(b.lastName));
          return users;
        });
  }

  // Get active employees only
  Stream<List<UserModel>> getActiveEmployeesStream(String companyId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .where('isActive', isEqualTo: true)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing a Firestore index
          users.sort((a, b) => a.lastName.compareTo(b.lastName));
          return users;
        });
  }

  // Get employees managed by a specific manager
  Stream<List<UserModel>> getEmployeesByManagerStream(String managerId, String companyId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .where('managerId', isEqualTo: managerId)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing a Firestore index
          users.sort((a, b) => a.lastName.compareTo(b.lastName));
          return users;
        });
  }

  // Get single employee by ID
  Future<UserModel?> getEmployeeById(String employeeId) async {
    try {
      return await _authService.getUserById(employeeId);
    } catch (e) {
      ErrorHandler.logError(e, null);
      return null;
    }
  }

  // Create new employee
  Future<UserModel> createEmployee({
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
  }) async {
    try {
      final user = await _authService.createUser(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        companyId: companyId,
        employmentType: employmentType,
        hourlyRate: hourlyRate,
        phoneNumber: phoneNumber,
        managerId: managerId,
        workLocation: workLocation,
        isKeyholder: isKeyholder,
      );

      // Send welcome email to employees
      if (role == UserRoles.employee) {
        try {
          final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('sendNewEmployeeWelcome');

          await callable.call({
            'userId': user.id,
            'temporaryPassword': password,
          });
        } catch (emailError) {
          // Log error but don't fail the employee creation
          ErrorHandler.logError(emailError, null);
          // The employee was created successfully, just the email failed
        }
      }

      return user;
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Update employee
  Future<void> updateEmployee(UserModel employee) async {
    try {
      await _authService.updateUser(employee);
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Deactivate employee (soft delete)
  Future<void> deactivateEmployee(String employeeId) async {
    try {
      await _authService.deactivateUser(employeeId);
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Reactivate employee
  Future<void> reactivateEmployee(String employeeId) async {
    try {
      await _authService.reactivateUser(employeeId);
    } catch (e) {
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  // Get all managers (for assigning to employees)
  Future<List<UserModel>> getManagers(String companyId) async {
    try {
      return await _authService.getUsersByRole(UserRoles.manager, companyId);
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }

  // Search employees by name
  Future<List<UserModel>> searchEmployees(String query, String companyId) async {
    try {
      final allEmployees = await _authService.getAllUsers(companyId);
      final lowerQuery = query.toLowerCase();

      return allEmployees.where((employee) {
        final fullName = employee.fullName.toLowerCase();
        final email = employee.email.toLowerCase();
        return fullName.contains(lowerQuery) || email.contains(lowerQuery);
      }).toList();
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }

  // Get employee statistics
  Future<Map<String, int>> getEmployeeStats(String companyId) async {
    try {
      final allEmployees = await _authService.getAllUsers(companyId);

      return {
        'total': allEmployees.length,
        'active': allEmployees.where((e) => e.isActive).length,
        'inactive': allEmployees.where((e) => !e.isActive).length,
        'admins': allEmployees.where((e) => e.role == UserRoles.admin).length,
        'managers':
            allEmployees.where((e) => e.role == UserRoles.manager).length,
        'employees':
            allEmployees.where((e) => e.role == UserRoles.employee).length,
        'fullTime': allEmployees
            .where((e) => e.employmentType == EmploymentTypes.fullTime)
            .length,
        'partTime': allEmployees
            .where((e) => e.employmentType == EmploymentTypes.partTime)
            .length,
      };
    } catch (e) {
      ErrorHandler.logError(e, null);
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'admins': 0,
        'managers': 0,
        'employees': 0,
        'fullTime': 0,
        'partTime': 0,
      };
    }
  }

  // Upload profile image (placeholder for now)
  Future<String?> uploadProfileImage(String employeeId, String imagePath) async {
    // TODO: Implement Firebase Storage upload
    // This will be implemented when we add image upload functionality
    return null;
  }

  // Upload face image for recognition (placeholder for now)
  Future<String?> uploadFaceImage(String employeeId, String imagePath) async {
    // TODO: Implement Firebase Storage upload
    // This will be implemented when we add facial recognition
    return null;
  }

  // Get employees by manager ID (for manager dashboard)
  Future<List<UserModel>> getEmployeesByManagerId(String managerId, String companyId) async {
    try {
      // Fetch without ordering to avoid index requirement
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('managerId', isEqualTo: managerId)
          .where('companyId', isEqualTo: companyId)
          .get();

      final employees = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((employee) => employee.role == UserRoles.employee)
          .toList();

      // Sort in memory
      employees.sort((a, b) => a.lastName.compareTo(b.lastName));

      return employees;
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }

  // Get all employees (for admin/manager use)
  Future<List<UserModel>> getAllEmployees(String companyId) async {
    try {
      // Fetch all users without ordering to avoid index requirement
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('companyId', isEqualTo: companyId)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Sort in memory instead of in Firestore query
      users.sort((a, b) => a.lastName.compareTo(b.lastName));

      return users;
    } catch (e) {
      ErrorHandler.logError(e, null);
      return [];
    }
  }
}
