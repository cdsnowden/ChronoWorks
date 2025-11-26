import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a customer retention task for account managers
class RetentionTask {
  final String id;
  final String companyId;
  final String companyName;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;

  final String riskType;
  final String riskLevel;
  final String riskReason;
  final DateTime? expirationDate;

  final String currentPlan;
  final int planValue;

  final String status;
  final int priority;
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedToEmail;
  final DateTime dueDate;

  final int contactAttempts;
  final DateTime? lastContactedAt;
  final List<RetentionNote> notes;

  final String? outcome;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;

  final DateTime createdAt;
  final DateTime updatedAt;

  final int daysAsCustomer;

  RetentionTask({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.riskType,
    required this.riskLevel,
    required this.riskReason,
    this.expirationDate,
    required this.currentPlan,
    required this.planValue,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.assignedToName,
    this.assignedToEmail,
    required this.dueDate,
    required this.contactAttempts,
    this.lastContactedAt,
    required this.notes,
    this.outcome,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.daysAsCustomer,
  });

  factory RetentionTask.fromJson(Map<String, dynamic> json) {
    return RetentionTask(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      companyName: json['companyName'] as String,
      ownerName: json['ownerName'] as String,
      ownerEmail: json['ownerEmail'] as String,
      ownerPhone: json['ownerPhone'] as String? ?? '',
      riskType: json['riskType'] as String,
      riskLevel: json['riskLevel'] as String,
      riskReason: json['riskReason'] as String,
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      currentPlan: json['currentPlan'] as String,
      planValue: json['planValue'] as int? ?? 0,
      status: json['status'] as String,
      priority: json['priority'] as int,
      assignedTo: json['assignedTo'] as String?,
      assignedToName: json['assignedToName'] as String?,
      assignedToEmail: json['assignedToEmail'] as String?,
      dueDate: DateTime.parse(json['dueDate'] as String),
      contactAttempts: json['contactAttempts'] as int? ?? 0,
      lastContactedAt: json['lastContactedAt'] != null
          ? DateTime.parse(json['lastContactedAt'] as String)
          : null,
      notes: (json['notes'] as List<dynamic>?)
              ?.map((n) => RetentionNote.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      outcome: json['outcome'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      resolvedBy: json['resolvedBy'] as String?,
      resolutionNotes: json['resolutionNotes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      daysAsCustomer: json['daysAsCustomer'] as int? ?? 0,
    );
  }

  /// Gets the number of days until expiration (negative if expired)
  int get daysUntilExpiration {
    if (expirationDate == null) return 0;
    return expirationDate!.difference(DateTime.now()).inDays;
  }

  /// Gets the number of days until due date (negative if overdue)
  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }

  /// Returns true if task is overdue
  bool get isOverdue => daysUntilDue < 0;

  /// Returns true if task is due today
  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today == due;
  }

  /// Gets priority color
  PriorityColor get priorityColor {
    switch (priority) {
      case 1:
        return PriorityColor.urgent;
      case 2:
        return PriorityColor.high;
      case 3:
        return PriorityColor.medium;
      default:
        return PriorityColor.low;
    }
  }

  /// Gets risk level color
  RiskColor get riskColor {
    switch (riskLevel) {
      case 'urgent':
        return RiskColor.urgent;
      case 'critical':
        return RiskColor.critical;
      case 'high':
        return RiskColor.high;
      case 'medium':
        return RiskColor.medium;
      default:
        return RiskColor.low;
    }
  }
}

/// Represents a note on a retention task
class RetentionNote {
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String note;
  final int callDuration;
  final String? callOutcome;

  RetentionNote({
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.note,
    required this.callDuration,
    this.callOutcome,
  });

  factory RetentionNote.fromJson(Map<String, dynamic> json) {
    return RetentionNote(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      note: json['note'] as String,
      callDuration: json['callDuration'] as int? ?? 0,
      callOutcome: json['callOutcome'] as String?,
    );
  }
}

/// Priority color enum
enum PriorityColor {
  urgent,
  high,
  medium,
  low,
}

/// Risk color enum
enum RiskColor {
  urgent,
  critical,
  high,
  medium,
  low,
}

/// Dashboard metrics
class RetentionMetrics {
  final int urgent;
  final int todayTasks;
  final int overdue;
  final int saveRate;
  final int avgValue;
  final int totalAtRisk;

  RetentionMetrics({
    required this.urgent,
    required this.todayTasks,
    required this.overdue,
    required this.saveRate,
    required this.avgValue,
    required this.totalAtRisk,
  });

  factory RetentionMetrics.fromJson(Map<String, dynamic> json) {
    return RetentionMetrics(
      urgent: json['urgent'] as int? ?? 0,
      todayTasks: json['todayTasks'] as int? ?? 0,
      overdue: json['overdue'] as int? ?? 0,
      saveRate: json['saveRate'] as int? ?? 0,
      avgValue: json['avgValue'] as int? ?? 0,
      totalAtRisk: json['totalAtRisk'] as int? ?? 0,
    );
  }
}
