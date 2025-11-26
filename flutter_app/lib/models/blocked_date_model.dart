import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedDate {
  final String id;
  final String companyId;
  final DateTime date;
  final String reason;
  final String createdBy; // Admin who created this block
  final DateTime createdAt;

  BlockedDate({
    required this.id,
    required this.companyId,
    required this.date,
    required this.reason,
    required this.createdBy,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'date': Timestamp.fromDate(date),
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory BlockedDate.fromMap(Map<String, dynamic> map, String documentId) {
    return BlockedDate(
      id: documentId,
      companyId: map['companyId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      reason: map['reason'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Create from Firestore DocumentSnapshot
  factory BlockedDate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedDate.fromMap(data, doc.id);
  }

  // Copy with method for updates
  BlockedDate copyWith({
    String? id,
    String? companyId,
    DateTime? date,
    String? reason,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return BlockedDate(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'BlockedDate(id: $id, date: $date, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockedDate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
