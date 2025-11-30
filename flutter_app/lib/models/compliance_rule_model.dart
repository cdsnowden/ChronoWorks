import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories of compliance rules
enum ComplianceCategory {
  mealBreak,
  restBreak,
  dailyOvertime,
  weeklyOvertime,
  doubleTime,
  minorHours,
  minorTiming,
  predictiveScheduling,
  splitShift,
  consecutiveDays,
}

/// Severity levels for compliance issues
enum ComplianceSeverity {
  info,       // Informational only
  warning,    // Approaching violation
  violation,  // Rule violated
  critical,   // Serious violation requiring immediate action
}

/// Enforcement actions the system can take
enum EnforcementAction {
  none,           // Just log it
  notify,         // Send notification
  warnEmployee,   // Warn employee
  warnManager,    // Alert manager
  blockAction,    // Prevent the action (e.g., block clock-in)
  forceBreak,     // Force a break to start
  requireApproval, // Require manager approval to proceed
}

/// A compliance rule that defines labor law requirements
class ComplianceRule {
  final String id;
  final String name;
  final String description;
  final ComplianceCategory category;

  // Jurisdiction
  final String jurisdiction;     // "federal", "state", "city"
  final String? state;           // "CA", "NY", etc.
  final String? city;            // "Los Angeles", "Seattle", etc.
  final List<String>? industries; // Specific industries this applies to

  // Rule parameters (varies by category)
  final double? hoursThreshold;  // Hours before rule triggers (e.g., 5 for meal break)
  final int? durationMinutes;    // Required duration (e.g., 30 min break)
  final int? warningMinutesBefore; // When to warn before violation
  final double? overtimeThreshold; // Hours for overtime (8 daily, 40 weekly)
  final double? overtimeMultiplier; // 1.5x, 2x, etc.
  final int? advanceNoticeDays;  // For predictive scheduling
  final String? timeRestriction; // For minors: "7am-7pm" or "7am-9pm summer"
  final int? maxHoursSchoolDay;  // Max hours for minors on school days
  final int? maxHoursNonSchoolDay; // Max hours for minors on non-school days
  final int? maxConsecutiveDays; // Max consecutive days allowed

  // Enforcement
  final EnforcementAction enforcementAction;
  final bool isWaivable;         // Can employee waive this (e.g., meal break in CA)
  final String? waiverRequirements; // Conditions for valid waiver

  // Metadata
  final bool isActive;
  final DateTime effectiveDate;
  final DateTime? expirationDate;
  final String? legalReference;  // Citation to actual law
  final DateTime createdAt;
  final DateTime? updatedAt;

  ComplianceRule({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.jurisdiction,
    this.state,
    this.city,
    this.industries,
    this.hoursThreshold,
    this.durationMinutes,
    this.warningMinutesBefore,
    this.overtimeThreshold,
    this.overtimeMultiplier,
    this.advanceNoticeDays,
    this.timeRestriction,
    this.maxHoursSchoolDay,
    this.maxHoursNonSchoolDay,
    this.maxConsecutiveDays,
    this.enforcementAction = EnforcementAction.notify,
    this.isWaivable = false,
    this.waiverRequirements,
    this.isActive = true,
    required this.effectiveDate,
    this.expirationDate,
    this.legalReference,
    required this.createdAt,
    this.updatedAt,
  });

  factory ComplianceRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ComplianceRule(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: ComplianceCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ComplianceCategory.mealBreak,
      ),
      jurisdiction: data['jurisdiction'] ?? 'federal',
      state: data['state'],
      city: data['city'],
      industries: data['industries'] != null
          ? List<String>.from(data['industries'])
          : null,
      hoursThreshold: (data['hoursThreshold'] as num?)?.toDouble(),
      durationMinutes: data['durationMinutes'] as int?,
      warningMinutesBefore: data['warningMinutesBefore'] as int?,
      overtimeThreshold: (data['overtimeThreshold'] as num?)?.toDouble(),
      overtimeMultiplier: (data['overtimeMultiplier'] as num?)?.toDouble(),
      advanceNoticeDays: data['advanceNoticeDays'] as int?,
      timeRestriction: data['timeRestriction'],
      maxHoursSchoolDay: data['maxHoursSchoolDay'] as int?,
      maxHoursNonSchoolDay: data['maxHoursNonSchoolDay'] as int?,
      maxConsecutiveDays: data['maxConsecutiveDays'] as int?,
      enforcementAction: EnforcementAction.values.firstWhere(
        (e) => e.name == data['enforcementAction'],
        orElse: () => EnforcementAction.notify,
      ),
      isWaivable: data['isWaivable'] ?? false,
      waiverRequirements: data['waiverRequirements'],
      isActive: data['isActive'] ?? true,
      effectiveDate: (data['effectiveDate'] as Timestamp).toDate(),
      expirationDate: data['expirationDate'] != null
          ? (data['expirationDate'] as Timestamp).toDate()
          : null,
      legalReference: data['legalReference'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category.name,
      'jurisdiction': jurisdiction,
      'state': state,
      'city': city,
      'industries': industries,
      'hoursThreshold': hoursThreshold,
      'durationMinutes': durationMinutes,
      'warningMinutesBefore': warningMinutesBefore,
      'overtimeThreshold': overtimeThreshold,
      'overtimeMultiplier': overtimeMultiplier,
      'advanceNoticeDays': advanceNoticeDays,
      'timeRestriction': timeRestriction,
      'maxHoursSchoolDay': maxHoursSchoolDay,
      'maxHoursNonSchoolDay': maxHoursNonSchoolDay,
      'maxConsecutiveDays': maxConsecutiveDays,
      'enforcementAction': enforcementAction.name,
      'isWaivable': isWaivable,
      'waiverRequirements': waiverRequirements,
      'isActive': isActive,
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'expirationDate': expirationDate != null
          ? Timestamp.fromDate(expirationDate!)
          : null,
      'legalReference': legalReference,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Get a human-readable summary of the rule
  String get summary {
    switch (category) {
      case ComplianceCategory.mealBreak:
        return '${durationMinutes}min meal break after ${hoursThreshold}hrs';
      case ComplianceCategory.restBreak:
        return '${durationMinutes}min rest break per ${hoursThreshold}hrs';
      case ComplianceCategory.dailyOvertime:
        return 'OT (${overtimeMultiplier}x) after ${overtimeThreshold}hrs/day';
      case ComplianceCategory.weeklyOvertime:
        return 'OT (${overtimeMultiplier}x) after ${overtimeThreshold}hrs/week';
      case ComplianceCategory.doubleTime:
        return 'Double time (${overtimeMultiplier}x) after ${overtimeThreshold}hrs';
      case ComplianceCategory.minorHours:
        return 'Minors: max ${maxHoursSchoolDay}hrs school days, ${maxHoursNonSchoolDay}hrs non-school';
      case ComplianceCategory.minorTiming:
        return 'Minors: work hours $timeRestriction';
      case ComplianceCategory.predictiveScheduling:
        return '${advanceNoticeDays} days advance schedule notice';
      case ComplianceCategory.splitShift:
        return 'Split shift premium required';
      case ComplianceCategory.consecutiveDays:
        return 'Max $maxConsecutiveDays consecutive days';
    }
  }
}

/// A compliance violation or warning event
class ComplianceEvent {
  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String ruleId;
  final String ruleName;
  final ComplianceCategory category;
  final ComplianceSeverity severity;
  final String description;
  final DateTime timestamp;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolution;     // "waiver_signed", "break_taken", "manager_approved"
  final Map<String, dynamic>? metadata;

  ComplianceEvent({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.ruleId,
    required this.ruleName,
    required this.category,
    required this.severity,
    required this.description,
    required this.timestamp,
    this.resolvedAt,
    this.resolvedBy,
    this.resolution,
    this.metadata,
  });

  factory ComplianceEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ComplianceEvent(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      ruleId: data['ruleId'] ?? '',
      ruleName: data['ruleName'] ?? '',
      category: ComplianceCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ComplianceCategory.mealBreak,
      ),
      severity: ComplianceSeverity.values.firstWhere(
        (e) => e.name == data['severity'],
        orElse: () => ComplianceSeverity.warning,
      ),
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      resolvedBy: data['resolvedBy'],
      resolution: data['resolution'],
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'ruleId': ruleId,
      'ruleName': ruleName,
      'category': category.name,
      'severity': severity.name,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
      'resolution': resolution,
      'metadata': metadata,
    };
  }

  bool get isResolved => resolvedAt != null;
}

/// Company-specific compliance settings
class CompanyComplianceSettings {
  final String companyId;
  final String primaryState;
  final String? primaryCity;
  final List<String> additionalStates;  // For multi-state companies
  final bool autoEnforceBreaks;
  final bool requireBreakAcknowledgment;
  final bool allowMealBreakWaivers;
  final int overtimeWarningMinutes;     // Warn X minutes before OT
  final bool requireOvertimeApproval;
  final bool trackMinorCompliance;
  final bool enablePredictiveScheduling;
  final List<String> disabledRuleIds;   // Rules admin has disabled
  final DateTime updatedAt;

  CompanyComplianceSettings({
    required this.companyId,
    required this.primaryState,
    this.primaryCity,
    this.additionalStates = const [],
    this.autoEnforceBreaks = false,
    this.requireBreakAcknowledgment = true,
    this.allowMealBreakWaivers = true,
    this.overtimeWarningMinutes = 60,
    this.requireOvertimeApproval = false,
    this.trackMinorCompliance = true,
    this.enablePredictiveScheduling = false,
    this.disabledRuleIds = const [],
    required this.updatedAt,
  });

  factory CompanyComplianceSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyComplianceSettings(
      companyId: doc.id,
      primaryState: data['primaryState'] ?? 'CA',
      primaryCity: data['primaryCity'],
      additionalStates: List<String>.from(data['additionalStates'] ?? []),
      autoEnforceBreaks: data['autoEnforceBreaks'] ?? false,
      requireBreakAcknowledgment: data['requireBreakAcknowledgment'] ?? true,
      allowMealBreakWaivers: data['allowMealBreakWaivers'] ?? true,
      overtimeWarningMinutes: data['overtimeWarningMinutes'] ?? 60,
      requireOvertimeApproval: data['requireOvertimeApproval'] ?? false,
      trackMinorCompliance: data['trackMinorCompliance'] ?? true,
      enablePredictiveScheduling: data['enablePredictiveScheduling'] ?? false,
      disabledRuleIds: List<String>.from(data['disabledRuleIds'] ?? []),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primaryState': primaryState,
      'primaryCity': primaryCity,
      'additionalStates': additionalStates,
      'autoEnforceBreaks': autoEnforceBreaks,
      'requireBreakAcknowledgment': requireBreakAcknowledgment,
      'allowMealBreakWaivers': allowMealBreakWaivers,
      'overtimeWarningMinutes': overtimeWarningMinutes,
      'requireOvertimeApproval': requireOvertimeApproval,
      'trackMinorCompliance': trackMinorCompliance,
      'enablePredictiveScheduling': enablePredictiveScheduling,
      'disabledRuleIds': disabledRuleIds,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CompanyComplianceSettings copyWith({
    String? primaryState,
    String? primaryCity,
    List<String>? additionalStates,
    bool? autoEnforceBreaks,
    bool? requireBreakAcknowledgment,
    bool? allowMealBreakWaivers,
    int? overtimeWarningMinutes,
    bool? requireOvertimeApproval,
    bool? trackMinorCompliance,
    bool? enablePredictiveScheduling,
    List<String>? disabledRuleIds,
  }) {
    return CompanyComplianceSettings(
      companyId: companyId,
      primaryState: primaryState ?? this.primaryState,
      primaryCity: primaryCity ?? this.primaryCity,
      additionalStates: additionalStates ?? this.additionalStates,
      autoEnforceBreaks: autoEnforceBreaks ?? this.autoEnforceBreaks,
      requireBreakAcknowledgment: requireBreakAcknowledgment ?? this.requireBreakAcknowledgment,
      allowMealBreakWaivers: allowMealBreakWaivers ?? this.allowMealBreakWaivers,
      overtimeWarningMinutes: overtimeWarningMinutes ?? this.overtimeWarningMinutes,
      requireOvertimeApproval: requireOvertimeApproval ?? this.requireOvertimeApproval,
      trackMinorCompliance: trackMinorCompliance ?? this.trackMinorCompliance,
      enablePredictiveScheduling: enablePredictiveScheduling ?? this.enablePredictiveScheduling,
      disabledRuleIds: disabledRuleIds ?? this.disabledRuleIds,
      updatedAt: DateTime.now(),
    );
  }
}

/// Result of a compliance check
class ComplianceCheckResult {
  final bool isCompliant;
  final List<ComplianceIssue> issues;
  final List<ComplianceWarning> warnings;

  ComplianceCheckResult({
    required this.isCompliant,
    this.issues = const [],
    this.warnings = const [],
  });

  bool get hasViolations => issues.any((i) => i.severity == ComplianceSeverity.violation);
  bool get hasWarnings => warnings.isNotEmpty;
}

/// A specific compliance issue found
class ComplianceIssue {
  final String ruleId;
  final String ruleName;
  final ComplianceCategory category;
  final ComplianceSeverity severity;
  final String message;
  final String? suggestedAction;
  final Map<String, dynamic>? metadata;

  ComplianceIssue({
    required this.ruleId,
    required this.ruleName,
    required this.category,
    required this.severity,
    required this.message,
    this.suggestedAction,
    this.metadata,
  });
}

/// A compliance warning (approaching violation)
class ComplianceWarning {
  final String ruleId;
  final String ruleName;
  final ComplianceCategory category;
  final String message;
  final int minutesUntilViolation;
  final String? suggestedAction;

  ComplianceWarning({
    required this.ruleId,
    required this.ruleName,
    required this.category,
    required this.message,
    required this.minutesUntilViolation,
    this.suggestedAction,
  });
}
