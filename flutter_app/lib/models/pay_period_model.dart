import 'package:cloud_firestore/cloud_firestore.dart';

class PayPeriodModel {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final String periodType; // 'weekly', 'biweekly', 'monthly'
  final bool isProcessed; // Has payroll been processed?
  final DateTime? processedAt;
  final String? processedBy; // Admin who processed it
  final DateTime createdAt;
  final DateTime? updatedAt;

  PayPeriodModel({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.periodType,
    this.isProcessed = false,
    this.processedAt,
    this.processedBy,
    required this.createdAt,
    this.updatedAt,
  });

  // Get formatted date range
  String get formattedDateRange {
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[startDate.month]} ${startDate.day} - ${months[endDate.month]} ${endDate.day}, ${endDate.year}';
  }

  // Check if a date falls within this pay period
  bool containsDate(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        date.isBefore(endDate.add(const Duration(seconds: 1)));
  }

  // Get number of days in pay period
  int get durationDays {
    return endDate.difference(startDate).inDays + 1;
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'periodType': periodType,
      'isProcessed': isProcessed,
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore document
  factory PayPeriodModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PayPeriodModel(
      id: documentId,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      periodType: map['periodType'] ?? 'biweekly',
      isProcessed: map['isProcessed'] ?? false,
      processedAt: map['processedAt'] != null ? (map['processedAt'] as Timestamp).toDate() : null,
      processedBy: map['processedBy'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory PayPeriodModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null for pay period ${doc.id}');
    }
    return PayPeriodModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  PayPeriodModel copyWith({
    String? id,
    DateTime? startDate,
    DateTime? endDate,
    String? periodType,
    bool? isProcessed,
    DateTime? processedAt,
    String? processedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayPeriodModel(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      periodType: periodType ?? this.periodType,
      isProcessed: isProcessed ?? this.isProcessed,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PayPeriodModel(id: $id, range: $formattedDateRange, type: $periodType, processed: $isProcessed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PayPeriodModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Helper method to generate pay periods
  static List<PayPeriodModel> generatePayPeriods({
    required DateTime startDate,
    required DateTime endDate,
    required String periodType,
  }) {
    final List<PayPeriodModel> periods = [];
    DateTime currentStart = startDate;

    while (currentStart.isBefore(endDate)) {
      DateTime currentEnd;

      switch (periodType) {
        case 'weekly':
          currentEnd = currentStart.add(const Duration(days: 6));
          break;
        case 'biweekly':
          currentEnd = currentStart.add(const Duration(days: 13));
          break;
        case 'monthly':
          // Add one month
          currentEnd = DateTime(
            currentStart.year,
            currentStart.month + 1,
            currentStart.day,
          ).subtract(const Duration(days: 1));
          break;
        default:
          currentEnd = currentStart.add(const Duration(days: 13)); // Default to biweekly
      }

      // Don't go past the end date
      if (currentEnd.isAfter(endDate)) {
        currentEnd = endDate;
      }

      periods.add(PayPeriodModel(
        id: '', // Will be set when saved to Firestore
        startDate: currentStart,
        endDate: currentEnd,
        periodType: periodType,
        createdAt: DateTime.now(),
      ));

      currentStart = currentEnd.add(const Duration(days: 1));
    }

    return periods;
  }

  // Get current pay period based on date and period type
  static PayPeriodModel getCurrentPayPeriod(String periodType, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (periodType) {
      case 'weekly':
        // Start of week (Sunday)
        final weekday = now.weekday % 7; // Sunday = 0
        startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday));
        endDate = startDate.add(const Duration(days: 6));
        break;

      case 'biweekly':
        // Biweekly starting from a reference date (e.g., Jan 1, 2024)
        final referenceStart = DateTime(2024, 1, 1); // Adjust this to your company's pay period start
        final daysSinceReference = now.difference(referenceStart).inDays;
        final periodsSinceReference = (daysSinceReference / 14).floor();
        startDate = referenceStart.add(Duration(days: periodsSinceReference * 14));
        endDate = startDate.add(const Duration(days: 13));
        break;

      case 'monthly':
        // Start of current month
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
        break;

      default:
        // Default to biweekly
        final referenceStart = DateTime(2024, 1, 1);
        final daysSinceReference = now.difference(referenceStart).inDays;
        final periodsSinceReference = (daysSinceReference / 14).floor();
        startDate = referenceStart.add(Duration(days: periodsSinceReference * 14));
        endDate = startDate.add(const Duration(days: 13));
    }

    return PayPeriodModel(
      id: '',
      startDate: startDate,
      endDate: endDate,
      periodType: periodType,
      createdAt: DateTime.now(),
    );
  }
}
