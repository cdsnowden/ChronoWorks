import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blocked_date_model.dart';

class BlockedDatesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'blockedDates';

  // Create a new blocked date
  Future<BlockedDate> createBlockedDate({
    required String companyId,
    required DateTime date,
    required String reason,
    required String createdBy,
  }) async {
    try {
      // Check if date is already blocked
      final existing = await isDateBlocked(companyId: companyId, date: date);
      if (existing) {
        throw Exception('This date is already blocked');
      }

      final docRef = _firestore.collection(_collection).doc();

      // Normalize date to start of day (remove time portion)
      final normalizedDate = DateTime(date.year, date.month, date.day);

      final blockedDate = BlockedDate(
        id: docRef.id,
        companyId: companyId,
        date: normalizedDate,
        reason: reason,
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await docRef.set(blockedDate.toMap());
      return blockedDate;
    } catch (e) {
      throw Exception('Failed to create blocked date: $e');
    }
  }

  // Create multiple blocked dates (e.g., for holidays or range)
  Future<List<BlockedDate>> createBlockedDateRange({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String createdBy,
  }) async {
    try {
      if (endDate.isBefore(startDate)) {
        throw Exception('End date must be after start date');
      }

      final blockedDates = <BlockedDate>[];
      DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day);

      while (currentDate.isBefore(normalizedEndDate) ||
             currentDate.isAtSameMomentAs(normalizedEndDate)) {
        // Check if date is already blocked
        final existing = await isDateBlocked(companyId: companyId, date: currentDate);

        if (!existing) {
          final docRef = _firestore.collection(_collection).doc();

          final blockedDate = BlockedDate(
            id: docRef.id,
            companyId: companyId,
            date: currentDate,
            reason: reason,
            createdBy: createdBy,
            createdAt: DateTime.now(),
          );

          await docRef.set(blockedDate.toMap());
          blockedDates.add(blockedDate);
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      return blockedDates;
    } catch (e) {
      throw Exception('Failed to create blocked date range: $e');
    }
  }

  // Delete a blocked date
  Future<void> deleteBlockedDate(String blockedDateId) async {
    try {
      await _firestore.collection(_collection).doc(blockedDateId).delete();
    } catch (e) {
      throw Exception('Failed to delete blocked date: $e');
    }
  }

  // Delete multiple blocked dates
  Future<void> deleteBlockedDates(List<String> blockedDateIds) async {
    try {
      final batch = _firestore.batch();

      for (final id in blockedDateIds) {
        batch.delete(_firestore.collection(_collection).doc(id));
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete blocked dates: $e');
    }
  }

  // Check if a specific date is blocked
  Future<bool> isDateBlocked({
    required String companyId,
    required DateTime date,
  }) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('date', isEqualTo: Timestamp.fromDate(normalizedDate))
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check if date is blocked: $e');
    }
  }

  // Check if any dates in a range are blocked
  Future<List<DateTime>> getBlockedDatesInRange({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final blockedDates = await getBlockedDates(companyId);

      final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

      return blockedDates
          .where((blocked) =>
              (blocked.date.isAfter(normalizedStart) ||
               blocked.date.isAtSameMomentAs(normalizedStart)) &&
              (blocked.date.isBefore(normalizedEnd) ||
               blocked.date.isAtSameMomentAs(normalizedEnd)))
          .map((blocked) => blocked.date)
          .toList();
    } catch (e) {
      throw Exception('Failed to get blocked dates in range: $e');
    }
  }

  // Get all blocked dates for a company
  Future<List<BlockedDate>> getBlockedDates(String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .orderBy('date', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => BlockedDate.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get blocked dates: $e');
    }
  }

  // Get blocked dates as a stream
  Stream<List<BlockedDate>> getBlockedDatesStream(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BlockedDate.fromFirestore(doc))
          .toList();
    });
  }

  // Get upcoming blocked dates (future dates only)
  Future<List<BlockedDate>> getUpcomingBlockedDates(String companyId) async {
    try {
      final now = DateTime.now();
      final normalizedNow = DateTime(now.year, now.month, now.day);

      final allBlocked = await getBlockedDates(companyId);

      return allBlocked
          .where((blocked) =>
              blocked.date.isAfter(normalizedNow) ||
              blocked.date.isAtSameMomentAs(normalizedNow))
          .toList();
    } catch (e) {
      throw Exception('Failed to get upcoming blocked dates: $e');
    }
  }

  // Get past blocked dates
  Future<List<BlockedDate>> getPastBlockedDates(String companyId) async {
    try {
      final now = DateTime.now();
      final normalizedNow = DateTime(now.year, now.month, now.day);

      final allBlocked = await getBlockedDates(companyId);

      return allBlocked
          .where((blocked) => blocked.date.isBefore(normalizedNow))
          .toList();
    } catch (e) {
      throw Exception('Failed to get past blocked dates: $e');
    }
  }

  // Get a specific blocked date by ID
  Future<BlockedDate?> getBlockedDateById(String blockedDateId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(blockedDateId).get();

      if (!doc.exists) {
        return null;
      }

      return BlockedDate.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get blocked date: $e');
    }
  }

  // Update a blocked date
  Future<void> updateBlockedDate({
    required String blockedDateId,
    DateTime? date,
    String? reason,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (date != null) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        updates['date'] = Timestamp.fromDate(normalizedDate);
      }

      if (reason != null) {
        updates['reason'] = reason;
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection(_collection)
            .doc(blockedDateId)
            .update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update blocked date: $e');
    }
  }
}
