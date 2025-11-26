import 'package:cloud_firestore/cloud_firestore.dart';

class BreakEntryModel {
  final String id;
  final String timeEntryId; // Reference to parent time entry
  final String userId; // Employee who took this break
  final DateTime breakStartTime;
  final DateTime? breakEndTime;
  final Map<String, double>? breakStartLocation; // Lat/lng when break started
  final Map<String, double>? breakEndLocation; // Lat/lng when break ended
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BreakEntryModel({
    required this.id,
    required this.timeEntryId,
    required this.userId,
    required this.breakStartTime,
    this.breakEndTime,
    this.breakStartLocation,
    this.breakEndLocation,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  // Check if currently on break (no end time)
  bool get isOnBreak => breakEndTime == null;

  // Calculate break duration in minutes
  double get durationMinutes {
    if (breakEndTime == null) return 0.0;
    final duration = breakEndTime!.difference(breakStartTime);
    return duration.inMinutes.toDouble();
  }

  // Calculate break duration in hours
  double get durationHours {
    return durationMinutes / 60.0;
  }

  // Get formatted duration
  String get formattedDuration {
    if (breakEndTime == null) {
      final now = DateTime.now();
      final duration = now.difference(breakStartTime);
      final minutes = duration.inMinutes;
      return '$minutes min (ongoing)';
    }

    final minutes = durationMinutes.round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timeEntryId': timeEntryId,
      'userId': userId,
      'breakStartTime': Timestamp.fromDate(breakStartTime),
      'breakEndTime': breakEndTime != null ? Timestamp.fromDate(breakEndTime!) : null,
      'breakStartLocation': breakStartLocation,
      'breakEndLocation': breakEndLocation,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore document
  factory BreakEntryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BreakEntryModel(
      id: documentId,
      timeEntryId: map['timeEntryId'] ?? '',
      userId: map['userId'] ?? '',
      breakStartTime: (map['breakStartTime'] as Timestamp).toDate(),
      breakEndTime: map['breakEndTime'] != null
          ? (map['breakEndTime'] as Timestamp).toDate()
          : null,
      breakStartLocation: map['breakStartLocation'] != null
          ? Map<String, double>.from(map['breakStartLocation'])
          : null,
      breakEndLocation: map['breakEndLocation'] != null
          ? Map<String, double>.from(map['breakEndLocation'])
          : null,
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory BreakEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null for break entry ${doc.id}');
    }
    return BreakEntryModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  BreakEntryModel copyWith({
    String? id,
    String? timeEntryId,
    String? userId,
    DateTime? breakStartTime,
    DateTime? breakEndTime,
    Map<String, double>? breakStartLocation,
    Map<String, double>? breakEndLocation,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BreakEntryModel(
      id: id ?? this.id,
      timeEntryId: timeEntryId ?? this.timeEntryId,
      userId: userId ?? this.userId,
      breakStartTime: breakStartTime ?? this.breakStartTime,
      breakEndTime: breakEndTime ?? this.breakEndTime,
      breakStartLocation: breakStartLocation ?? this.breakStartLocation,
      breakEndLocation: breakEndLocation ?? this.breakEndLocation,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BreakEntryModel(id: $id, start: $breakStartTime, end: $breakEndTime, duration: ${formattedDuration})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BreakEntryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
