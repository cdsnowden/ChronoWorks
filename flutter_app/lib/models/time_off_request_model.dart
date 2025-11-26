import 'package:cloud_firestore/cloud_firestore.dart';

class TimeOffRequestModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final String type; // 'vacation', 'sick', 'personal', 'unpaid'
  final String? reason;
  final String status; // 'pending', 'approved', 'denied'
  final String? reviewedBy;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String companyId;

  TimeOffRequestModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.reason,
    this.status = 'pending',
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.reviewNotes,
    required this.createdAt,
    this.updatedAt,
    required this.companyId,
  });

  // Calculate number of days requested
  int get daysRequested {
    return endDate.difference(startDate).inDays + 1;
  }

  // Check if request is pending
  bool get isPending => status == 'pending';

  // Check if request is approved
  bool get isApproved => status == 'approved';

  // Check if request is denied
  bool get isDenied => status == 'denied';

  // Check if request is in the past
  bool get isPast => endDate.isBefore(DateTime.now());

  // Check if request is upcoming
  bool get isUpcoming => startDate.isAfter(DateTime.now());

  // Check if request is currently active
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  // Get formatted date range
  String get formattedDateRange {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      // Single day
      return '${months[startDate.month]} ${startDate.day}, ${startDate.year}';
    } else if (startDate.year == endDate.year && startDate.month == endDate.month) {
      // Same month
      return '${months[startDate.month]} ${startDate.day}-${endDate.day}, ${startDate.year}';
    } else if (startDate.year == endDate.year) {
      // Same year, different months
      return '${months[startDate.month]} ${startDate.day} - ${months[endDate.month]} ${endDate.day}, ${startDate.year}';
    } else {
      // Different years
      return '${months[startDate.month]} ${startDate.day}, ${startDate.year} - ${months[endDate.month]} ${endDate.day}, ${endDate.year}';
    }
  }

  // Get user-friendly type label
  String get typeLabel {
    switch (type) {
      case 'paid':
        return 'Paid Time Off';
      case 'unpaid':
        return 'Unpaid Leave';
      case 'vacation':
        return 'Vacation';
      case 'sick':
        return 'Sick Leave';
      case 'personal':
        return 'Personal Day';
      default:
        return type;
    }
  }

  // Get user-friendly status label
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'denied':
        return 'Denied';
      default:
        return status;
    }
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'type': type,
      'reason': reason,
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewerName': reviewerName,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewNotes': reviewNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'companyId': companyId,
    };
  }

  // Create from Firestore document
  factory TimeOffRequestModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TimeOffRequestModel(
      id: documentId,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      type: map['type'] ?? 'personal',
      reason: map['reason'],
      status: map['status'] ?? 'pending',
      reviewedBy: map['reviewedBy'],
      reviewerName: map['reviewerName'],
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewNotes: map['reviewNotes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      companyId: map['companyId'] ?? '',
    );
  }

  // Create from Firestore DocumentSnapshot
  factory TimeOffRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null for time off request ${doc.id}');
    }
    return TimeOffRequestModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  TimeOffRequestModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? reason,
    String? status,
    String? reviewedBy,
    String? reviewerName,
    DateTime? reviewedAt,
    String? reviewNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? companyId,
  }) {
    return TimeOffRequestModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyId: companyId ?? this.companyId,
    );
  }

  @override
  String toString() {
    return 'TimeOffRequestModel(id: $id, employeeId: $employeeId, type: $type, dates: $formattedDateRange, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TimeOffRequestModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
