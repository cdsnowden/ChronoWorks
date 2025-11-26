import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShiftTemplateModel {
  final String id;
  final String name;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final double durationHours;
  final bool hasLunchBreak; // If true, deduct 1 hour for lunch
  final bool isDayOff; // If true, this is a day off template
  final String? dayOffType; // 'paid', 'unpaid', 'holiday'
  final double? paidHours; // Hours to pay for paid/holiday day offs
  final String? createdBy; // User ID who created it
  final String? companyId; // Company ID this template belongs to (null for global templates)
  final bool isGlobal; // If true, available to all companies; if false, only to this company
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShiftTemplateModel({
    required this.id,
    required this.name,
    this.startTime,
    this.endTime,
    required this.durationHours,
    this.hasLunchBreak = false,
    this.isDayOff = false,
    this.dayOffType,
    this.paidHours,
    this.createdBy,
    this.companyId,
    this.isGlobal = false,
    required this.createdAt,
    this.updatedAt,
  });

  // Format time for display
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
    return '${_formatTime(startTime!)} - ${_formatTime(endTime!)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Convert TimeOfDay to map for Firestore
  static Map<String, int> _timeOfDayToMap(TimeOfDay time) {
    return {
      'hour': time.hour,
      'minute': time.minute,
    };
  }

  // Convert map to TimeOfDay from Firestore
  static TimeOfDay _mapToTimeOfDay(Map<String, dynamic> map) {
    return TimeOfDay(
      hour: map['hour'] as int,
      minute: map['minute'] as int,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime != null ? _timeOfDayToMap(startTime!) : null,
      'endTime': endTime != null ? _timeOfDayToMap(endTime!) : null,
      'durationHours': durationHours,
      'hasLunchBreak': hasLunchBreak,
      'isDayOff': isDayOff,
      'dayOffType': dayOffType,
      'paidHours': paidHours,
      'createdBy': createdBy,
      'companyId': companyId,
      'isGlobal': isGlobal,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore document
  factory ShiftTemplateModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ShiftTemplateModel(
      id: documentId,
      name: map['name'] ?? '',
      startTime: map['startTime'] != null ? _mapToTimeOfDay(map['startTime']) : null,
      endTime: map['endTime'] != null ? _mapToTimeOfDay(map['endTime']) : null,
      durationHours: (map['durationHours'] ?? 0.0).toDouble(),
      hasLunchBreak: map['hasLunchBreak'] ?? false,
      isDayOff: map['isDayOff'] ?? false,
      dayOffType: map['dayOffType'],
      paidHours: map['paidHours'] != null ? (map['paidHours'] as num).toDouble() : null,
      createdBy: map['createdBy'],
      companyId: map['companyId'],
      isGlobal: map['isGlobal'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory ShiftTemplateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShiftTemplateModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  ShiftTemplateModel copyWith({
    String? id,
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    double? durationHours,
    bool? hasLunchBreak,
    bool? isDayOff,
    String? dayOffType,
    double? paidHours,
    String? createdBy,
    String? companyId,
    bool? isGlobal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShiftTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationHours: durationHours ?? this.durationHours,
      hasLunchBreak: hasLunchBreak ?? this.hasLunchBreak,
      isDayOff: isDayOff ?? this.isDayOff,
      dayOffType: dayOffType ?? this.dayOffType,
      paidHours: paidHours ?? this.paidHours,
      createdBy: createdBy ?? this.createdBy,
      companyId: companyId ?? this.companyId,
      isGlobal: isGlobal ?? this.isGlobal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ShiftTemplateModel(id: $id, name: $name, time: $formattedTimeRange, hours: ${durationHours}h)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShiftTemplateModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
