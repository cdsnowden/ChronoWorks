import 'package:cloud_firestore/cloud_firestore.dart';

class TimeEntryModel {
  final String id;
  final String userId; // Employee who made this entry
  final DateTime clockInTime;
  final DateTime? clockOutTime;
  final Map<String, double>? clockInLocation; // {lat: 0.0, lng: 0.0}
  final Map<String, double>? clockOutLocation;
  final String? clockInPhotoUrl; // For facial recognition
  final String? clockOutPhotoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Map<String, dynamic>>? editHistory; // Audit trail for edits
  final bool isOffPremises; // Whether employee clocked in outside geofence

  TimeEntryModel({
    required this.id,
    required this.userId,
    required this.clockInTime,
    this.clockOutTime,
    this.clockInLocation,
    this.clockOutLocation,
    this.clockInPhotoUrl,
    this.clockOutPhotoUrl,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.editHistory,
    this.isOffPremises = false,
  });

  // Check if currently clocked in (no clock out time)
  bool get isClockedIn => clockOutTime == null;

  // Calculate total hours worked
  double get totalHours {
    if (clockOutTime == null) return 0.0;
    final duration = clockOutTime!.difference(clockInTime);
    return duration.inMinutes / 60.0;
  }

  // Get formatted duration
  String get formattedDuration {
    if (clockOutTime == null) {
      final now = DateTime.now();
      final duration = now.difference(clockInTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '${hours}h ${minutes}m (ongoing)';
    }

    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'clockInTime': Timestamp.fromDate(clockInTime),
      'clockOutTime':
          clockOutTime != null ? Timestamp.fromDate(clockOutTime!) : null,
      'clockInLocation': clockInLocation,
      'clockOutLocation': clockOutLocation,
      'clockInPhotoUrl': clockInPhotoUrl,
      'clockOutPhotoUrl': clockOutPhotoUrl,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'editHistory': editHistory,
      'isOffPremises': isOffPremises,
    };
  }

  // Create from Firestore document
  factory TimeEntryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TimeEntryModel(
      id: documentId,
      userId: map['userId'] ?? '',
      clockInTime: (map['clockInTime'] as Timestamp).toDate(),
      clockOutTime: map['clockOutTime'] != null
          ? (map['clockOutTime'] as Timestamp).toDate()
          : null,
      clockInLocation: map['clockInLocation'] != null
          ? Map<String, double>.from(map['clockInLocation'])
          : null,
      clockOutLocation: map['clockOutLocation'] != null
          ? Map<String, double>.from(map['clockOutLocation'])
          : null,
      clockInPhotoUrl: map['clockInPhotoUrl'],
      clockOutPhotoUrl: map['clockOutPhotoUrl'],
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      editHistory: map['editHistory'] != null
          ? List<Map<String, dynamic>>.from(map['editHistory'])
          : null,
      isOffPremises: map['isOffPremises'] ?? false,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory TimeEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeEntryModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  TimeEntryModel copyWith({
    String? id,
    String? userId,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    Map<String, double>? clockInLocation,
    Map<String, double>? clockOutLocation,
    String? clockInPhotoUrl,
    String? clockOutPhotoUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? editHistory,
    bool? isOffPremises,
  }) {
    return TimeEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      clockOutLocation: clockOutLocation ?? this.clockOutLocation,
      clockInPhotoUrl: clockInPhotoUrl ?? this.clockInPhotoUrl,
      clockOutPhotoUrl: clockOutPhotoUrl ?? this.clockOutPhotoUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editHistory: editHistory ?? this.editHistory,
      isOffPremises: isOffPremises ?? this.isOffPremises,
    );
  }

  @override
  String toString() {
    return 'TimeEntryModel(id: $id, userId: $userId, clockIn: $clockInTime, clockOut: $clockOutTime, hours: $totalHours)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TimeEntryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
