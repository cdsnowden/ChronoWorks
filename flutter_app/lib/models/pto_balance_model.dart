import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of PTO transactions
enum PtoTransactionType {
  /// Initial allocation at start of year/anniversary
  accrual,
  /// PTO used (approved time off)
  used,
  /// Manual adjustment by admin
  adjustment,
  /// Carryover from previous year
  carryover,
  /// Expired/forfeited PTO
  expired,
  /// Pending request (reserved but not yet used)
  pending,
  /// Cancelled request (returns pending hours)
  cancelled,
}

/// A single PTO transaction record
class PtoTransaction {
  final String id;
  final DateTime date;
  final PtoTransactionType type;
  final double hours;
  final String? description;
  final String? timeOffRequestId;
  final String? adjustedBy; // Admin who made manual adjustment
  final DateTime createdAt;

  PtoTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.hours,
    this.description,
    this.timeOffRequestId,
    this.adjustedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'hours': hours,
      'description': description,
      'timeOffRequestId': timeOffRequestId,
      'adjustedBy': adjustedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PtoTransaction.fromMap(Map<String, dynamic> map) {
    return PtoTransaction(
      id: map['id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      type: PtoTransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PtoTransactionType.adjustment,
      ),
      hours: (map['hours'] ?? 0).toDouble(),
      description: map['description'],
      timeOffRequestId: map['timeOffRequestId'],
      adjustedBy: map['adjustedBy'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

/// Employee's PTO balance for a specific year
class PtoBalanceModel {
  final String id;
  final String employeeId;
  final String companyId;
  final int year; // The year this balance applies to

  /// Total hours available at start of year (based on policy tier)
  final double annualAllocation;

  /// Hours carried over from previous year
  final double carryoverHours;

  /// Hours accrued so far this year (for per-pay-period accrual)
  final double accruedHours;

  /// Hours used (approved time off taken)
  final double usedHours;

  /// Hours pending (awaiting approval or future approved dates)
  final double pendingHours;

  /// Hours manually adjusted by admin
  final double adjustmentHours;

  /// Hours expired/forfeited
  final double expiredHours;

  /// Transaction history
  final List<PtoTransaction> transactions;

  /// Policy ID used for this year's allocation
  final String? policyId;

  /// Employee's years of service at start of this year
  final int yearsOfServiceAtStart;

  final DateTime createdAt;
  final DateTime? updatedAt;

  PtoBalanceModel({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.year,
    required this.annualAllocation,
    this.carryoverHours = 0,
    this.accruedHours = 0,
    this.usedHours = 0,
    this.pendingHours = 0,
    this.adjustmentHours = 0,
    this.expiredHours = 0,
    this.transactions = const [],
    this.policyId,
    this.yearsOfServiceAtStart = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Total hours available to use (allocated + carryover + accrued + adjustments - used - pending - expired)
  double get availableHours {
    return annualAllocation + carryoverHours + accruedHours + adjustmentHours - usedHours - pendingHours - expiredHours;
  }

  /// Total hours earned this year (allocation + carryover + accrued + adjustments)
  double get totalEarnedHours {
    return annualAllocation + carryoverHours + accruedHours + adjustmentHours;
  }

  /// Total hours consumed (used + pending + expired)
  double get totalConsumedHours {
    return usedHours + pendingHours + expiredHours;
  }

  /// Percentage of PTO used
  double get usagePercentage {
    if (totalEarnedHours == 0) return 0;
    return (usedHours / totalEarnedHours) * 100;
  }

  /// Check if employee can request the given hours
  bool canRequest(double hours) {
    return hours <= availableHours;
  }

  /// Format hours as days (assuming 8 hours per day)
  String formatAsDays(double hours, {double hoursPerDay = 8.0}) {
    final days = hours / hoursPerDay;
    if (days == days.roundToDouble()) {
      return '${days.round()} day${days.round() == 1 ? '' : 's'}';
    }
    return '${days.toStringAsFixed(1)} days';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'companyId': companyId,
      'year': year,
      'annualAllocation': annualAllocation,
      'carryoverHours': carryoverHours,
      'accruedHours': accruedHours,
      'usedHours': usedHours,
      'pendingHours': pendingHours,
      'adjustmentHours': adjustmentHours,
      'expiredHours': expiredHours,
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'policyId': policyId,
      'yearsOfServiceAtStart': yearsOfServiceAtStart,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory PtoBalanceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PtoBalanceModel(
      id: documentId,
      employeeId: map['employeeId'] ?? '',
      companyId: map['companyId'] ?? '',
      year: map['year'] ?? DateTime.now().year,
      annualAllocation: (map['annualAllocation'] ?? 0).toDouble(),
      carryoverHours: (map['carryoverHours'] ?? 0).toDouble(),
      accruedHours: (map['accruedHours'] ?? 0).toDouble(),
      usedHours: (map['usedHours'] ?? 0).toDouble(),
      pendingHours: (map['pendingHours'] ?? 0).toDouble(),
      adjustmentHours: (map['adjustmentHours'] ?? 0).toDouble(),
      expiredHours: (map['expiredHours'] ?? 0).toDouble(),
      transactions: (map['transactions'] as List<dynamic>?)
              ?.map((t) => PtoTransaction.fromMap(t as Map<String, dynamic>))
              .toList() ??
          [],
      policyId: map['policyId'],
      yearsOfServiceAtStart: map['yearsOfServiceAtStart'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory PtoBalanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null for PTO balance ${doc.id}');
    }
    return PtoBalanceModel.fromMap(data, doc.id);
  }

  /// Create a new balance for an employee
  factory PtoBalanceModel.create({
    required String employeeId,
    required String companyId,
    required int year,
    required double annualAllocation,
    double carryoverHours = 0,
    String? policyId,
    int yearsOfServiceAtStart = 0,
  }) {
    final now = DateTime.now();
    final transactions = <PtoTransaction>[];

    // Add initial allocation transaction
    if (annualAllocation > 0) {
      transactions.add(PtoTransaction(
        id: '${employeeId}_${year}_allocation',
        date: DateTime(year, 1, 1),
        type: PtoTransactionType.accrual,
        hours: annualAllocation,
        description: 'Annual PTO allocation for $year',
        createdAt: now,
      ));
    }

    // Add carryover transaction if applicable
    if (carryoverHours > 0) {
      transactions.add(PtoTransaction(
        id: '${employeeId}_${year}_carryover',
        date: DateTime(year, 1, 1),
        type: PtoTransactionType.carryover,
        hours: carryoverHours,
        description: 'Carryover from ${year - 1}',
        createdAt: now,
      ));
    }

    return PtoBalanceModel(
      id: '${employeeId}_$year',
      employeeId: employeeId,
      companyId: companyId,
      year: year,
      annualAllocation: annualAllocation,
      carryoverHours: carryoverHours,
      transactions: transactions,
      policyId: policyId,
      yearsOfServiceAtStart: yearsOfServiceAtStart,
      createdAt: now,
    );
  }

  PtoBalanceModel copyWith({
    String? id,
    String? employeeId,
    String? companyId,
    int? year,
    double? annualAllocation,
    double? carryoverHours,
    double? accruedHours,
    double? usedHours,
    double? pendingHours,
    double? adjustmentHours,
    double? expiredHours,
    List<PtoTransaction>? transactions,
    String? policyId,
    int? yearsOfServiceAtStart,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PtoBalanceModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      companyId: companyId ?? this.companyId,
      year: year ?? this.year,
      annualAllocation: annualAllocation ?? this.annualAllocation,
      carryoverHours: carryoverHours ?? this.carryoverHours,
      accruedHours: accruedHours ?? this.accruedHours,
      usedHours: usedHours ?? this.usedHours,
      pendingHours: pendingHours ?? this.pendingHours,
      adjustmentHours: adjustmentHours ?? this.adjustmentHours,
      expiredHours: expiredHours ?? this.expiredHours,
      transactions: transactions ?? this.transactions,
      policyId: policyId ?? this.policyId,
      yearsOfServiceAtStart: yearsOfServiceAtStart ?? this.yearsOfServiceAtStart,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PtoBalanceModel(employee: $employeeId, year: $year, available: $availableHours hrs)';
  }
}
