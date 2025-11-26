import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer_note.dart';

class CustomerNoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _notesCollection =>
      _firestore.collection('customerNotes');
  CollectionReference get _companiesCollection =>
      _firestore.collection('companies');
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Create a new customer note
  Future<String> createNote({
    required String companyId,
    required String note,
    required String noteType,
    String? relatedTicketId,
    List<String> tags = const [],
    String sentiment = 'neutral',
    bool followUpRequired = false,
    DateTime? followUpDate,
  }) async {
    try {
      // Get current user info
      String userId = _auth.currentUser!.uid;

      // Try to get user from users collection first
      DocumentSnapshot userDoc = await _usersCollection.doc(userId).get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      // If not found in users, try account managers
      if (userData == null) {
        DocumentSnapshot amDoc = await _firestore.collection('accountManagers').doc(userId).get();
        userData = amDoc.data() as Map<String, dynamic>?;
      }

      // Fallback if still not found
      if (userData == null) {
        userData = {
          'displayName': 'Unknown User',
          'email': _auth.currentUser?.email ?? 'unknown@email.com',
          'role': 'user',
        };
      }

      // Get company info
      DocumentSnapshot companyDoc =
          await _companiesCollection.doc(companyId).get();
      Map<String, dynamic>? companyData =
          companyDoc.data() as Map<String, dynamic>?;

      if (companyData == null) {
        throw Exception('Company not found');
      }

      // Create note
      CustomerNote customerNote = CustomerNote(
        id: '', // Will be set by Firestore
        companyId: companyId,
        companyName: companyData['businessName'] ?? 'Unknown Company',
        note: note,
        noteType: noteType,
        createdBy: userId,
        createdByName: userData['displayName'] ?? 'Unknown',
        createdByRole: userData['role'] ?? 'user',
        relatedTicketId: relatedTicketId,
        tags: tags,
        sentiment: sentiment,
        followUpRequired: followUpRequired,
        followUpDate: followUpDate,
        followUpCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to Firestore
      DocumentReference docRef =
          await _notesCollection.add(customerNote.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create note: $e');
    }
  }

  /// Get note by ID
  Future<CustomerNote?> getNote(String noteId) async {
    try {
      DocumentSnapshot doc = await _notesCollection.doc(noteId).get();
      if (doc.exists) {
        return CustomerNote.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get note: $e');
    }
  }

  /// Get all notes for a company
  Stream<List<CustomerNote>> getNotesForCompany(
    String companyId, {
    int limit = 50,
  }) {
    return _notesCollection
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerNote.fromFirestore(doc))
            .toList());
  }

  /// Get notes by type for a company
  Stream<List<CustomerNote>> getNotesByType(
    String companyId,
    String noteType,
  ) {
    return _notesCollection
        .where('companyId', isEqualTo: companyId)
        .where('noteType', isEqualTo: noteType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerNote.fromFirestore(doc))
            .toList());
  }

  /// Get notes requiring follow-up
  Stream<List<CustomerNote>> getNotesWithFollowUp({
    String? companyId,
    bool onlyOverdue = false,
  }) {
    Query query = _notesCollection.where('followUpRequired', isEqualTo: true).where('followUpCompleted', isEqualTo: false);

    if (companyId != null) {
      query = query.where('companyId', isEqualTo: companyId);
    }

    if (onlyOverdue) {
      query = query.where('followUpDate', isLessThan: Timestamp.now());
    }

    return query
        .orderBy('followUpDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerNote.fromFirestore(doc))
            .toList());
  }

  /// Get notes created by current user
  Stream<List<CustomerNote>> getMyNotes({int limit = 100}) {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _notesCollection
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerNote.fromFirestore(doc))
            .toList());
  }

  /// Get notes by sentiment for a company
  Stream<List<CustomerNote>> getNotesBySentiment(
    String companyId,
    String sentiment,
  ) {
    return _notesCollection
        .where('companyId', isEqualTo: companyId)
        .where('sentiment', isEqualTo: sentiment)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerNote.fromFirestore(doc))
            .toList());
  }

  /// Get notes by tag
  Stream<List<CustomerNote>> getNotesByTag(String tag) {
    return _notesCollection
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerNote.fromFirestore(doc))
            .toList());
  }

  /// Update note
  Future<void> updateNote(
    String noteId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _notesCollection.doc(noteId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update note: $e');
    }
  }

  /// Mark follow-up as completed
  Future<void> markFollowUpComplete(String noteId) async {
    try {
      await _notesCollection.doc(noteId).update({
        'followUpCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark follow-up complete: $e');
    }
  }

  /// Update follow-up date
  Future<void> updateFollowUpDate(String noteId, DateTime newDate) async {
    try {
      await _notesCollection.doc(noteId).update({
        'followUpDate': Timestamp.fromDate(newDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update follow-up date: $e');
    }
  }

  /// Add tags to note
  Future<void> addTags(String noteId, List<String> tags) async {
    try {
      await _notesCollection.doc(noteId).update({
        'tags': FieldValue.arrayUnion(tags),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add tags: $e');
    }
  }

  /// Remove tags from note
  Future<void> removeTags(String noteId, List<String> tags) async {
    try {
      await _notesCollection.doc(noteId).update({
        'tags': FieldValue.arrayRemove(tags),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to remove tags: $e');
    }
  }

  /// Update sentiment
  Future<void> updateSentiment(String noteId, String sentiment) async {
    try {
      await _notesCollection.doc(noteId).update({
        'sentiment': sentiment,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update sentiment: $e');
    }
  }

  /// Delete note
  Future<void> deleteNote(String noteId) async {
    try {
      // Only allow deletion if current user created the note or is Super Admin
      String? userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      DocumentSnapshot noteDoc = await _notesCollection.doc(noteId).get();
      if (!noteDoc.exists) throw Exception('Note not found');

      Map<String, dynamic> noteData = noteDoc.data() as Map<String, dynamic>;

      // Check if user is the creator
      if (noteData['createdBy'] != userId) {
        // Check if user is Super Admin
        DocumentSnapshot userDoc = await _usersCollection.doc(userId).get();
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        if (userData['role'] != 'super_admin') {
          throw Exception('Only the note creator or Super Admin can delete notes');
        }
      }

      await _notesCollection.doc(noteId).delete();
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }

  /// Get note statistics for a company
  Future<Map<String, dynamic>> getNoteStats(String companyId) async {
    try {
      QuerySnapshot allNotes =
          await _notesCollection.where('companyId', isEqualTo: companyId).get();

      int total = allNotes.docs.length;
      int positive = 0;
      int neutral = 0;
      int negative = 0;
      int followUpsNeeded = 0;
      int overdueFollowUps = 0;

      Map<String, int> typeCount = {};

      DateTime now = DateTime.now();

      for (var doc in allNotes.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Count by sentiment
        String sentiment = data['sentiment'] ?? 'neutral';
        if (sentiment == NoteSentiment.positive) positive++;
        if (sentiment == NoteSentiment.neutral) neutral++;
        if (sentiment == NoteSentiment.negative) negative++;

        // Count follow-ups
        if (data['followUpRequired'] == true &&
            data['followUpCompleted'] != true) {
          followUpsNeeded++;

          // Check if overdue
          if (data['followUpDate'] != null) {
            DateTime followUpDate = (data['followUpDate'] as Timestamp).toDate();
            if (followUpDate.isBefore(now)) {
              overdueFollowUps++;
            }
          }
        }

        // Count by type
        String noteType = data['noteType'] ?? 'interaction';
        typeCount[noteType] = (typeCount[noteType] ?? 0) + 1;
      }

      return {
        'total': total,
        'positive': positive,
        'neutral': neutral,
        'negative': negative,
        'followUpsNeeded': followUpsNeeded,
        'overdueFollowUps': overdueFollowUps,
        'byType': typeCount,
      };
    } catch (e) {
      throw Exception('Failed to get note stats: $e');
    }
  }

  /// Get all unique tags across all notes
  Future<List<String>> getAllTags() async {
    try {
      QuerySnapshot snapshot = await _notesCollection.get();

      Set<String> allTags = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<String> tags = List<String>.from(data['tags'] ?? []);
        allTags.addAll(tags);
      }

      List<String> tagList = allTags.toList()..sort();
      return tagList;
    } catch (e) {
      throw Exception('Failed to get all tags: $e');
    }
  }

  /// Search notes by text
  Future<List<CustomerNote>> searchNotes({
    String? companyId,
    required String searchTerm,
  }) async {
    try {
      // Note: This is a simple search. For production, consider using
      // Algolia or Elastic Search for full-text search capabilities

      Query query = _notesCollection;

      if (companyId != null) {
        query = query.where('companyId', isEqualTo: companyId);
      }

      QuerySnapshot snapshot = await query.get();

      List<CustomerNote> results = [];

      for (var doc in snapshot.docs) {
        CustomerNote note = CustomerNote.fromFirestore(doc);

        // Simple case-insensitive search in note content
        if (note.note.toLowerCase().contains(searchTerm.toLowerCase())) {
          results.add(note);
        }
      }

      // Sort by most recent
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return results;
    } catch (e) {
      throw Exception('Failed to search notes: $e');
    }
  }

  /// Quick note shortcuts for common scenarios

  /// Create an onboarding call note
  Future<String> createOnboardingNote(String companyId, String details) {
    return createNote(
      companyId: companyId,
      note: details,
      noteType: NoteType.onboardingCall,
      tags: ['onboarding'],
      sentiment: NoteSentiment.positive,
      followUpRequired: true,
      followUpDate: DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Create an upsell opportunity note
  Future<String> createUpsellOpportunity(
    String companyId,
    String opportunity,
  ) {
    return createNote(
      companyId: companyId,
      note: opportunity,
      noteType: NoteType.upsellOpportunity,
      tags: ['upsell', 'opportunity'],
      sentiment: NoteSentiment.positive,
      followUpRequired: true,
      followUpDate: DateTime.now().add(const Duration(days: 14)),
    );
  }

  /// Create a churn risk note
  Future<String> createChurnRiskNote(String companyId, String reason) {
    return createNote(
      companyId: companyId,
      note: reason,
      noteType: NoteType.churnRisk,
      tags: ['churn_risk', 'urgent'],
      sentiment: NoteSentiment.negative,
      followUpRequired: true,
      followUpDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  /// Create a success story note
  Future<String> createSuccessStory(String companyId, String story) {
    return createNote(
      companyId: companyId,
      note: story,
      noteType: NoteType.successStory,
      tags: ['success', 'case_study'],
      sentiment: NoteSentiment.positive,
      followUpRequired: false,
    );
  }
}
