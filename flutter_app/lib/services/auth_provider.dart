import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  authenticating,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _currentUser;
  String? _errorMessage;
  bool _isFirstUser = false;

  // Getters
  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isFirstUser => _isFirstUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.authenticating;

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  AuthProvider() {
    _init();
  }

  // Initialize and listen to auth state changes
  Future<void> _init() async {
    // Check if this is the first user
    try {
      _isFirstUser = await _authService.isFirstUser();
    } catch (e) {
      // If permission error, assume it's not the first user
      _isFirstUser = false;
    }
    notifyListeners();

    // Listen to Firebase auth state changes
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  // Handle auth state changes
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
    } else {
      try {
        _currentUser = await _authService.getCurrentUser();
        _status = AuthStatus.authenticated;
      } catch (e) {
        // Don't set error message here - Super Admins and Account Managers
        // don't have user documents, so this is expected to fail for them
        _status = AuthStatus.unauthenticated;
        _currentUser = null;
      }
    }
    notifyListeners();
  }

  // Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      _currentUser = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      // Don't set error message for permission errors - these are expected for
      // Super Admins and Account Managers who don't have user documents
      final errorStr = e.toString();
      if (!errorStr.toLowerCase().contains('permission')) {
        _errorMessage = errorStr.replaceAll('Exception: ', '');
      }
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  // Create first admin account
  Future<bool> createFirstAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String companyName,
    String? phoneNumber,
    String subscriptionPlan = 'free',
  }) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();

      _currentUser = await _authService.createFirstAdmin(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        companyName: companyName,
        phoneNumber: phoneNumber,
        subscriptionPlan: subscriptionPlan,
      );

      _status = AuthStatus.authenticated;
      _isFirstUser = false;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile(UserModel updatedUser) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _authService.updateUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Refresh current user data
  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Check if user has specific role
  bool hasRole(String role) {
    return _currentUser?.role == role;
  }

  // Check if user is admin
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Check if user is manager
  bool get isManager => _currentUser?.isManager ?? false;

  // Check if user is employee
  bool get isEmployee => _currentUser?.isEmployee ?? false;
}
