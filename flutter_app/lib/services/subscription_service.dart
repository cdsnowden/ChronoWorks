import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/subscription_plan.dart';

/// Service for managing subscriptions and feature access
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Gets the current company's subscription details
  Future<CompanySubscription> getCompanySubscription(String companyId) async {
    final companyDoc = await _firestore.collection('companies').doc(companyId).get();

    if (!companyDoc.exists) {
      throw Exception('Company not found');
    }

    final data = companyDoc.data()!;
    return CompanySubscription.fromFirestore(data);
  }

  /// Gets the subscription plan details
  Future<SubscriptionPlan?> getSubscriptionPlan(String planId) async {
    final planDoc = await _firestore.collection('subscriptionPlans').doc(planId).get();

    if (!planDoc.exists) {
      return null;
    }

    return SubscriptionPlan.fromJson(planDoc.data()!);
  }

  /// Checks if a specific feature is available for the company
  Future<bool> hasFeature(String companyId, String featureName) async {
    try {
      final subscription = await getCompanySubscription(companyId);

      // If account is locked, no features available (except read-only)
      if (subscription.status == 'locked') {
        return false;
      }

      // Get the plan details
      final plan = await getSubscriptionPlan(subscription.currentPlan);
      if (plan == null) {
        return false;
      }

      // Check if feature exists in plan
      return plan.features[featureName] ?? false;
    } catch (e) {
      print('Error checking feature access: $e');
      return false;
    }
  }

  /// Returns a FeatureAccessResult with detailed information
  Future<FeatureAccessResult> checkFeatureAccess(String companyId, String featureName) async {
    try {
      final subscription = await getCompanySubscription(companyId);

      // If account is locked
      if (subscription.status == 'locked') {
        return FeatureAccessResult(
          hasAccess: false,
          reason: 'Your account is locked. Please choose a paid plan to reactivate.',
          requiresUpgrade: true,
          currentPlan: subscription.currentPlan,
        );
      }

      // Get the plan details
      final plan = await getSubscriptionPlan(subscription.currentPlan);
      if (plan == null) {
        return FeatureAccessResult(
          hasAccess: false,
          reason: 'Plan not found',
          requiresUpgrade: false,
          currentPlan: subscription.currentPlan,
        );
      }

      // Check if feature is available
      final hasFeature = plan.features[featureName] ?? false;

      if (!hasFeature) {
        return FeatureAccessResult(
          hasAccess: false,
          reason: 'This feature is not available on your ${plan.name}. Upgrade to unlock.',
          requiresUpgrade: true,
          currentPlan: subscription.currentPlan,
          suggestedPlan: _getSuggestedPlanForFeature(featureName),
        );
      }

      return FeatureAccessResult(
        hasAccess: true,
        reason: '',
        requiresUpgrade: false,
        currentPlan: subscription.currentPlan,
      );
    } catch (e) {
      return FeatureAccessResult(
        hasAccess: false,
        reason: 'Error checking feature access: $e',
        requiresUpgrade: false,
        currentPlan: 'unknown',
      );
    }
  }

  /// Suggests which plan to upgrade to for a specific feature
  String _getSuggestedPlanForFeature(String featureName) {
    // Map features to minimum required plan
    const featureToPlan = {
      'overtimeTracking': 'bronze',
      'missedClockoutAlerts': 'bronze',
      'lateClockInAlerts': 'bronze',
      'photoVerification': 'silver',
      'gpsTracking': 'silver',
      'advancedReporting': 'silver',
      'exportData': 'silver',
      'shiftSwapping': 'silver',
      'payrollIntegration': 'silver',
      'apiAccess': 'silver',
      'departmentManagement': 'gold',
      'autoScheduling': 'gold',
      'laborCostTracking': 'gold',
      'paidTimeOff': 'gold',
      'customDashboards': 'gold',
      'roleBasedPermissions': 'platinum',
      'customIntegrations': 'platinum',
      'biometricClockIn': 'platinum',
      'teamMessaging': 'platinum',
      'complianceReports': 'platinum',
    };

    return featureToPlan[featureName] ?? 'silver';
  }

  /// Gets all available subscription plans
  Future<List<SubscriptionPlan>> getAllPlans() async {
    final plansSnapshot = await _firestore
        .collection('subscriptionPlans')
        .where('isVisible', isEqualTo: true)
        .orderBy('displayOrder')
        .get();

    return plansSnapshot.docs
        .map((doc) => SubscriptionPlan.fromJson(doc.data()))
        .toList();
  }

  /// Get upgrade preview showing costs and changes (Phase 4)
  Future<PlanChangePreview> getUpgradePreview({
    required String newPlan,
    required String newBillingCycle,
  }) async {
    try {
      final callable = _functions.httpsCallable('getUpgradePreview');
      final result = await callable.call({
        'newPlan': newPlan,
        'newBillingCycle': newBillingCycle,
      });

      if (result.data['success'] != true) {
        throw Exception('Failed to get upgrade preview');
      }

      return PlanChangePreview.fromJson(result.data as Map<String, dynamic>);
    } catch (e) {
      print('Error getting upgrade preview: $e');
      rethrow;
    }
  }

  /// Change subscription plan (upgrade or downgrade) (Phase 4)
  Future<PlanChangeResult> changePlan({
    required String newPlan,
    required String newBillingCycle,
    bool? immediate,
  }) async {
    try {
      final callable = _functions.httpsCallable('changePlan');
      final result = await callable.call({
        'newPlan': newPlan,
        'newBillingCycle': newBillingCycle,
        if (immediate != null) 'immediate': immediate,
      });

      if (result.data['success'] != true) {
        throw Exception(result.data['message'] ?? 'Failed to change plan');
      }

      return PlanChangeResult.fromJson(result.data as Map<String, dynamic>);
    } catch (e) {
      print('Error changing plan: $e');
      rethrow;
    }
  }

  /// Cancel a scheduled plan change (downgrade) (Phase 4)
  Future<void> cancelScheduledChange() async {
    try {
      final callable = _functions.httpsCallable('cancelScheduledChange');
      final result = await callable.call();

      if (result.data['success'] != true) {
        throw Exception(result.data['message'] ?? 'Failed to cancel scheduled change');
      }
    } catch (e) {
      print('Error cancelling scheduled change: $e');
      rethrow;
    }
  }

  /// Get current company's billing info (Phase 4)
  Future<Map<String, dynamic>?> getCurrentBillingInfo(String companyId) async {
    try {
      final doc = await _firestore.collection('companies').doc(companyId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'currentPlan': data['currentPlan'] ?? 'free',
        'billingCycle': data['billingCycle'],
        'nextBillingDate': data['nextBillingDate'],
        'lastBillingDate': data['lastBillingDate'],
        'billingStatus': data['billingStatus'] ?? 'active',
        'hasPaymentMethod': data['hasPaymentMethod'] ?? false,
        'paymentMethodLast4': data['paymentMethodLast4'],
        'paymentMethodType': data['paymentMethodType'],
        'scheduledPlanChange': data['scheduledPlanChange'],
        'planHistory': data['planHistory'] ?? [],
      };
    } catch (e) {
      print('Error getting billing info: $e');
      rethrow;
    }
  }

  /// Stream current company's billing info (Phase 4)
  Stream<Map<String, dynamic>?> billingInfoStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data()!;
      return {
        'currentPlan': data['currentPlan'] ?? 'free',
        'billingCycle': data['billingCycle'],
        'nextBillingDate': data['nextBillingDate'],
        'lastBillingDate': data['lastBillingDate'],
        'billingStatus': data['billingStatus'] ?? 'active',
        'hasPaymentMethod': data['hasPaymentMethod'] ?? false,
        'paymentMethodLast4': data['paymentMethodLast4'],
        'paymentMethodType': data['paymentMethodType'],
        'scheduledPlanChange': data['scheduledPlanChange'],
        'planHistory': data['planHistory'] ?? [],
      };
    });
  }
}

/// Represents a company's subscription status
class CompanySubscription {
  final String currentPlan;
  final String status; // 'active', 'locked'
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;
  final DateTime? freeStartDate;
  final DateTime? freeEndDate;
  final DateTime? lockedAt;
  final String? lockedReason;

  CompanySubscription({
    required this.currentPlan,
    required this.status,
    this.trialStartDate,
    this.trialEndDate,
    this.freeStartDate,
    this.freeEndDate,
    this.lockedAt,
    this.lockedReason,
  });

  factory CompanySubscription.fromFirestore(Map<String, dynamic> data) {
    return CompanySubscription(
      currentPlan: data['currentPlan'] ?? 'free',
      status: data['status'] ?? 'active',
      trialStartDate: (data['trialStartDate'] as Timestamp?)?.toDate(),
      trialEndDate: (data['trialEndDate'] as Timestamp?)?.toDate(),
      freeStartDate: (data['freeStartDate'] as Timestamp?)?.toDate(),
      freeEndDate: (data['freeEndDate'] as Timestamp?)?.toDate(),
      lockedAt: (data['lockedAt'] as Timestamp?)?.toDate(),
      lockedReason: data['lockedReason'],
    );
  }

  /// Gets days remaining in trial (negative if expired)
  int? get daysRemainingInTrial {
    if (trialEndDate == null) return null;
    final now = DateTime.now();
    return trialEndDate!.difference(now).inDays;
  }

  /// Gets days remaining in free period (negative if expired)
  int? get daysRemainingInFree {
    if (freeEndDate == null) return null;
    final now = DateTime.now();
    return freeEndDate!.difference(now).inDays;
  }

  /// Returns true if on trial
  bool get isOnTrial => currentPlan == 'trial';

  /// Returns true if on free plan
  bool get isOnFree => currentPlan == 'free';

  /// Returns true if account is locked
  bool get isLocked => status == 'locked';

  /// Returns true if on a paid plan
  bool get isOnPaidPlan => !isOnTrial && !isOnFree && currentPlan != 'trial' && currentPlan != 'free';
}

/// Result of a feature access check
class FeatureAccessResult {
  final bool hasAccess;
  final String reason;
  final bool requiresUpgrade;
  final String currentPlan;
  final String? suggestedPlan;

  FeatureAccessResult({
    required this.hasAccess,
    required this.reason,
    required this.requiresUpgrade,
    required this.currentPlan,
    this.suggestedPlan,
  });
}
