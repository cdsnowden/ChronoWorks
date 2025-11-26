import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionTokenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a secure random token
  String _generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Creates a subscription change token for a company
  /// Returns the token string that can be used in the URL
  Future<String> createSubscriptionToken({
    required String companyId,
    required String createdBy,
    int validityHours = 72, // Default: 72 hours (3 days)
  }) async {
    try {
      final token = _generateToken();
      final now = DateTime.now();
      final expiresAt = now.add(Duration(hours: validityHours));

      await _firestore.collection('subscriptionChangeTokens').doc(token).set({
        'token': token,
        'companyId': companyId,
        'createdBy': createdBy, // Account Manager UID
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'used': false,
        'usedAt': null,
        'usedBy': null,
      });

      return token;
    } catch (e) {
      throw Exception('Failed to create subscription token: $e');
    }
  }

  /// Validates a subscription token and returns company info if valid
  /// Returns null if token is invalid, expired, or already used
  Future<Map<String, dynamic>?> validateToken(String token) async {
    try {
      final tokenDoc = await _firestore
          .collection('subscriptionChangeTokens')
          .doc(token)
          .get();

      if (!tokenDoc.exists) {
        return null; // Token doesn't exist
      }

      final data = tokenDoc.data()!;
      final used = data['used'] as bool;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final now = DateTime.now();

      // Check if token is already used
      if (used) {
        return null;
      }

      // Check if token is expired
      if (now.isAfter(expiresAt)) {
        return null;
      }

      // Token is valid, return company info
      final companyId = data['companyId'] as String;
      final companyDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) {
        return null;
      }

      return {
        'token': token,
        'companyId': companyId,
        'companyData': companyDoc.data(),
        'expiresAt': expiresAt,
      };
    } catch (e) {
      print('Error validating token: $e');
      return null;
    }
  }

  /// Marks a token as used after successful subscription change
  Future<void> markTokenAsUsed(String token, String userId) async {
    try {
      await _firestore.collection('subscriptionChangeTokens').doc(token).update({
        'used': true,
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': userId,
      });
    } catch (e) {
      throw Exception('Failed to mark token as used: $e');
    }
  }

  /// Deletes expired tokens (cleanup function)
  /// Can be called periodically or triggered by Cloud Functions
  Future<int> deleteExpiredTokens() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('subscriptionChangeTokens')
          .where('expiresAt', isLessThan: now)
          .get();

      int deletedCount = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      return deletedCount;
    } catch (e) {
      print('Error deleting expired tokens: $e');
      return 0;
    }
  }

  /// Gets all active tokens for a company
  Future<List<Map<String, dynamic>>> getActiveTokensForCompany(String companyId) async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('subscriptionChangeTokens')
          .where('companyId', isEqualTo: companyId)
          .where('used', isEqualTo: false)
          .where('expiresAt', isGreaterThan: now)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting active tokens: $e');
      return [];
    }
  }

  /// Revokes (deletes) a specific token
  Future<void> revokeToken(String token) async {
    try {
      await _firestore.collection('subscriptionChangeTokens').doc(token).delete();
    } catch (e) {
      throw Exception('Failed to revoke token: $e');
    }
  }

  /// Generates a subscription management URL with the token
  String generateSubscriptionUrl(String token, {String? baseUrl}) {
    // In production, use your actual domain
    final domain = baseUrl ?? 'https://your-app-domain.com';
    return '$domain/subscription/manage?token=$token';
  }
}
