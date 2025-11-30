import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';

/// Service for face recognition using Cloud Functions
/// Works on both mobile and web platforms
class FaceRecognitionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register a user's face (called during profile setup)
  Future<void> registerFace({
    required String userId,
    required String companyId,
    required dynamic imageFile, // Can be File (mobile) or XFile (web)
  }) async {
    try {
      // Convert image to base64
      Uint8List imageBytes;

      if (kIsWeb) {
        // On web, imageFile is XFile
        if (imageFile is XFile) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('Invalid image type for web');
        }
      } else {
        // On mobile, imageFile can be File or XFile
        if (imageFile is File) {
          imageBytes = await imageFile.readAsBytes();
        } else if (imageFile is XFile) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('Invalid image type for mobile');
        }
      }

      final base64Image = base64Encode(imageBytes);

      // Call Cloud Function
      final callable = _functions.httpsCallable('registerFace');
      final result = await callable.call({
        'userId': userId,
        'companyId': companyId,
        'imageBase64': base64Image,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to register face');
      }

      debugPrint('Face registered successfully for user $userId');
    } catch (e) {
      debugPrint('Error registering face: $e');
      if (e is FirebaseFunctionsException) {
        throw Exception(e.message ?? 'Failed to register face');
      }
      rethrow;
    }
  }

  /// Verify a user's face against their registered face
  Future<FaceVerificationResult> verifyFace({
    required String userId,
    required dynamic imageFile, // Can be File (mobile) or XFile (web)
  }) async {
    try {
      // Convert image to base64
      Uint8List imageBytes;

      if (kIsWeb) {
        if (imageFile is XFile) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('Invalid image type for web');
        }
      } else {
        if (imageFile is File) {
          imageBytes = await imageFile.readAsBytes();
        } else if (imageFile is XFile) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('Invalid image type for mobile');
        }
      }

      final base64Image = base64Encode(imageBytes);

      // Call Cloud Function
      final callable = _functions.httpsCallable('verifyFace');
      final result = await callable.call({
        'userId': userId,
        'imageBase64': base64Image,
      });

      final data = result.data as Map<String, dynamic>;

      return FaceVerificationResult(
        isMatch: data['isMatch'] ?? false,
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
        error: data['error'] as String?,
      );
    } catch (e) {
      debugPrint('Error verifying face: $e');
      if (e is FirebaseFunctionsException) {
        return FaceVerificationResult(
          isMatch: false,
          confidence: 0,
          error: e.message ?? 'Face verification failed',
        );
      }
      return FaceVerificationResult(
        isMatch: false,
        confidence: 0,
        error: e.toString(),
      );
    }
  }

  /// Check if user has face registered
  Future<bool> hasFaceRegistered(String userId) async {
    try {
      // First try Cloud Function
      final callable = _functions.httpsCallable('hasFaceRegistered');
      final result = await callable.call({'userId': userId});
      final data = result.data as Map<String, dynamic>;
      return data['hasRegistered'] ?? false;
    } catch (e) {
      debugPrint('Error checking face registration via function: $e');
      // Fallback to direct Firestore check
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        return userData?['faceRegistered'] == true &&
               userData?['faceDescriptor'] != null;
      } catch (firestoreError) {
        debugPrint('Firestore fallback error: $firestoreError');
        return false;
      }
    }
  }

  /// Send violation notification to managers and admins
  Future<void> sendViolationNotification({
    required String userId,
    required String companyId,
    required String violationType,
    required double confidence,
    String? photoUrl,
  }) async {
    try {
      // Get user info
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final firstName = userData?['firstName'] ?? '';
      final lastName = userData?['lastName'] ?? '';
      final userName = '$firstName $lastName'.trim();

      // Create notification
      final notification = {
        'type': 'face_verification_violation',
        'userId': userId,
        'userName': userName.isNotEmpty ? userName : 'Unknown',
        'companyId': companyId,
        'violationType': violationType,
        'confidence': confidence,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      };

      // Get managers and admins for this company
      final managersAndAdmins = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .where('role', whereIn: ['admin', 'manager'])
          .get();

      // Send notification to each
      final batch = _firestore.batch();
      for (final doc in managersAndAdmins.docs) {
        final notificationRef = _firestore
            .collection('users')
            .doc(doc.id)
            .collection('notifications')
            .doc();
        batch.set(notificationRef, notification);
      }

      // Also add to company-wide violations log
      final violationRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('faceViolations')
          .doc();
      batch.set(violationRef, notification);

      await batch.commit();
    } catch (e) {
      debugPrint('Error sending violation notification: $e');
    }
  }

  void dispose() {
    // No cleanup needed for cloud-based service
  }
}

/// Result of face verification
class FaceVerificationResult {
  final bool isMatch;
  final double confidence;
  final String? error;

  FaceVerificationResult({
    required this.isMatch,
    required this.confidence,
    this.error,
  });
}
