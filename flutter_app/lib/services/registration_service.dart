import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/registration_request.dart';

/// Service for handling business registration submissions
class RegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submits a new business registration request
  ///
  /// Returns the created document ID on success
  /// Throws FirebaseException on failure
  Future<String> submitRegistration(RegistrationRequest request) async {
    try {
      // Validate that all required fields are present
      if (request.businessName.trim().isEmpty) {
        throw Exception('Business name is required');
      }
      if (request.ownerName.trim().isEmpty) {
        throw Exception('Owner name is required');
      }
      if (request.ownerEmail.trim().isEmpty) {
        throw Exception('Owner email is required');
      }
      if (request.ownerPhone.trim().isEmpty) {
        throw Exception('Owner phone is required');
      }

      // Create registration request document
      final docRef = await _firestore
          .collection('registrationRequests')
          .add(request.toJson());

      return docRef.id;
    } on FirebaseException catch (e) {
      throw Exception('Failed to submit registration: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during registration: $e');
    }
  }

  /// Checks if an email address is already registered
  ///
  /// Returns true if email exists in any pending, approved, or active request
  Future<bool> isEmailAlreadyRegistered(String email) async {
    try {
      final snapshot = await _firestore
          .collection('registrationRequests')
          .where('ownerEmail', isEqualTo: email.trim().toLowerCase())
          .where('status', whereIn: ['pending', 'approved'])
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      // On error, assume email might be registered to be safe
      return true;
    }
  }

  /// Gets the status of a registration request by email
  ///
  /// Returns null if no request found
  Future<RegistrationRequest?> getRegistrationByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('registrationRequests')
          .where('ownerEmail', isEqualTo: email.trim().toLowerCase())
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return RegistrationRequest.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  /// Validates registration data before submission
  ///
  /// Returns null if valid, or error message if invalid
  String? validateRegistrationData(RegistrationRequest request) {
    if (request.businessName.trim().isEmpty) {
      return 'Business name is required';
    }
    if (request.businessName.trim().length < 2) {
      return 'Business name must be at least 2 characters';
    }

    if (request.industry.trim().isEmpty) {
      return 'Industry selection is required';
    }

    if (request.numberOfEmployees <= 0) {
      return 'Number of employees must be specified';
    }

    if (request.ownerName.trim().isEmpty) {
      return 'Owner name is required';
    }
    if (request.ownerName.trim().length < 2) {
      return 'Owner name must be at least 2 characters';
    }

    if (request.ownerEmail.trim().isEmpty) {
      return 'Owner email is required';
    }
    // Basic email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(request.ownerEmail.trim())) {
      return 'Please enter a valid email address';
    }

    if (request.ownerPhone.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneDigits = request.ownerPhone.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length != 10) {
      return 'Phone number must be 10 digits';
    }

    if (request.address.street.trim().isEmpty) {
      return 'Street address is required';
    }
    if (request.address.city.trim().isEmpty) {
      return 'City is required';
    }
    if (request.address.state.trim().isEmpty) {
      return 'State is required';
    }
    if (request.address.zip.trim().isEmpty) {
      return 'ZIP code is required';
    }
    final zipDigits = request.address.zip.replaceAll(RegExp(r'\D'), '');
    if (zipDigits.length != 5) {
      return 'ZIP code must be 5 digits';
    }

    if (request.timezone.trim().isEmpty) {
      return 'Timezone is required';
    }

    // Password validation (if provided)
    if (request.password != null) {
      final password = request.password!;
      if (password.length < 8) {
        return 'Password must be at least 8 characters';
      }
      if (!password.contains(RegExp(r'[A-Z]'))) {
        return 'Password must contain at least one uppercase letter';
      }
      if (!password.contains(RegExp(r'[a-z]'))) {
        return 'Password must contain at least one lowercase letter';
      }
      if (!password.contains(RegExp(r'[0-9]'))) {
        return 'Password must contain at least one number';
      }
    }

    return null; // All validations passed
  }

  /// Normalizes registration data before submission
  ///
  /// Trims whitespace, formats phone numbers, etc.
  RegistrationRequest normalizeRegistrationData(RegistrationRequest request) {
    return request.copyWith(
      businessName: request.businessName.trim(),
      industry: request.industry.trim(),
      website: request.website?.trim(),
      ownerName: request.ownerName.trim(),
      ownerEmail: request.ownerEmail.trim().toLowerCase(),
      ownerPhone: _formatPhoneNumber(request.ownerPhone),
      jobTitle: request.jobTitle?.trim(),
      address: Address(
        street: request.address.street.trim(),
        city: request.address.city.trim(),
        state: request.address.state.trim(),
        zip: _formatZipCode(request.address.zip),
      ),
      timezone: request.timezone.trim(),
    );
  }

  /// Formats phone number to (XXX) XXX-XXXX format
  String _formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, 10)}';
    }
    return phone; // Return as-is if not 10 digits
  }

  /// Formats ZIP code to 5-digit format
  String _formatZipCode(String zip) {
    final digits = zip.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 5) {
      return digits.substring(0, 5);
    }
    return zip; // Return as-is if less than 5 digits
  }
}
