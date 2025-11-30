import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines how PTO is accrued
enum AccrualMethod {
  /// PTO granted as lump sum at start of year or anniversary
  annual,
  /// PTO earned each pay period
  perPayPeriod,
  /// PTO earned based on hours worked
  hoursWorked,
}

/// A tier in the PTO policy based on years of service
class PtoTier {
  /// Minimum years of service for this tier (inclusive)
  final int minYears;

  /// Maximum years of service for this tier (exclusive, null = unlimited)
  final int? maxYears;

  /// Hours of PTO earned per year at this tier
  final double annualHours;

  /// Label for this tier (e.g., "1-2 Years", "3-5 Years")
  final String label;

  PtoTier({
    required this.minYears,
    this.maxYears,
    required this.annualHours,
    required this.label,
  });

  /// Get equivalent days based on hours per day
  double getDays(double hoursPerDay) => annualHours / hoursPerDay;

  /// Get equivalent weeks based on hours per week
  double getWeeks(double hoursPerWeek) => annualHours / hoursPerWeek;

  Map<String, dynamic> toMap() {
    return {
      'minYears': minYears,
      'maxYears': maxYears,
      'annualHours': annualHours,
      'label': label,
    };
  }

  factory PtoTier.fromMap(Map<String, dynamic> map) {
    return PtoTier(
      minYears: map['minYears'] ?? 0,
      maxYears: map['maxYears'],
      annualHours: (map['annualHours'] ?? 0).toDouble(),
      label: map['label'] ?? '',
    );
  }
}

/// Company-level PTO policy configuration
class PtoPolicyModel {
  final String id;
  final String companyId;

  /// Name of this policy (e.g., "Standard PTO", "Executive PTO")
  final String name;

  /// Whether this policy is active
  final bool isActive;

  /// Whether this is the default policy for new employees
  final bool isDefault;

  /// How PTO is accrued
  final AccrualMethod accrualMethod;

  /// Tiers based on years of service
  final List<PtoTier> tiers;

  /// Hours that constitute one "day" of PTO (typically 8)
  final double hoursPerDay;

  /// Hours that constitute one "week" of PTO (typically 40)
  final double hoursPerWeek;

  /// Minimum months of employment before PTO can be used
  final int waitingPeriodMonths;

  /// Maximum hours that can be accrued (cap)
  final double? maxAccrualHours;

  /// Maximum hours that can carry over to next year
  final double? maxCarryoverHours;

  /// For hoursWorked accrual: hours of PTO earned per hour worked
  final double? accrualRatePerHour;

  /// For perPayPeriod accrual: hours of PTO earned per pay period
  /// (calculated from annual hours / pay periods per year)
  final int payPeriodsPerYear;

  /// Whether to allow negative balance (advance PTO)
  final bool allowNegativeBalance;

  /// Maximum negative balance allowed (if allowNegativeBalance is true)
  final double? maxNegativeHours;

  /// Types of time off this policy covers
  final List<String> coveredTypes; // ['vacation', 'sick', 'personal']

  /// Whether sick time is separate from vacation
  final bool separateSickTime;

  /// Annual sick hours (if separateSickTime is true)
  final double? annualSickHours;

  final DateTime createdAt;
  final DateTime? updatedAt;

  PtoPolicyModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.isActive = true,
    this.isDefault = false,
    required this.accrualMethod,
    required this.tiers,
    this.hoursPerDay = 8.0,
    this.hoursPerWeek = 40.0,
    this.waitingPeriodMonths = 0,
    this.maxAccrualHours,
    this.maxCarryoverHours,
    this.accrualRatePerHour,
    this.payPeriodsPerYear = 26, // Bi-weekly default
    this.allowNegativeBalance = false,
    this.maxNegativeHours,
    this.coveredTypes = const ['vacation', 'personal'],
    this.separateSickTime = false,
    this.annualSickHours,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get the tier for a given years of service
  PtoTier? getTierForYears(int years) {
    for (final tier in tiers) {
      if (years >= tier.minYears &&
          (tier.maxYears == null || years < tier.maxYears!)) {
        return tier;
      }
    }
    return tiers.isNotEmpty ? tiers.last : null;
  }

  /// Get annual PTO hours for given years of service
  double getAnnualHoursForYears(int years) {
    final tier = getTierForYears(years);
    return tier?.annualHours ?? 0;
  }

  /// Get PTO hours per pay period for given years of service
  double getHoursPerPayPeriod(int years) {
    final annualHours = getAnnualHoursForYears(years);
    return annualHours / payPeriodsPerYear;
  }

  /// Convert hours to days
  double hoursToDays(double hours) => hours / hoursPerDay;

  /// Convert days to hours
  double daysToHours(double days) => days * hoursPerDay;

  /// Convert hours to weeks
  double hoursToWeeks(double hours) => hours / hoursPerWeek;

  /// Format hours as days and hours string
  String formatHoursAsDays(double hours) {
    final days = (hours / hoursPerDay).floor();
    final remainingHours = hours % hoursPerDay;

    if (days == 0) {
      return '${remainingHours.toStringAsFixed(1)} hours';
    } else if (remainingHours == 0) {
      return '$days day${days == 1 ? '' : 's'}';
    } else {
      return '$days day${days == 1 ? '' : 's'}, ${remainingHours.toStringAsFixed(1)} hours';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'isActive': isActive,
      'isDefault': isDefault,
      'accrualMethod': accrualMethod.name,
      'tiers': tiers.map((t) => t.toMap()).toList(),
      'hoursPerDay': hoursPerDay,
      'hoursPerWeek': hoursPerWeek,
      'waitingPeriodMonths': waitingPeriodMonths,
      'maxAccrualHours': maxAccrualHours,
      'maxCarryoverHours': maxCarryoverHours,
      'accrualRatePerHour': accrualRatePerHour,
      'payPeriodsPerYear': payPeriodsPerYear,
      'allowNegativeBalance': allowNegativeBalance,
      'maxNegativeHours': maxNegativeHours,
      'coveredTypes': coveredTypes,
      'separateSickTime': separateSickTime,
      'annualSickHours': annualSickHours,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory PtoPolicyModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PtoPolicyModel(
      id: documentId,
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? 'Default Policy',
      isActive: map['isActive'] ?? true,
      isDefault: map['isDefault'] ?? false,
      accrualMethod: AccrualMethod.values.firstWhere(
        (e) => e.name == map['accrualMethod'],
        orElse: () => AccrualMethod.annual,
      ),
      tiers: (map['tiers'] as List<dynamic>?)
              ?.map((t) => PtoTier.fromMap(t as Map<String, dynamic>))
              .toList() ??
          [],
      hoursPerDay: (map['hoursPerDay'] ?? 8.0).toDouble(),
      hoursPerWeek: (map['hoursPerWeek'] ?? 40.0).toDouble(),
      waitingPeriodMonths: map['waitingPeriodMonths'] ?? 0,
      maxAccrualHours: map['maxAccrualHours']?.toDouble(),
      maxCarryoverHours: map['maxCarryoverHours']?.toDouble(),
      accrualRatePerHour: map['accrualRatePerHour']?.toDouble(),
      payPeriodsPerYear: map['payPeriodsPerYear'] ?? 26,
      allowNegativeBalance: map['allowNegativeBalance'] ?? false,
      maxNegativeHours: map['maxNegativeHours']?.toDouble(),
      coveredTypes: List<String>.from(map['coveredTypes'] ?? ['vacation', 'personal']),
      separateSickTime: map['separateSickTime'] ?? false,
      annualSickHours: map['annualSickHours']?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory PtoPolicyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null for PTO policy ${doc.id}');
    }
    return PtoPolicyModel.fromMap(data, doc.id);
  }

  /// Create a default policy for a new company
  factory PtoPolicyModel.createDefault(String companyId) {
    return PtoPolicyModel(
      id: '',
      companyId: companyId,
      name: 'Standard PTO Policy',
      isActive: true,
      isDefault: true,
      accrualMethod: AccrualMethod.annual,
      tiers: [
        PtoTier(
          minYears: 0,
          maxYears: 1,
          annualHours: 0, // No PTO first year
          label: 'First Year',
        ),
        PtoTier(
          minYears: 1,
          maxYears: 2,
          annualHours: 40, // 1 week (5 days)
          label: '1 Year',
        ),
        PtoTier(
          minYears: 2,
          maxYears: 5,
          annualHours: 80, // 2 weeks (10 days)
          label: '2-4 Years',
        ),
        PtoTier(
          minYears: 5,
          maxYears: 10,
          annualHours: 120, // 3 weeks (15 days)
          label: '5-9 Years',
        ),
        PtoTier(
          minYears: 10,
          maxYears: null,
          annualHours: 160, // 4 weeks (20 days)
          label: '10+ Years',
        ),
      ],
      hoursPerDay: 8.0,
      hoursPerWeek: 40.0,
      waitingPeriodMonths: 12, // 1 year waiting period
      maxAccrualHours: 240, // Max 6 weeks
      maxCarryoverHours: 40, // Can carry over 1 week
      payPeriodsPerYear: 26,
      createdAt: DateTime.now(),
    );
  }

  PtoPolicyModel copyWith({
    String? id,
    String? companyId,
    String? name,
    bool? isActive,
    bool? isDefault,
    AccrualMethod? accrualMethod,
    List<PtoTier>? tiers,
    double? hoursPerDay,
    double? hoursPerWeek,
    int? waitingPeriodMonths,
    double? maxAccrualHours,
    double? maxCarryoverHours,
    double? accrualRatePerHour,
    int? payPeriodsPerYear,
    bool? allowNegativeBalance,
    double? maxNegativeHours,
    List<String>? coveredTypes,
    bool? separateSickTime,
    double? annualSickHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PtoPolicyModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      accrualMethod: accrualMethod ?? this.accrualMethod,
      tiers: tiers ?? this.tiers,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      waitingPeriodMonths: waitingPeriodMonths ?? this.waitingPeriodMonths,
      maxAccrualHours: maxAccrualHours ?? this.maxAccrualHours,
      maxCarryoverHours: maxCarryoverHours ?? this.maxCarryoverHours,
      accrualRatePerHour: accrualRatePerHour ?? this.accrualRatePerHour,
      payPeriodsPerYear: payPeriodsPerYear ?? this.payPeriodsPerYear,
      allowNegativeBalance: allowNegativeBalance ?? this.allowNegativeBalance,
      maxNegativeHours: maxNegativeHours ?? this.maxNegativeHours,
      coveredTypes: coveredTypes ?? this.coveredTypes,
      separateSickTime: separateSickTime ?? this.separateSickTime,
      annualSickHours: annualSickHours ?? this.annualSickHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
