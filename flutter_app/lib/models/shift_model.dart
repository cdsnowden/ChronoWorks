import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftModel {
  final String id;
  final String employeeId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? notes;
  final String? location;
  final bool isPublished; // Whether the shift is published to employee
  final bool isDayOff; // Whether this is a day off
  final String? dayOffType; // 'paid', 'unpaid', 'holiday'
  final double? paidHours; // Hours to pay for paid/holiday day offs
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy; // Admin/Manager who created the shift

  ShiftModel({
    required this.id,
    required this.employeeId,
    this.startTime,
    this.endTime,
    this.notes,
    this.location,
    this.isPublished = false,
    this.isDayOff = false,
    this.dayOffType,
    this.paidHours,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Calculate shift duration in hours
  double get durationHours {
    if (isDayOff) return 0.0;
    if (startTime == null || endTime == null) return 0.0;
    final duration = endTime!.difference(startTime!);
    return duration.inMinutes / 60.0;
  }

  // Check if shift is today
  bool get isToday {
    final now = DateTime.now();
    final checkTime = startTime ?? createdAt;
    return checkTime.year == now.year &&
        checkTime.month == now.month &&
        checkTime.day == now.day;
  }

  // Check if shift is in the past
  bool get isPast {
    if (endTime == null) return false;
    return endTime!.isBefore(DateTime.now());
  }

  // Check if shift is in the future
  bool get isFuture {
    if (startTime == null) return false;
    return startTime!.isAfter(DateTime.now());
  }

  // Check if shift is currently active
  bool get isActive {
    if (startTime == null || endTime == null) return false;
    final now = DateTime.now();
    return now.isAfter(startTime!) && now.isBefore(endTime!);
  }

  // Get formatted date range
  String get formattedDate {
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
    final dateTime = startTime ?? createdAt;
    return '${months[dateTime.month]} ${dateTime.day}, ${dateTime.year}';
  }

  // Get formatted time range
  String get formattedTimeRange {
    if (isDayOff) {
      if (dayOffType == 'paid') {
        return 'Paid Day Off (${paidHours?.toStringAsFixed(1) ?? 0}h)';
      } else if (dayOffType == 'holiday') {
        return 'Holiday (${paidHours?.toStringAsFixed(1) ?? 0}h)';
      } else {
        return 'Unpaid Day Off';
      }
    }

    if (startTime == null || endTime == null) return 'N/A';

    final startHour = startTime!.hour > 12 ? startTime!.hour - 12 : startTime!.hour;
    final startMinute = startTime!.minute.toString().padLeft(2, '0');
    final startPeriod = startTime!.hour >= 12 ? 'PM' : 'AM';

    final endHour = endTime!.hour > 12 ? endTime!.hour - 12 : endTime!.hour;
    final endMinute = endTime!.minute.toString().padLeft(2, '0');
    final endPeriod = endTime!.hour >= 12 ? 'PM' : 'AM';

    return '$startHour:$startMinute $startPeriod - $endHour:$endMinute $endPeriod';
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'notes': notes,
      'location': location,
      'isPublished': isPublished,
      'isDayOff': isDayOff,
      'dayOffType': dayOffType,
      'paidHours': paidHours,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }

  // Create from Firestore document
  factory ShiftModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ShiftModel(
      id: documentId,
      employeeId: map['employeeId'] ?? '',
      startTime: map['startTime'] != null ? (map['startTime'] as Timestamp).toDate() : null,
      endTime: map['endTime'] != null ? (map['endTime'] as Timestamp).toDate() : null,
      notes: map['notes'],
      location: map['location'],
      isPublished: map['isPublished'] ?? false,
      isDayOff: map['isDayOff'] ?? false,
      dayOffType: map['dayOffType'],
      paidHours: map['paidHours'] != null ? (map['paidHours'] as num).toDouble() : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      createdBy: map['createdBy'] ?? '',
    );
  }

  // Create from Firestore DocumentSnapshot
  factory ShiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null for shift ${doc.id}');
    }
    return ShiftModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  ShiftModel copyWith({
    String? id,
    String? employeeId,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    String? location,
    bool? isPublished,
    bool? isDayOff,
    String? dayOffType,
    double? paidHours,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      isPublished: isPublished ?? this.isPublished,
      isDayOff: isDayOff ?? this.isDayOff,
      dayOffType: dayOffType ?? this.dayOffType,
      paidHours: paidHours ?? this.paidHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'ShiftModel(id: $id, employeeId: $employeeId, date: $formattedDate, time: $formattedTimeRange)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShiftModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
