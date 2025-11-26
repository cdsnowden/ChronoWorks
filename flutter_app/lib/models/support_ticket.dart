import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicket {
  final String id;
  final String ticketNumber;
  final String companyId;
  final String companyName;
  final TicketSubmitter submittedBy;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? assignedAt;
  final String? resolution;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final List<TicketMessage> messages;
  final List<String> tags;
  final bool escalatedToSuperAdmin;
  final DateTime? escalatedAt;
  final String? internalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.companyId,
    required this.companyName,
    required this.submittedBy,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.assignedTo,
    this.assignedToName,
    this.assignedAt,
    this.resolution,
    this.resolvedAt,
    this.resolvedBy,
    required this.messages,
    required this.tags,
    required this.escalatedToSuperAdmin,
    this.escalatedAt,
    this.internalNotes,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
  });

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id: doc.id,
      ticketNumber: data['ticketNumber'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      submittedBy: TicketSubmitter.fromMap(data['submittedBy'] ?? {}),
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'other',
      priority: data['priority'] ?? 'medium',
      status: data['status'] ?? 'open',
      assignedTo: data['assignedTo'],
      assignedToName: data['assignedToName'],
      assignedAt: data['assignedAt']?.toDate(),
      resolution: data['resolution'],
      resolvedAt: data['resolvedAt']?.toDate(),
      resolvedBy: data['resolvedBy'],
      messages: (data['messages'] as List?)
              ?.map((m) => TicketMessage.fromMap(m))
              .toList() ??
          [],
      tags: List<String>.from(data['tags'] ?? []),
      escalatedToSuperAdmin: data['escalatedToSuperAdmin'] ?? false,
      escalatedAt: data['escalatedAt']?.toDate(),
      internalNotes: data['internalNotes'],
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      closedAt: data['closedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticketNumber': ticketNumber,
      'companyId': companyId,
      'companyName': companyName,
      'submittedBy': submittedBy.toMap(),
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedAt':
          assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'resolution': resolution,
      'resolvedAt':
          resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
      'messages': messages.map((m) => m.toMap()).toList(),
      'tags': tags,
      'escalatedToSuperAdmin': escalatedToSuperAdmin,
      'escalatedAt':
          escalatedAt != null ? Timestamp.fromDate(escalatedAt!) : null,
      'internalNotes': internalNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
    };
  }

  // Helper getters
  bool get isOpen => status == 'open' || status == 'in_progress';
  bool get isResolved => status == 'resolved' || status == 'closed';
  bool get isUrgent => priority == 'urgent';
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
  int get messageCount => messages.length;
  Duration? get responseTime => assignedAt?.difference(createdAt);
  Duration? get resolutionTime => resolvedAt?.difference(createdAt);
}

class TicketSubmitter {
  final String userId;
  final String name;
  final String email;
  final String role;

  TicketSubmitter({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory TicketSubmitter.fromMap(Map<String, dynamic> map) {
    return TicketSubmitter(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
    };
  }
}

class TicketMessage {
  final String messageId;
  final String from;
  final String fromName;
  final String fromRole;
  final String message;
  final DateTime timestamp;
  final List<String> attachments;

  TicketMessage({
    required this.messageId,
    required this.from,
    required this.fromName,
    required this.fromRole,
    required this.message,
    required this.timestamp,
    required this.attachments,
  });

  factory TicketMessage.fromMap(Map<String, dynamic> map) {
    return TicketMessage(
      messageId: map['messageId'] ?? '',
      from: map['from'] ?? '',
      fromName: map['fromName'] ?? '',
      fromRole: map['fromRole'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'from': from,
      'fromName': fromName,
      'fromRole': fromRole,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'attachments': attachments,
    };
  }

  bool get hasAttachments => attachments.isNotEmpty;
}

// Ticket categories
class TicketCategory {
  static const String technicalIssue = 'technical_issue';
  static const String howTo = 'how_to';
  static const String billing = 'billing';
  static const String featureRequest = 'feature_request';
  static const String accountManagement = 'account_management';
  static const String dataExport = 'data_export';
  static const String general = 'general';
  static const String other = 'other';

  static List<String> get all => [
        technicalIssue,
        howTo,
        billing,
        featureRequest,
        accountManagement,
        dataExport,
        general,
        other,
      ];

  static String getDisplayName(String category) {
    switch (category) {
      case technicalIssue:
        return 'Technical Issue';
      case howTo:
        return 'How To';
      case billing:
        return 'Billing';
      case featureRequest:
        return 'Feature Request';
      case accountManagement:
        return 'Account Management';
      case dataExport:
        return 'Data Export';
      case general:
        return 'General Inquiry';
      case other:
        return 'Other';
      default:
        return category;
    }
  }
}

// Ticket priorities
class TicketPriority {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String urgent = 'urgent';

  static List<String> get all => [low, medium, high, urgent];

  static String getDisplayName(String priority) {
    return priority[0].toUpperCase() + priority.substring(1);
  }
}

// Ticket statuses
class TicketStatus {
  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String waitingOnCustomer = 'waiting_on_customer';
  static const String resolved = 'resolved';
  static const String closed = 'closed';

  static List<String> get all =>
      [open, inProgress, waitingOnCustomer, resolved, closed];

  static String getDisplayName(String status) {
    switch (status) {
      case open:
        return 'Open';
      case inProgress:
        return 'In Progress';
      case waitingOnCustomer:
        return 'Waiting on Customer';
      case resolved:
        return 'Resolved';
      case closed:
        return 'Closed';
      default:
        return status;
    }
  }
}
