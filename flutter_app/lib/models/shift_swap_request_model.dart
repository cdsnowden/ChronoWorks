import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ShiftSwapRequestModel {
  final String id;
  final String requestType; // 'swap' or 'coverage'
  final String requesterId;
  final String requesterName;
  final String originalShiftId;
  final DateTime originalShiftDate;
  final String originalShiftStartTime;
  final String originalShiftEndTime;
  final String? targetEmployeeId; // null if open to anyone
  final String? targetEmployeeName;
  final String? replacementShiftId; // Only for swaps
  final DateTime? replacementShiftDate;
  final String? replacementShiftStartTime;
  final String? replacementShiftEndTime;
  final String? reason;
  final String status; // 'pending', 'approved', 'denied', 'cancelled'
  final String? reviewedBy;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String companyId;

  ShiftSwapRequestModel({
    required this.id,
    required this.requestType,
    required this.requesterId,
    required this.requesterName,
    required this.originalShiftId,
    required this.originalShiftDate,
    required this.originalShiftStartTime,
    required this.originalShiftEndTime,
    this.targetEmployeeId,
    this.targetEmployeeName,
    this.replacementShiftId,
    this.replacementShiftDate,
    this.replacementShiftStartTime,
    this.replacementShiftEndTime,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.reviewNotes,
    required this.createdAt,
    this.updatedAt,
    required this.companyId,
  });

  // Helper getters
  bool get isSwap => requestType == 'swap';
  bool get isCoverage => requestType == 'coverage';
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get isCancelled => status == 'cancelled';
  bool get isOpenRequest => targetEmployeeId == null;

  String get requestTypeLabel {
    switch (requestType) {
      case 'swap':
        return 'Shift Swap';
      case 'coverage':
        return 'Coverage Request';
      default:
        return 'Unknown';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'denied':
        return 'Denied';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String get formattedOriginalShift {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return '${dateFormat.format(originalShiftDate)} • $originalShiftStartTime - $originalShiftEndTime';
  }

  String get formattedReplacementShift {
    if (replacementShiftDate == null) return 'N/A';
    final dateFormat = DateFormat('MMM dd, yyyy');
    return '${dateFormat.format(replacementShiftDate!)} • $replacementShiftStartTime - $replacementShiftEndTime';
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestType': requestType,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'originalShiftId': originalShiftId,
      'originalShiftDate': Timestamp.fromDate(originalShiftDate),
      'originalShiftStartTime': originalShiftStartTime,
      'originalShiftEndTime': originalShiftEndTime,
      'targetEmployeeId': targetEmployeeId,
      'targetEmployeeName': targetEmployeeName,
      'replacementShiftId': replacementShiftId,
      'replacementShiftDate': replacementShiftDate != null
          ? Timestamp.fromDate(replacementShiftDate!)
          : null,
      'replacementShiftStartTime': replacementShiftStartTime,
      'replacementShiftEndTime': replacementShiftEndTime,
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
  factory ShiftSwapRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShiftSwapRequestModel(
      id: doc.id,
      requestType: data['requestType'] ?? 'coverage',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      originalShiftId: data['originalShiftId'] ?? '',
      originalShiftDate: (data['originalShiftDate'] as Timestamp).toDate(),
      originalShiftStartTime: data['originalShiftStartTime'] ?? '',
      originalShiftEndTime: data['originalShiftEndTime'] ?? '',
      targetEmployeeId: data['targetEmployeeId'],
      targetEmployeeName: data['targetEmployeeName'],
      replacementShiftId: data['replacementShiftId'],
      replacementShiftDate: data['replacementShiftDate'] != null
          ? (data['replacementShiftDate'] as Timestamp).toDate()
          : null,
      replacementShiftStartTime: data['replacementShiftStartTime'],
      replacementShiftEndTime: data['replacementShiftEndTime'],
      reason: data['reason'],
      status: data['status'] ?? 'pending',
      reviewedBy: data['reviewedBy'],
      reviewerName: data['reviewerName'],
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewNotes: data['reviewNotes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      companyId: data['companyId'] ?? '',
    );
  }

  // Create a copy with updated fields
  ShiftSwapRequestModel copyWith({
    String? id,
    String? requestType,
    String? requesterId,
    String? requesterName,
    String? originalShiftId,
    DateTime? originalShiftDate,
    String? originalShiftStartTime,
    String? originalShiftEndTime,
    String? targetEmployeeId,
    String? targetEmployeeName,
    String? replacementShiftId,
    DateTime? replacementShiftDate,
    String? replacementShiftStartTime,
    String? replacementShiftEndTime,
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
    return ShiftSwapRequestModel(
      id: id ?? this.id,
      requestType: requestType ?? this.requestType,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      originalShiftId: originalShiftId ?? this.originalShiftId,
      originalShiftDate: originalShiftDate ?? this.originalShiftDate,
      originalShiftStartTime: originalShiftStartTime ?? this.originalShiftStartTime,
      originalShiftEndTime: originalShiftEndTime ?? this.originalShiftEndTime,
      targetEmployeeId: targetEmployeeId ?? this.targetEmployeeId,
      targetEmployeeName: targetEmployeeName ?? this.targetEmployeeName,
      replacementShiftId: replacementShiftId ?? this.replacementShiftId,
      replacementShiftDate: replacementShiftDate ?? this.replacementShiftDate,
      replacementShiftStartTime:
          replacementShiftStartTime ?? this.replacementShiftStartTime,
      replacementShiftEndTime:
          replacementShiftEndTime ?? this.replacementShiftEndTime,
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
}
