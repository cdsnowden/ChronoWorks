import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pto_policy_model.dart';
import '../models/pto_balance_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class PtoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // PTO POLICY MANAGEMENT
  // ============================================================

  /// Create a new PTO policy for a company
  Future<PtoPolicyModel> createPolicy(PtoPolicyModel policy) async {
    try {
      final docRef = _firestore.collection(FirebaseCollections.ptoPolicies).doc();
      final newPolicy = policy.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
      );
      await docRef.set(newPolicy.toMap());
      return newPolicy;
    } catch (e) {
      throw Exception('Failed to create PTO policy: $e');
    }
  }

  /// Update an existing PTO policy
  Future<void> updatePolicy(PtoPolicyModel policy) async {
    try {
      await _firestore
          .collection(FirebaseCollections.ptoPolicies)
          .doc(policy.id)
          .update(policy.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update PTO policy: $e');
    }
  }

  /// Delete a PTO policy
  Future<void> deletePolicy(String policyId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.ptoPolicies)
          .doc(policyId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete PTO policy: $e');
    }
  }

  /// Get all PTO policies for a company
  Stream<List<PtoPolicyModel>> getPoliciesForCompany(String companyId) {
    return _firestore
        .collection(FirebaseCollections.ptoPolicies)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PtoPolicyModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get the default PTO policy for a company
  Future<PtoPolicyModel?> getDefaultPolicy(String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.ptoPolicies)
          .where('companyId', isEqualTo: companyId)
          .where('isDefault', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return PtoPolicyModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to get default PTO policy: $e');
    }
  }

  /// Get a specific PTO policy by ID
  Future<PtoPolicyModel?> getPolicy(String policyId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseCollections.ptoPolicies)
          .doc(policyId)
          .get();

      if (!doc.exists) return null;
      return PtoPolicyModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get PTO policy: $e');
    }
  }

  /// Set a policy as the default (and unset any existing default)
  Future<void> setDefaultPolicy(String companyId, String policyId) async {
    try {
      // Get all policies for company
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.ptoPolicies)
          .where('companyId', isEqualTo: companyId)
          .get();

      final batch = _firestore.batch();

      // Unset all existing defaults and set the new default
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'isDefault': doc.id == policyId,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to set default PTO policy: $e');
    }
  }

  /// Initialize default policy for a new company
  Future<PtoPolicyModel> initializeCompanyPolicy(String companyId) async {
    // Check if policy already exists
    final existing = await getDefaultPolicy(companyId);
    if (existing != null) return existing;

    // Create default policy
    final defaultPolicy = PtoPolicyModel.createDefault(companyId);
    return await createPolicy(defaultPolicy);
  }

  // ============================================================
  // PTO BALANCE MANAGEMENT
  // ============================================================

  /// Get or create balance for an employee for a specific year
  Future<PtoBalanceModel> getOrCreateBalance({
    required String employeeId,
    required String companyId,
    required int year,
  }) async {
    try {
      // Try to get existing balance
      final balanceId = '${employeeId}_$year';
      final doc = await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balanceId)
          .get();

      if (doc.exists) {
        return PtoBalanceModel.fromFirestore(doc);
      }

      // Create new balance
      return await _createBalanceForEmployee(employeeId, companyId, year);
    } catch (e) {
      throw Exception('Failed to get or create PTO balance: $e');
    }
  }

  /// Create a new balance for an employee
  Future<PtoBalanceModel> _createBalanceForEmployee(
    String employeeId,
    String companyId,
    int year,
  ) async {
    // Get employee
    final employeeDoc = await _firestore
        .collection(FirebaseCollections.users)
        .doc(employeeId)
        .get();

    if (!employeeDoc.exists) {
      throw Exception('Employee not found');
    }

    final employee = UserModel.fromFirestore(employeeDoc);

    // Get applicable policy
    PtoPolicyModel? policy;
    if (employee.ptoPolicyId != null) {
      policy = await getPolicy(employee.ptoPolicyId!);
    }
    policy ??= await getDefaultPolicy(companyId);

    if (policy == null) {
      // Create default policy if none exists
      policy = await initializeCompanyPolicy(companyId);
    }

    // Calculate years of service at start of year
    final yearStart = DateTime(year, 1, 1);
    final effectiveStartDate = employee.effectiveStartDate;
    int yearsOfService = yearStart.year - effectiveStartDate.year;
    if (yearStart.month < effectiveStartDate.month ||
        (yearStart.month == effectiveStartDate.month &&
            yearStart.day < effectiveStartDate.day)) {
      yearsOfService--;
    }
    yearsOfService = yearsOfService < 0 ? 0 : yearsOfService;

    // Check waiting period
    final monthsEmployed = (yearStart.difference(effectiveStartDate).inDays / 30).floor();
    final isEligible = monthsEmployed >= policy.waitingPeriodMonths;

    // Get annual allocation from policy tier
    double annualAllocation = 0;
    if (isEligible) {
      annualAllocation = policy.getAnnualHoursForYears(yearsOfService);
    }

    // Get carryover from previous year
    double carryoverHours = 0;
    if (year > 1) {
      carryoverHours = await _getCarryoverFromPreviousYear(
        employeeId,
        year - 1,
        policy.maxCarryoverHours,
      );
    }

    // Create the balance
    final balance = PtoBalanceModel.create(
      employeeId: employeeId,
      companyId: companyId,
      year: year,
      annualAllocation: annualAllocation,
      carryoverHours: carryoverHours,
      policyId: policy.id,
      yearsOfServiceAtStart: yearsOfService,
    );

    // Save to Firestore
    await _firestore
        .collection(FirebaseCollections.ptoBalances)
        .doc(balance.id)
        .set(balance.toMap());

    return balance;
  }

  /// Get carryover from previous year balance
  Future<double> _getCarryoverFromPreviousYear(
    String employeeId,
    int previousYear,
    double? maxCarryover,
  ) async {
    try {
      final balanceId = '${employeeId}_$previousYear';
      final doc = await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balanceId)
          .get();

      if (!doc.exists) return 0;

      final balance = PtoBalanceModel.fromFirestore(doc);
      final availableToCarry = balance.availableHours;

      if (availableToCarry <= 0) return 0;

      // Apply max carryover cap if set
      if (maxCarryover != null && availableToCarry > maxCarryover) {
        return maxCarryover;
      }

      return availableToCarry;
    } catch (e) {
      return 0;
    }
  }

  /// Get current year balance for an employee
  Future<PtoBalanceModel?> getCurrentBalance(String employeeId, String companyId) async {
    return await getOrCreateBalance(
      employeeId: employeeId,
      companyId: companyId,
      year: DateTime.now().year,
    );
  }

  /// Stream of balance updates for an employee
  Stream<PtoBalanceModel?> watchBalance(String employeeId, int year) {
    final balanceId = '${employeeId}_$year';
    return _firestore
        .collection(FirebaseCollections.ptoBalances)
        .doc(balanceId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return PtoBalanceModel.fromFirestore(doc);
    });
  }

  /// Update balance when a time-off request is created (pending)
  Future<void> reservePtoHours({
    required String employeeId,
    required String companyId,
    required String requestId,
    required double hours,
    required DateTime requestDate,
  }) async {
    try {
      final year = requestDate.year;
      final balance = await getOrCreateBalance(
        employeeId: employeeId,
        companyId: companyId,
        year: year,
      );

      // Check if there's enough available time
      if (hours > balance.availableHours) {
        throw Exception(
          'Insufficient PTO balance. Available: ${balance.availableHours.toStringAsFixed(1)} hours, Requested: ${hours.toStringAsFixed(1)} hours'
        );
      }

      // Add pending transaction
      final transaction = PtoTransaction(
        id: 'pending_$requestId',
        date: requestDate,
        type: PtoTransactionType.pending,
        hours: hours,
        description: 'Time off request pending approval',
        timeOffRequestId: requestId,
        createdAt: DateTime.now(),
      );

      final updatedTransactions = [...balance.transactions, transaction];

      await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balance.id)
          .update({
        'pendingHours': balance.pendingHours + hours,
        'transactions': updatedTransactions.map((t) => t.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to reserve PTO hours: $e');
    }
  }

  /// Update balance when a time-off request is approved
  Future<void> confirmPtoUsage({
    required String employeeId,
    required String companyId,
    required String requestId,
    required double hours,
    required DateTime requestDate,
  }) async {
    try {
      final year = requestDate.year;
      final balanceId = '${employeeId}_$year';
      final doc = await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balanceId)
          .get();

      if (!doc.exists) {
        throw Exception('Balance not found for year $year');
      }

      final balance = PtoBalanceModel.fromFirestore(doc);

      // Add used transaction
      final transaction = PtoTransaction(
        id: 'used_$requestId',
        date: requestDate,
        type: PtoTransactionType.used,
        hours: hours,
        description: 'Approved time off',
        timeOffRequestId: requestId,
        createdAt: DateTime.now(),
      );

      // Remove pending transaction, add used transaction
      final updatedTransactions = balance.transactions
          .where((t) => t.timeOffRequestId != requestId)
          .toList()
        ..add(transaction);

      await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balanceId)
          .update({
        'pendingHours': (balance.pendingHours - hours).clamp(0, double.infinity),
        'usedHours': balance.usedHours + hours,
        'transactions': updatedTransactions.map((t) => t.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to confirm PTO usage: $e');
    }
  }

  /// Update balance when a time-off request is denied or cancelled
  Future<void> releasePtoHours({
    required String employeeId,
    required String companyId,
    required String requestId,
    required double hours,
    required DateTime requestDate,
  }) async {
    try {
      final year = requestDate.year;
      final balanceId = '${employeeId}_$year';
      final doc = await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balanceId)
          .get();

      if (!doc.exists) return;

      final balance = PtoBalanceModel.fromFirestore(doc);

      // Add cancelled transaction
      final transaction = PtoTransaction(
        id: 'cancelled_$requestId',
        date: DateTime.now(),
        type: PtoTransactionType.cancelled,
        hours: hours,
        description: 'Time off request cancelled/denied',
        timeOffRequestId: requestId,
        createdAt: DateTime.now(),
      );

      // Remove pending transaction, add cancelled transaction
      final updatedTransactions = balance.transactions
          .where((t) => t.timeOffRequestId != requestId)
          .toList()
        ..add(transaction);

      await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balanceId)
          .update({
        'pendingHours': (balance.pendingHours - hours).clamp(0, double.infinity),
        'transactions': updatedTransactions.map((t) => t.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to release PTO hours: $e');
    }
  }

  /// Make a manual adjustment to an employee's balance
  Future<void> adjustBalance({
    required String employeeId,
    required String companyId,
    required int year,
    required double hours,
    required String reason,
    required String adjustedBy,
  }) async {
    try {
      final balance = await getOrCreateBalance(
        employeeId: employeeId,
        companyId: companyId,
        year: year,
      );

      // Add adjustment transaction
      final transaction = PtoTransaction(
        id: 'adj_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        type: PtoTransactionType.adjustment,
        hours: hours,
        description: reason,
        adjustedBy: adjustedBy,
        createdAt: DateTime.now(),
      );

      final updatedTransactions = [...balance.transactions, transaction];

      await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .doc(balance.id)
          .update({
        'adjustmentHours': balance.adjustmentHours + hours,
        'transactions': updatedTransactions.map((t) => t.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to adjust PTO balance: $e');
    }
  }

  // ============================================================
  // ELIGIBILITY CHECKS
  // ============================================================

  /// Check if an employee is eligible for PTO based on their company's policy
  Future<Map<String, dynamic>> checkPtoEligibility({
    required String employeeId,
    required String companyId,
  }) async {
    try {
      // Get employee
      final employeeDoc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(employeeId)
          .get();

      if (!employeeDoc.exists) {
        return {
          'isEligible': false,
          'waitingPeriodMonths': 0,
          'eligibilityDate': DateTime.now(),
          'daysUntilEligible': 0,
          'monthsEmployed': 0,
        };
      }

      final employee = UserModel.fromFirestore(employeeDoc);

      // Get applicable policy
      PtoPolicyModel? policy;
      if (employee.ptoPolicyId != null) {
        policy = await getPolicy(employee.ptoPolicyId!);
      }
      policy ??= await getDefaultPolicy(companyId);

      // Default waiting period if no policy exists
      final waitingPeriodMonths = policy?.waitingPeriodMonths ?? 12;

      final now = DateTime.now();
      final effectiveStartDate = employee.effectiveStartDate;

      // Calculate months employed
      final daysDiff = now.difference(effectiveStartDate).inDays;
      final monthsEmployed = (daysDiff / 30).floor();

      // Calculate eligibility
      final isEligible = monthsEmployed >= waitingPeriodMonths;

      // Calculate eligibility date (add waiting period months to start date)
      final eligibilityDate = DateTime(
        effectiveStartDate.year,
        effectiveStartDate.month + waitingPeriodMonths,
        effectiveStartDate.day,
      );

      // Calculate days until eligible
      final daysUntilEligible = isEligible
          ? 0
          : eligibilityDate.difference(now).inDays.clamp(0, 999999);

      return {
        'isEligible': isEligible,
        'waitingPeriodMonths': waitingPeriodMonths,
        'eligibilityDate': eligibilityDate,
        'daysUntilEligible': daysUntilEligible,
        'monthsEmployed': monthsEmployed,
        'effectiveStartDate': effectiveStartDate,
      };
    } catch (e) {
      throw Exception('Failed to check PTO eligibility: $e');
    }
  }

  // ============================================================
  // BALANCE CALCULATIONS
  // ============================================================

  /// Calculate hours for a time-off request based on dates
  double calculateRequestHours({
    required DateTime startDate,
    required DateTime endDate,
    double hoursPerDay = 8.0,
    bool excludeWeekends = true,
  }) {
    double totalHours = 0;
    DateTime current = startDate;

    while (!current.isAfter(endDate)) {
      // Skip weekends if configured
      if (excludeWeekends && (current.weekday == DateTime.saturday || current.weekday == DateTime.sunday)) {
        current = current.add(const Duration(days: 1));
        continue;
      }
      totalHours += hoursPerDay;
      current = current.add(const Duration(days: 1));
    }

    return totalHours;
  }

  /// Get all balances for a company (for admin view)
  Future<List<PtoBalanceModel>> getAllBalancesForCompany(
    String companyId,
    int year,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirebaseCollections.ptoBalances)
          .where('companyId', isEqualTo: companyId)
          .where('year', isEqualTo: year)
          .get();

      return querySnapshot.docs
          .map((doc) => PtoBalanceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get company balances: $e');
    }
  }

  /// Check if an employee can request the given hours
  Future<bool> canRequestHours({
    required String employeeId,
    required String companyId,
    required double hours,
    required DateTime requestDate,
  }) async {
    try {
      final balance = await getOrCreateBalance(
        employeeId: employeeId,
        companyId: companyId,
        year: requestDate.year,
      );
      return balance.canRequest(hours);
    } catch (e) {
      return false;
    }
  }

  /// Get summary of PTO usage for an employee
  Future<Map<String, dynamic>> getEmployeePtoSummary({
    required String employeeId,
    required String companyId,
    required int year,
  }) async {
    try {
      final balance = await getOrCreateBalance(
        employeeId: employeeId,
        companyId: companyId,
        year: year,
      );

      // Get the policy for formatting
      PtoPolicyModel? policy;
      if (balance.policyId != null) {
        policy = await getPolicy(balance.policyId!);
      }
      policy ??= await getDefaultPolicy(companyId);

      final hoursPerDay = policy?.hoursPerDay ?? 8.0;

      return {
        'year': year,
        'annualAllocation': balance.annualAllocation,
        'carryover': balance.carryoverHours,
        'accrued': balance.accruedHours,
        'adjustments': balance.adjustmentHours,
        'used': balance.usedHours,
        'pending': balance.pendingHours,
        'expired': balance.expiredHours,
        'available': balance.availableHours,
        'totalEarned': balance.totalEarnedHours,
        'usagePercentage': balance.usagePercentage,
        'yearsOfService': balance.yearsOfServiceAtStart,
        // Formatted as days
        'availableDays': balance.availableHours / hoursPerDay,
        'usedDays': balance.usedHours / hoursPerDay,
        'totalDays': balance.totalEarnedHours / hoursPerDay,
        'hoursPerDay': hoursPerDay,
      };
    } catch (e) {
      throw Exception('Failed to get PTO summary: $e');
    }
  }

  // ============================================================
  // ACCRUAL PROCESSING (for per-pay-period accrual)
  // ============================================================

  /// Process accrual for a pay period (call this from a scheduled job or manually)
  Future<void> processPayPeriodAccrual({
    required String companyId,
    required DateTime payPeriodEnd,
  }) async {
    try {
      // Get the company's policy
      final policy = await getDefaultPolicy(companyId);
      if (policy == null || policy.accrualMethod != AccrualMethod.perPayPeriod) {
        return; // Skip if no policy or not per-pay-period accrual
      }

      // Get all employees
      final employeesSnapshot = await _firestore
          .collection(FirebaseCollections.users)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final year = payPeriodEnd.year;

      for (final employeeDoc in employeesSnapshot.docs) {
        final employee = UserModel.fromFirestore(employeeDoc);

        // Check if employee is eligible
        final monthsEmployed = (payPeriodEnd.difference(employee.effectiveStartDate).inDays / 30).floor();
        if (monthsEmployed < policy.waitingPeriodMonths) continue;

        // Get or create balance
        final balance = await getOrCreateBalance(
          employeeId: employee.id,
          companyId: companyId,
          year: year,
        );

        // Calculate hours to accrue
        final hoursToAccrue = policy.getHoursPerPayPeriod(employee.yearsOfService);

        // Check if max accrual would be exceeded
        final newTotal = balance.accruedHours + hoursToAccrue;
        final cappedHours = policy.maxAccrualHours != null
            ? (newTotal > policy.maxAccrualHours!
                ? policy.maxAccrualHours! - balance.accruedHours
                : hoursToAccrue)
            : hoursToAccrue;

        if (cappedHours <= 0) continue;

        // Add accrual transaction
        final transaction = PtoTransaction(
          id: 'accrual_${employee.id}_${payPeriodEnd.millisecondsSinceEpoch}',
          date: payPeriodEnd,
          type: PtoTransactionType.accrual,
          hours: cappedHours,
          description: 'Pay period accrual',
          createdAt: DateTime.now(),
        );

        final updatedTransactions = [...balance.transactions, transaction];

        await _firestore
            .collection(FirebaseCollections.ptoBalances)
            .doc(balance.id)
            .update({
          'accruedHours': balance.accruedHours + cappedHours,
          'transactions': updatedTransactions.map((t) => t.toMap()).toList(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      throw Exception('Failed to process pay period accrual: $e');
    }
  }
}
