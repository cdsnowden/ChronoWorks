import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compliance_rule_model.dart';
import '../models/user_model.dart';
import '../models/time_entry_model.dart';
import '../utils/constants.dart';

/// Service for managing labor law compliance
class ComplianceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _rulesCollection = 'complianceRules';
  static const String _eventsCollection = 'complianceEvents';
  static const String _settingsCollection = 'complianceSettings';

  // ============================================================
  // DEFAULT RULES - Pre-populated labor law rules
  // ============================================================

  /// Get default federal and state rules
  static List<ComplianceRule> getDefaultRules() {
    final now = DateTime.now();
    return [
      // === FEDERAL RULES ===
      ComplianceRule(
        id: 'fed_weekly_ot',
        name: 'Federal Weekly Overtime',
        description: 'Non-exempt employees must receive 1.5x pay for hours over 40 per week',
        category: ComplianceCategory.weeklyOvertime,
        jurisdiction: 'federal',
        overtimeThreshold: 40,
        overtimeMultiplier: 1.5,
        warningMinutesBefore: 60,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'FLSA Section 7(a)',
        effectiveDate: DateTime(1938, 10, 24),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'fed_minor_school',
        name: 'Federal Minor Work Hours (School Days)',
        description: 'Minors 14-15 may work max 3 hours on school days',
        category: ComplianceCategory.minorHours,
        jurisdiction: 'federal',
        maxHoursSchoolDay: 3,
        maxHoursNonSchoolDay: 8,
        enforcementAction: EnforcementAction.blockAction,
        legalReference: 'FLSA Child Labor Provisions',
        effectiveDate: DateTime(1938, 10, 24),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'fed_minor_timing',
        name: 'Federal Minor Work Timing',
        description: 'Minors 14-15 may only work between 7am-7pm (9pm June-Labor Day)',
        category: ComplianceCategory.minorTiming,
        jurisdiction: 'federal',
        timeRestriction: '7:00-19:00',
        enforcementAction: EnforcementAction.blockAction,
        legalReference: 'FLSA Child Labor Provisions',
        effectiveDate: DateTime(1938, 10, 24),
        createdAt: now,
      ),

      // === CALIFORNIA RULES ===
      ComplianceRule(
        id: 'ca_meal_break',
        name: 'California Meal Break',
        description: 'Employees must receive a 30-minute unpaid meal break before 5 hours of work',
        category: ComplianceCategory.mealBreak,
        jurisdiction: 'state',
        state: 'CA',
        hoursThreshold: 5,
        durationMinutes: 30,
        warningMinutesBefore: 30,
        enforcementAction: EnforcementAction.warnEmployee,
        isWaivable: true,
        waiverRequirements: 'Written waiver if shift is 6 hours or less',
        legalReference: 'California Labor Code Section 512',
        effectiveDate: DateTime(2000, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'ca_second_meal',
        name: 'California Second Meal Break',
        description: 'Employees working over 10 hours must receive a second 30-minute meal break',
        category: ComplianceCategory.mealBreak,
        jurisdiction: 'state',
        state: 'CA',
        hoursThreshold: 10,
        durationMinutes: 30,
        warningMinutesBefore: 30,
        enforcementAction: EnforcementAction.warnEmployee,
        isWaivable: true,
        waiverRequirements: 'Can waive if first meal break was not waived and shift is 12 hours or less',
        legalReference: 'California Labor Code Section 512',
        effectiveDate: DateTime(2000, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'ca_rest_break',
        name: 'California Rest Break',
        description: 'Employees must receive a paid 10-minute rest break per 4 hours worked',
        category: ComplianceCategory.restBreak,
        jurisdiction: 'state',
        state: 'CA',
        hoursThreshold: 4,
        durationMinutes: 10,
        warningMinutesBefore: 15,
        enforcementAction: EnforcementAction.notify,
        legalReference: 'California Labor Code Section 226.7',
        effectiveDate: DateTime(2000, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'ca_daily_ot',
        name: 'California Daily Overtime',
        description: 'Non-exempt employees must receive 1.5x pay for hours over 8 per day',
        category: ComplianceCategory.dailyOvertime,
        jurisdiction: 'state',
        state: 'CA',
        overtimeThreshold: 8,
        overtimeMultiplier: 1.5,
        warningMinutesBefore: 60,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'California Labor Code Section 510',
        effectiveDate: DateTime(2000, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'ca_double_time',
        name: 'California Double Time',
        description: 'Employees must receive 2x pay for hours over 12 per day',
        category: ComplianceCategory.doubleTime,
        jurisdiction: 'state',
        state: 'CA',
        overtimeThreshold: 12,
        overtimeMultiplier: 2.0,
        warningMinutesBefore: 30,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'California Labor Code Section 510',
        effectiveDate: DateTime(2000, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'ca_7th_day',
        name: 'California 7th Consecutive Day',
        description: 'Employees working 7 consecutive days receive 1.5x for first 8 hours, 2x after',
        category: ComplianceCategory.consecutiveDays,
        jurisdiction: 'state',
        state: 'CA',
        maxConsecutiveDays: 6,
        overtimeMultiplier: 1.5,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'California Labor Code Section 510',
        effectiveDate: DateTime(2000, 1, 1),
        createdAt: now,
      ),

      // === NEW YORK RULES ===
      ComplianceRule(
        id: 'ny_meal_break',
        name: 'New York Meal Break',
        description: 'Employees must receive a 30-minute meal break for shifts over 6 hours spanning 11am-2pm',
        category: ComplianceCategory.mealBreak,
        jurisdiction: 'state',
        state: 'NY',
        hoursThreshold: 6,
        durationMinutes: 30,
        warningMinutesBefore: 30,
        enforcementAction: EnforcementAction.warnEmployee,
        legalReference: 'NY Labor Law Section 162',
        effectiveDate: DateTime(1990, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'ny_spread_of_hours',
        name: 'New York Spread of Hours',
        description: 'Employees whose workday spans more than 10 hours are entitled to an extra hour at minimum wage',
        category: ComplianceCategory.splitShift,
        jurisdiction: 'state',
        state: 'NY',
        hoursThreshold: 10,
        enforcementAction: EnforcementAction.notify,
        legalReference: 'NY Labor Law Section 220',
        effectiveDate: DateTime(1990, 1, 1),
        createdAt: now,
      ),

      // === TEXAS RULES ===
      ComplianceRule(
        id: 'tx_weekly_ot',
        name: 'Texas Weekly Overtime',
        description: 'Texas follows federal FLSA overtime rules (40 hours/week)',
        category: ComplianceCategory.weeklyOvertime,
        jurisdiction: 'state',
        state: 'TX',
        overtimeThreshold: 40,
        overtimeMultiplier: 1.5,
        warningMinutesBefore: 60,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'Texas follows FLSA',
        effectiveDate: DateTime(1990, 1, 1),
        createdAt: now,
      ),

      // === OREGON RULES ===
      ComplianceRule(
        id: 'or_predictive',
        name: 'Oregon Predictive Scheduling',
        description: 'Retail, food service, and hospitality employers must provide schedules 14 days in advance',
        category: ComplianceCategory.predictiveScheduling,
        jurisdiction: 'state',
        state: 'OR',
        industries: ['Retail', 'Restaurant / Food Service', 'Hospitality'],
        advanceNoticeDays: 14,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'Oregon SB 828',
        effectiveDate: DateTime(2018, 7, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'or_meal_break',
        name: 'Oregon Meal Break',
        description: 'Employees must receive a 30-minute unpaid meal break for shifts over 6 hours',
        category: ComplianceCategory.mealBreak,
        jurisdiction: 'state',
        state: 'OR',
        hoursThreshold: 6,
        durationMinutes: 30,
        warningMinutesBefore: 30,
        enforcementAction: EnforcementAction.warnEmployee,
        legalReference: 'Oregon ORS 653.261',
        effectiveDate: DateTime(1990, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'or_rest_break',
        name: 'Oregon Rest Break',
        description: 'Employees must receive a paid 10-minute rest break per 4 hours worked',
        category: ComplianceCategory.restBreak,
        jurisdiction: 'state',
        state: 'OR',
        hoursThreshold: 4,
        durationMinutes: 10,
        warningMinutesBefore: 15,
        enforcementAction: EnforcementAction.notify,
        legalReference: 'Oregon ORS 653.261',
        effectiveDate: DateTime(1990, 1, 1),
        createdAt: now,
      ),

      // === WASHINGTON RULES ===
      ComplianceRule(
        id: 'wa_meal_break',
        name: 'Washington Meal Break',
        description: 'Employees must receive a 30-minute meal break between 2nd and 5th hour of work',
        category: ComplianceCategory.mealBreak,
        jurisdiction: 'state',
        state: 'WA',
        hoursThreshold: 5,
        durationMinutes: 30,
        warningMinutesBefore: 30,
        enforcementAction: EnforcementAction.warnEmployee,
        legalReference: 'WAC 296-126-092',
        effectiveDate: DateTime(1990, 1, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'wa_rest_break',
        name: 'Washington Rest Break',
        description: 'Employees must receive a paid 10-minute rest break per 4 hours worked',
        category: ComplianceCategory.restBreak,
        jurisdiction: 'state',
        state: 'WA',
        hoursThreshold: 4,
        durationMinutes: 10,
        warningMinutesBefore: 15,
        enforcementAction: EnforcementAction.notify,
        legalReference: 'WAC 296-126-092',
        effectiveDate: DateTime(1990, 1, 1),
        createdAt: now,
      ),

      // === CITY-SPECIFIC RULES ===
      ComplianceRule(
        id: 'sea_secure_scheduling',
        name: 'Seattle Secure Scheduling',
        description: 'Large retail/food service employers must provide schedules 14 days in advance',
        category: ComplianceCategory.predictiveScheduling,
        jurisdiction: 'city',
        state: 'WA',
        city: 'Seattle',
        industries: ['Retail', 'Restaurant / Food Service'],
        advanceNoticeDays: 14,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'Seattle Municipal Code 14.22',
        effectiveDate: DateTime(2017, 7, 1),
        createdAt: now,
      ),
      ComplianceRule(
        id: 'nyc_fast_food_scheduling',
        name: 'NYC Fast Food Scheduling',
        description: 'Fast food employers must provide schedules 14 days in advance',
        category: ComplianceCategory.predictiveScheduling,
        jurisdiction: 'city',
        state: 'NY',
        city: 'New York City',
        industries: ['Restaurant / Food Service'],
        advanceNoticeDays: 14,
        enforcementAction: EnforcementAction.warnManager,
        legalReference: 'NYC Admin Code 20-1221',
        effectiveDate: DateTime(2017, 11, 26),
        createdAt: now,
      ),
    ];
  }

  // ============================================================
  // RULES MANAGEMENT
  // ============================================================

  /// Initialize default rules in Firestore (run once)
  Future<void> initializeDefaultRules() async {
    final batch = _firestore.batch();
    final rules = getDefaultRules();

    for (final rule in rules) {
      final docRef = _firestore.collection(_rulesCollection).doc(rule.id);
      batch.set(docRef, rule.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Get all active rules for a jurisdiction
  Future<List<ComplianceRule>> getRulesForJurisdiction({
    required String state,
    String? city,
    String? industry,
  }) async {
    final rules = <ComplianceRule>[];

    // Get federal rules
    final federalQuery = await _firestore
        .collection(_rulesCollection)
        .where('jurisdiction', isEqualTo: 'federal')
        .where('isActive', isEqualTo: true)
        .get();
    rules.addAll(federalQuery.docs.map((d) => ComplianceRule.fromFirestore(d)));

    // Get state rules
    final stateQuery = await _firestore
        .collection(_rulesCollection)
        .where('jurisdiction', isEqualTo: 'state')
        .where('state', isEqualTo: state)
        .where('isActive', isEqualTo: true)
        .get();
    rules.addAll(stateQuery.docs.map((d) => ComplianceRule.fromFirestore(d)));

    // Get city rules if applicable
    if (city != null) {
      final cityQuery = await _firestore
          .collection(_rulesCollection)
          .where('jurisdiction', isEqualTo: 'city')
          .where('state', isEqualTo: state)
          .where('city', isEqualTo: city)
          .where('isActive', isEqualTo: true)
          .get();
      rules.addAll(cityQuery.docs.map((d) => ComplianceRule.fromFirestore(d)));
    }

    // Filter by industry if specified
    if (industry != null) {
      return rules.where((r) {
        if (r.industries == null || r.industries!.isEmpty) return true;
        return r.industries!.contains(industry);
      }).toList();
    }

    return rules;
  }

  // ============================================================
  // REAL-TIME COMPLIANCE CHECKING
  // ============================================================

  /// Check compliance for an active shift
  Future<ComplianceCheckResult> checkActiveShift({
    required String employeeId,
    required String companyId,
    required DateTime clockInTime,
    List<TimeEntryModel>? breaks,
  }) async {
    final issues = <ComplianceIssue>[];
    final warnings = <ComplianceWarning>[];

    // Get company settings and applicable rules
    final settings = await getCompanySettings(companyId);
    final rules = await getRulesForJurisdiction(
      state: settings?.primaryState ?? 'CA',
      city: settings?.primaryCity,
    );

    final now = DateTime.now();
    final minutesWorked = now.difference(clockInTime).inMinutes;
    final hoursWorked = minutesWorked / 60;

    // Check each applicable rule
    for (final rule in rules) {
      if (settings?.disabledRuleIds.contains(rule.id) ?? false) continue;

      switch (rule.category) {
        case ComplianceCategory.mealBreak:
          final result = _checkMealBreak(
            rule: rule,
            hoursWorked: hoursWorked,
            minutesWorked: minutesWorked,
            breaks: breaks,
          );
          if (result.issue != null) issues.add(result.issue!);
          if (result.warning != null) warnings.add(result.warning!);
          break;

        case ComplianceCategory.restBreak:
          final result = _checkRestBreak(
            rule: rule,
            hoursWorked: hoursWorked,
            breaks: breaks,
          );
          if (result.issue != null) issues.add(result.issue!);
          if (result.warning != null) warnings.add(result.warning!);
          break;

        case ComplianceCategory.dailyOvertime:
          final result = _checkDailyOvertime(
            rule: rule,
            hoursWorked: hoursWorked,
            minutesWorked: minutesWorked,
          );
          if (result.issue != null) issues.add(result.issue!);
          if (result.warning != null) warnings.add(result.warning!);
          break;

        case ComplianceCategory.doubleTime:
          final result = _checkDoubleTime(
            rule: rule,
            hoursWorked: hoursWorked,
            minutesWorked: minutesWorked,
          );
          if (result.warning != null) warnings.add(result.warning!);
          break;

        default:
          break;
      }
    }

    return ComplianceCheckResult(
      isCompliant: issues.isEmpty,
      issues: issues,
      warnings: warnings,
    );
  }

  /// Check meal break compliance
  _RuleCheckResult _checkMealBreak({
    required ComplianceRule rule,
    required double hoursWorked,
    required int minutesWorked,
    List<TimeEntryModel>? breaks,
  }) {
    final threshold = rule.hoursThreshold ?? 5;
    final thresholdMinutes = (threshold * 60).toInt();
    final warningBefore = rule.warningMinutesBefore ?? 30;

    // Check if meal break was taken
    final mealBreakTaken = breaks?.any((b) =>
        b.breakType == 'meal' &&
        b.breakDurationMinutes != null &&
        b.breakDurationMinutes! >= (rule.durationMinutes ?? 30)) ?? false;

    if (mealBreakTaken) {
      return _RuleCheckResult();
    }

    // Violation: worked past threshold without break
    if (hoursWorked >= threshold) {
      return _RuleCheckResult(
        issue: ComplianceIssue(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          severity: ComplianceSeverity.violation,
          message: 'Meal break required after ${threshold.toStringAsFixed(0)} hours. '
              'Employee has worked ${hoursWorked.toStringAsFixed(1)} hours without a meal break.',
          suggestedAction: 'Send employee on meal break immediately',
          metadata: {'hoursWorked': hoursWorked, 'threshold': threshold},
        ),
      );
    }

    // Warning: approaching threshold
    if (minutesWorked >= thresholdMinutes - warningBefore) {
      return _RuleCheckResult(
        warning: ComplianceWarning(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          message: 'Meal break due in ${thresholdMinutes - minutesWorked} minutes',
          minutesUntilViolation: thresholdMinutes - minutesWorked,
          suggestedAction: 'Take ${rule.durationMinutes}-minute meal break',
        ),
      );
    }

    return _RuleCheckResult();
  }

  /// Check rest break compliance
  _RuleCheckResult _checkRestBreak({
    required ComplianceRule rule,
    required double hoursWorked,
    List<TimeEntryModel>? breaks,
  }) {
    final threshold = rule.hoursThreshold ?? 4;
    final requiredBreaks = (hoursWorked / threshold).floor();

    final restBreaksTaken = breaks?.where((b) =>
        b.breakType == 'rest' &&
        b.breakDurationMinutes != null &&
        b.breakDurationMinutes! >= (rule.durationMinutes ?? 10)).length ?? 0;

    if (restBreaksTaken < requiredBreaks && requiredBreaks > 0) {
      return _RuleCheckResult(
        warning: ComplianceWarning(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          message: 'Rest break recommended. $requiredBreaks break(s) due, $restBreaksTaken taken.',
          minutesUntilViolation: 0,
          suggestedAction: 'Take a ${rule.durationMinutes}-minute rest break',
        ),
      );
    }

    return _RuleCheckResult();
  }

  /// Check daily overtime
  _RuleCheckResult _checkDailyOvertime({
    required ComplianceRule rule,
    required double hoursWorked,
    required int minutesWorked,
  }) {
    final threshold = rule.overtimeThreshold ?? 8;
    final thresholdMinutes = (threshold * 60).toInt();
    final warningBefore = rule.warningMinutesBefore ?? 60;

    // Already in overtime
    if (hoursWorked > threshold) {
      return _RuleCheckResult(
        issue: ComplianceIssue(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          severity: ComplianceSeverity.info,
          message: 'Employee is now in overtime. '
              '${(hoursWorked - threshold).toStringAsFixed(1)} OT hours at ${rule.overtimeMultiplier}x rate.',
          metadata: {
            'overtimeHours': hoursWorked - threshold,
            'multiplier': rule.overtimeMultiplier,
          },
        ),
      );
    }

    // Approaching overtime
    if (minutesWorked >= thresholdMinutes - warningBefore) {
      return _RuleCheckResult(
        warning: ComplianceWarning(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          message: 'Approaching daily overtime in ${thresholdMinutes - minutesWorked} minutes',
          minutesUntilViolation: thresholdMinutes - minutesWorked,
          suggestedAction: 'Consider clocking out to avoid overtime',
        ),
      );
    }

    return _RuleCheckResult();
  }

  /// Check double time
  _RuleCheckResult _checkDoubleTime({
    required ComplianceRule rule,
    required double hoursWorked,
    required int minutesWorked,
  }) {
    final threshold = rule.overtimeThreshold ?? 12;
    final thresholdMinutes = (threshold * 60).toInt();
    final warningBefore = rule.warningMinutesBefore ?? 30;

    if (minutesWorked >= thresholdMinutes - warningBefore && hoursWorked < threshold) {
      return _RuleCheckResult(
        warning: ComplianceWarning(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          message: 'Approaching double time in ${thresholdMinutes - minutesWorked} minutes',
          minutesUntilViolation: thresholdMinutes - minutesWorked,
          suggestedAction: 'Double time (${rule.overtimeMultiplier}x) starts at $threshold hours',
        ),
      );
    }

    return _RuleCheckResult();
  }

  /// Check weekly overtime for an employee
  Future<ComplianceCheckResult> checkWeeklyOvertime({
    required String employeeId,
    required String companyId,
    required double hoursThisWeek,
    double? additionalHoursToday,
  }) async {
    final issues = <ComplianceIssue>[];
    final warnings = <ComplianceWarning>[];

    final settings = await getCompanySettings(companyId);
    final rules = await getRulesForJurisdiction(
      state: settings?.primaryState ?? 'CA',
      city: settings?.primaryCity,
    );

    final totalHours = hoursThisWeek + (additionalHoursToday ?? 0);

    for (final rule in rules) {
      if (rule.category != ComplianceCategory.weeklyOvertime) continue;
      if (settings?.disabledRuleIds.contains(rule.id) ?? false) continue;

      final threshold = rule.overtimeThreshold ?? 40;
      final warningHours = threshold - ((rule.warningMinutesBefore ?? 60) / 60);

      if (totalHours > threshold) {
        issues.add(ComplianceIssue(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          severity: ComplianceSeverity.info,
          message: 'Weekly overtime: ${(totalHours - threshold).toStringAsFixed(1)} hours at ${rule.overtimeMultiplier}x',
          metadata: {'weeklyHours': totalHours, 'overtimeHours': totalHours - threshold},
        ));
      } else if (totalHours >= warningHours) {
        warnings.add(ComplianceWarning(
          ruleId: rule.id,
          ruleName: rule.name,
          category: rule.category,
          message: 'Approaching weekly overtime. ${totalHours.toStringAsFixed(1)} of $threshold hours used.',
          minutesUntilViolation: ((threshold - totalHours) * 60).toInt(),
          suggestedAction: 'Only ${(threshold - totalHours).toStringAsFixed(1)} regular hours remaining this week',
        ));
      }
    }

    return ComplianceCheckResult(
      isCompliant: issues.isEmpty,
      issues: issues,
      warnings: warnings,
    );
  }

  // ============================================================
  // COMPLIANCE EVENTS (AUDIT LOG)
  // ============================================================

  /// Log a compliance event
  Future<void> logComplianceEvent(ComplianceEvent event) async {
    await _firestore.collection(_eventsCollection).add(event.toMap());
  }

  /// Get compliance events for a company
  Future<List<ComplianceEvent>> getComplianceEvents({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
    ComplianceSeverity? severity,
    String? employeeId,
  }) async {
    Query query = _firestore
        .collection(_eventsCollection)
        .where('companyId', isEqualTo: companyId);

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    if (employeeId != null) {
      query = query.where('employeeId', isEqualTo: employeeId);
    }

    final snapshot = await query.orderBy('timestamp', descending: true).get();
    var events = snapshot.docs.map((d) => ComplianceEvent.fromFirestore(d)).toList();

    if (severity != null) {
      events = events.where((e) => e.severity == severity).toList();
    }

    return events;
  }

  /// Resolve a compliance event
  Future<void> resolveComplianceEvent({
    required String eventId,
    required String resolvedBy,
    required String resolution,
  }) async {
    await _firestore.collection(_eventsCollection).doc(eventId).update({
      'resolvedAt': Timestamp.now(),
      'resolvedBy': resolvedBy,
      'resolution': resolution,
    });
  }

  // ============================================================
  // COMPANY SETTINGS
  // ============================================================

  /// Get company compliance settings
  Future<CompanyComplianceSettings?> getCompanySettings(String companyId) async {
    final doc = await _firestore.collection(_settingsCollection).doc(companyId).get();
    if (!doc.exists) return null;
    return CompanyComplianceSettings.fromFirestore(doc);
  }

  /// Save company compliance settings
  Future<void> saveCompanySettings(CompanyComplianceSettings settings) async {
    await _firestore
        .collection(_settingsCollection)
        .doc(settings.companyId)
        .set(settings.toMap());
  }

  /// Get or create default settings for a company
  Future<CompanyComplianceSettings> getOrCreateSettings(String companyId, {String defaultState = 'CA'}) async {
    var settings = await getCompanySettings(companyId);
    if (settings == null) {
      settings = CompanyComplianceSettings(
        companyId: companyId,
        primaryState: defaultState,
        updatedAt: DateTime.now(),
      );
      await saveCompanySettings(settings);
    }
    return settings;
  }

  // ============================================================
  // COMPLIANCE REPORTS
  // ============================================================

  /// Generate a compliance summary report
  Future<Map<String, dynamic>> generateComplianceReport({
    required String companyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final events = await getComplianceEvents(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
    );

    final violations = events.where((e) => e.severity == ComplianceSeverity.violation).toList();
    final warnings = events.where((e) => e.severity == ComplianceSeverity.warning).toList();
    final resolved = events.where((e) => e.isResolved).toList();

    // Group by category
    final byCategory = <String, int>{};
    for (final event in events) {
      final key = event.category.name;
      byCategory[key] = (byCategory[key] ?? 0) + 1;
    }

    // Group by employee
    final byEmployee = <String, int>{};
    for (final event in violations) {
      byEmployee[event.employeeName] = (byEmployee[event.employeeName] ?? 0) + 1;
    }

    return {
      'period': {
        'start': startDate.toIso8601String(),
        'end': endDate.toIso8601String(),
      },
      'summary': {
        'totalEvents': events.length,
        'violations': violations.length,
        'warnings': warnings.length,
        'resolved': resolved.length,
        'resolutionRate': events.isNotEmpty
            ? (resolved.length / events.length * 100).toStringAsFixed(1)
            : '100',
      },
      'byCategory': byCategory,
      'byEmployee': byEmployee,
      'topViolations': violations.take(10).map((e) => {
        'employee': e.employeeName,
        'rule': e.ruleName,
        'date': e.timestamp.toIso8601String(),
        'resolved': e.isResolved,
      }).toList(),
    };
  }
}

/// Helper class for rule check results
class _RuleCheckResult {
  final ComplianceIssue? issue;
  final ComplianceWarning? warning;

  _RuleCheckResult({this.issue, this.warning});
}
