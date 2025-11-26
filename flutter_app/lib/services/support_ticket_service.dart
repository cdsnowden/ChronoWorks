import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/support_ticket.dart';
import 'package:uuid/uuid.dart';

class SupportTicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Collection references
  CollectionReference get _ticketsCollection =>
      _firestore.collection('supportTickets');
  CollectionReference get _companiesCollection =>
      _firestore.collection('companies');
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _accountManagersCollection =>
      _firestore.collection('accountManagers');

  /// Create a new support ticket
  Future<String> createTicket({
    required String companyId,
    required String subject,
    required String description,
    required String category,
    String priority = 'medium',
    List<String> tags = const [],
  }) async {
    try {
      // Get current user info
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await _usersCollection.doc(userId).get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Get company info
      DocumentSnapshot companyDoc =
          await _companiesCollection.doc(companyId).get();
      Map<String, dynamic> companyData =
          companyDoc.data() as Map<String, dynamic>;

      // Generate ticket number
      int year = DateTime.now().year;
      String ticketNumber = 'TKT-$year-${_uuid.v4().substring(0, 8).toUpperCase()}';

      // Create ticket
      SupportTicket ticket = SupportTicket(
        id: '', // Will be set by Firestore
        ticketNumber: ticketNumber,
        companyId: companyId,
        companyName: companyData['businessName'] ?? 'Unknown Company',
        submittedBy: TicketSubmitter(
          userId: userId,
          name: userData['displayName'] ?? 'Unknown',
          email: userData['email'] ?? '',
          role: userData['role'] ?? 'user',
        ),
        subject: subject,
        description: description,
        category: category,
        priority: priority,
        status: TicketStatus.open,
        assignedTo: null,
        assignedToName: null,
        assignedAt: null,
        resolution: null,
        resolvedAt: null,
        resolvedBy: null,
        messages: [
          TicketMessage(
            messageId: _uuid.v4(),
            from: userId,
            fromName: userData['displayName'] ?? 'Unknown',
            fromRole: userData['role'] ?? 'user',
            message: description,
            timestamp: DateTime.now(),
            attachments: [],
          )
        ],
        tags: tags,
        escalatedToSuperAdmin: false,
        escalatedAt: null,
        internalNotes: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        closedAt: null,
      );

      // Add to Firestore
      DocumentReference docRef =
          await _ticketsCollection.add(ticket.toFirestore());

      // Auto-assign to Account Manager if company has one
      if (companyData.containsKey('assignedAccountManager')) {
        String accountManagerId = companyData['assignedAccountManager']['id'];
        await assignTicket(docRef.id, accountManagerId);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create ticket: $e');
    }
  }

  /// Get ticket by ID
  Future<SupportTicket?> getTicket(String ticketId) async {
    try {
      DocumentSnapshot doc = await _ticketsCollection.doc(ticketId).get();
      if (doc.exists) {
        return SupportTicket.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get ticket: $e');
    }
  }

  /// Get tickets for a company
  Stream<List<SupportTicket>> getTicketsForCompany(
    String companyId, {
    String? status,
  }) {
    Query query = _ticketsCollection.where('companyId', isEqualTo: companyId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicket.fromFirestore(doc))
            .toList());
  }

  /// Get tickets assigned to an Account Manager
  Stream<List<SupportTicket>> getTicketsForAccountManager(
    String accountManagerId, {
    String? status,
  }) {
    Query query =
        _ticketsCollection.where('assignedTo', isEqualTo: accountManagerId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('priority')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicket.fromFirestore(doc))
            .toList());
  }

  /// Get all open tickets (Super Admin view)
  Stream<List<SupportTicket>> getAllOpenTickets() {
    return _ticketsCollection
        .where('status', whereIn: [TicketStatus.open, TicketStatus.inProgress])
        .orderBy('priority')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicket.fromFirestore(doc))
            .toList());
  }

  /// Assign ticket to Account Manager
  Future<void> assignTicket(String ticketId, String accountManagerId) async {
    try {
      // Get Account Manager info
      DocumentSnapshot amDoc =
          await _accountManagersCollection.doc(accountManagerId).get();
      Map<String, dynamic> amData = amDoc.data() as Map<String, dynamic>;

      await _ticketsCollection.doc(ticketId).update({
        'assignedTo': accountManagerId,
        'assignedToName': amData['displayName'] ?? 'Unknown',
        'assignedAt': FieldValue.serverTimestamp(),
        'status': TicketStatus.inProgress,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to assign ticket: $e');
    }
  }

  /// Unassign ticket from Account Manager
  Future<void> unassignTicket(String ticketId) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'assignedTo': FieldValue.delete(),
        'assignedToName': FieldValue.delete(),
        'assignedAt': FieldValue.delete(),
        'status': TicketStatus.open,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to unassign ticket: $e');
    }
  }

  /// Add message to ticket
  Future<void> addMessage({
    required String ticketId,
    required String message,
    List<String> attachments = const [],
  }) async {
    try {
      // Get current user info
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await _usersCollection.doc(userId).get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      TicketMessage newMessage = TicketMessage(
        messageId: _uuid.v4(),
        from: userId,
        fromName: userData['displayName'] ?? 'Unknown',
        fromRole: userData['role'] ?? 'user',
        message: message,
        timestamp: DateTime.now(),
        attachments: attachments,
      );

      await _ticketsCollection.doc(ticketId).update({
        'messages': FieldValue.arrayUnion([newMessage.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add message: $e');
    }
  }

  /// Update ticket status
  Future<void> updateTicketStatus(String ticketId, String status) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update ticket status: $e');
    }
  }

  /// Update ticket priority
  Future<void> updateTicketPriority(String ticketId, String priority) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'priority': priority,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update ticket priority: $e');
    }
  }

  /// Resolve ticket
  Future<void> resolveTicket({
    required String ticketId,
    required String resolution,
  }) async {
    try {
      String userId = _auth.currentUser!.uid;

      await _ticketsCollection.doc(ticketId).update({
        'status': TicketStatus.resolved,
        'resolution': resolution,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add resolution as a message
      await addMessage(
        ticketId: ticketId,
        message: '✅ RESOLVED: $resolution',
      );
    } catch (e) {
      throw Exception('Failed to resolve ticket: $e');
    }
  }

  /// Reopen ticket
  Future<void> reopenTicket(String ticketId) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'status': TicketStatus.open,
        'resolution': FieldValue.delete(),
        'resolvedAt': FieldValue.delete(),
        'resolvedBy': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reopen ticket: $e');
    }
  }

  /// Close ticket (final state)
  Future<void> closeTicket(String ticketId) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'status': TicketStatus.closed,
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to close ticket: $e');
    }
  }

  /// Escalate ticket to Super Admin
  Future<void> escalateToSuperAdmin({
    required String ticketId,
    String? reason,
  }) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'escalatedToSuperAdmin': true,
        'escalatedAt': FieldValue.serverTimestamp(),
        'priority': TicketPriority.urgent,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add escalation note as internal note
      if (reason != null) {
        await addInternalNote(
          ticketId: ticketId,
          note: 'ESCALATED TO SUPER ADMIN: $reason',
        );
      }

      // TODO: Send notification email to Super Admin
    } catch (e) {
      throw Exception('Failed to escalate ticket: $e');
    }
  }

  /// Add internal note (only visible to Account Managers and Super Admin)
  Future<void> addInternalNote({
    required String ticketId,
    required String note,
  }) async {
    try {
      // Get existing internal notes
      DocumentSnapshot doc = await _ticketsCollection.doc(ticketId).get();
      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      String existingNotes = data?['internalNotes'] ?? '';

      String timestamp = DateTime.now().toIso8601String();
      String userId = _auth.currentUser!.uid;
      String newNote = '[$timestamp - $userId]: $note';

      String updatedNotes = existingNotes.isEmpty
          ? newNote
          : '$existingNotes\n\n$newNote';

      await _ticketsCollection.doc(ticketId).update({
        'internalNotes': updatedNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add internal note: $e');
    }
  }

  /// Add tags to ticket
  Future<void> addTags(String ticketId, List<String> tags) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'tags': FieldValue.arrayUnion(tags),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add tags: $e');
    }
  }

  /// Remove tags from ticket
  Future<void> removeTags(String ticketId, List<String> tags) async {
    try {
      await _ticketsCollection.doc(ticketId).update({
        'tags': FieldValue.arrayRemove(tags),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to remove tags: $e');
    }
  }

  /// Get ticket statistics for Account Manager
  Future<Map<String, int>> getTicketStats(String accountManagerId) async {
    try {
      QuerySnapshot allTickets = await _ticketsCollection
          .where('assignedTo', isEqualTo: accountManagerId)
          .get();

      int total = allTickets.docs.length;
      int open = 0;
      int inProgress = 0;
      int resolved = 0;
      int urgent = 0;

      for (var doc in allTickets.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        String priority = data['priority'] ?? '';

        if (status == TicketStatus.open) open++;
        if (status == TicketStatus.inProgress) inProgress++;
        if (status == TicketStatus.resolved || status == TicketStatus.closed) {
          resolved++;
        }
        if (priority == TicketPriority.urgent) urgent++;
      }

      return {
        'total': total,
        'open': open,
        'inProgress': inProgress,
        'resolved': resolved,
        'urgent': urgent,
      };
    } catch (e) {
      throw Exception('Failed to get ticket stats: $e');
    }
  }

  /// Calculate average response time for Account Manager
  Future<double> calculateAverageResponseTime(String accountManagerId) async {
    try {
      QuerySnapshot tickets = await _ticketsCollection
          .where('assignedTo', isEqualTo: accountManagerId)
          .where('assignedAt', isNull: false)
          .get();

      if (tickets.docs.isEmpty) return 0;

      double totalHours = 0;
      int count = 0;

      for (var doc in tickets.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime createdAt = (data['createdAt'] as Timestamp).toDate();
        DateTime assignedAt = (data['assignedAt'] as Timestamp).toDate();

        Duration diff = assignedAt.difference(createdAt);
        totalHours += diff.inHours;
        count++;
      }

      return count > 0 ? totalHours / count : 0;
    } catch (e) {
      print('Failed to calculate response time: $e');
      return 0;
    }
  }

  /// Delete ticket (Super Admin only)
  Future<void> deleteTicket(String ticketId) async {
    try {
      await _ticketsCollection.doc(ticketId).delete();
    } catch (e) {
      throw Exception('Failed to delete ticket: $e');
    }
  }

  /// Get open ticket count and highest priority for a company
  Future<Map<String, dynamic>> getCompanyTicketInfo(String companyId) async {
    try {
      QuerySnapshot openTickets = await _ticketsCollection
          .where('companyId', isEqualTo: companyId)
          .where('status', whereIn: [TicketStatus.open, TicketStatus.inProgress])
          .get();

      int count = openTickets.docs.length;
      String highestPriority = 'low';

      if (count > 0) {
        // Determine highest priority
        bool hasUrgent = false;
        bool hasHigh = false;
        bool hasMedium = false;

        for (var doc in openTickets.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String priority = data['priority'] ?? 'low';

          if (priority == TicketPriority.urgent) hasUrgent = true;
          if (priority == TicketPriority.high) hasHigh = true;
          if (priority == TicketPriority.medium) hasMedium = true;
        }

        if (hasUrgent) {
          highestPriority = TicketPriority.urgent;
        } else if (hasHigh) {
          highestPriority = TicketPriority.high;
        } else if (hasMedium) {
          highestPriority = TicketPriority.medium;
        }
      }

      return {
        'count': count,
        'highestPriority': highestPriority,
      };
    } catch (e) {
      print('Failed to get company ticket info: $e');
      return {
        'count': 0,
        'highestPriority': 'low',
      };
    }
  }
}
