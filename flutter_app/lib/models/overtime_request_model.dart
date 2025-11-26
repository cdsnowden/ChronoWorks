import 'package:cloud_firestore/cloud_firestore.dart';

class OvertimeRequestModel {
  final String id;
  final String shiftId; // Reference to the shift
  final String employeeId;
  final String employeeName;
  final String managerId; // Manager who created the shift
  final String managerName;
  final DateTime shiftStartTime;
  final DateTime shiftEndTime;
  final double shiftHours;
  final double weeklyHoursBeforeShift;
  final double projectedWeeklyHours;
  final double overtimeHours;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String status; // 'pending', 'approved', 'rejected'
  final String? approvedBy; // Admin ID who approved/rejected
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final bool smsNotificationSent; // Track if admin was notified via SMS

  OvertimeRequestModel({
    required this.id,
    required this.shiftId,
    required this.employeeId,
    required this.employeeName,
    required this.managerId,
    required this.managerName,
    required this.shiftStartTime,
    required this.shiftEndTime,
    required this.shiftHours,
    required this.weeklyHoursBeforeShift,
    required this.projectedWeeklyHours,
    required this.overtimeHours,
    required this.weekStartDate,
    required this.weekEndDate,
    this.status = 'pending',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    this.smsNotificationSent = false,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shiftId': shiftId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'managerId': managerId,
      'managerName': managerName,
      'shiftStartTime': Timestamp.fromDate(shiftStartTime),
      'shiftEndTime': Timestamp.fromDate(shiftEndTime),
      'shiftHours': shiftHours,
      'weeklyHoursBeforeShift': weeklyHoursBeforeShift,
      'projectedWeeklyHours': projectedWeeklyHours,
      'overtimeHours': overtimeHours,
      'weekStartDate': Timestamp.fromDate(weekStartDate),
      'weekEndDate': Timestamp.fromDate(weekEndDate),
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'smsNotificationSent': smsNotificationSent,
    };
  }

  // Create from Firestore document
  factory OvertimeRequestModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OvertimeRequestModel(
      id: documentId,
      shiftId: map['shiftId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      managerId: map['managerId'] ?? '',
      managerName: map['managerName'] ?? '',
      shiftStartTime: (map['shiftStartTime'] as Timestamp).toDate(),
      shiftEndTime: (map['shiftEndTime'] as Timestamp).toDate(),
      shiftHours: (map['shiftHours'] ?? 0.0).toDouble(),
      weeklyHoursBeforeShift: (map['weeklyHoursBeforeShift'] ?? 0.0).toDouble(),
      projectedWeeklyHours: (map['projectedWeeklyHours'] ?? 0.0).toDouble(),
      overtimeHours: (map['overtimeHours'] ?? 0.0).toDouble(),
      weekStartDate: (map['weekStartDate'] as Timestamp).toDate(),
      weekEndDate: (map['weekEndDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: map['rejectionReason'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      smsNotificationSent: map['smsNotificationSent'] ?? false,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory OvertimeRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OvertimeRequestModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  OvertimeRequestModel copyWith({
    String? id,
    String? shiftId,
    String? employeeId,
    String? employeeName,
    String? managerId,
    String? managerName,
    DateTime? shiftStartTime,
    DateTime? shiftEndTime,
    double? shiftHours,
    double? weeklyHoursBeforeShift,
    double? projectedWeeklyHours,
    double? overtimeHours,
    DateTime? weekStartDate,
    DateTime? weekEndDate,
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? createdAt,
    bool? smsNotificationSent,
  }) {
    return OvertimeRequestModel(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      shiftEndTime: shiftEndTime ?? this.shiftEndTime,
      shiftHours: shiftHours ?? this.shiftHours,
      weeklyHoursBeforeShift: weeklyHoursBeforeShift ?? this.weeklyHoursBeforeShift,
      projectedWeeklyHours: projectedWeeklyHours ?? this.projectedWeeklyHours,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      weekEndDate: weekEndDate ?? this.weekEndDate,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      smsNotificationSent: smsNotificationSent ?? this.smsNotificationSent,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  @override
  String toString() {
    return 'OvertimeRequestModel(id: $id, employee: $employeeName, overtime: ${overtimeHours.toStringAsFixed(1)}h, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OvertimeRequestModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
