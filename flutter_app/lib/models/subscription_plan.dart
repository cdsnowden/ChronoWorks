/// Represents a subscription plan with pricing and features
class SubscriptionPlan {
  final String planId;
  final String name;
  final String description;
  final String tagline;

  final double priceMonthly;
  final double priceYearly;
  final String currency;

  final int maxEmployees;
  final int maxLocations;
  final int dataRetention;

  final Map<String, bool> features;

  final int displayOrder;
  final bool isPopular;
  final bool isVisible;

  final int level;

  SubscriptionPlan({
    required this.planId,
    required this.name,
    required this.description,
    required this.tagline,
    required this.priceMonthly,
    required this.priceYearly,
    required this.currency,
    required this.maxEmployees,
    required this.maxLocations,
    required this.dataRetention,
    required this.features,
    required this.displayOrder,
    required this.isPopular,
    required this.isVisible,
    required this.level,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      planId: json['planId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      priceMonthly: (json['priceMonthly'] as num).toDouble(),
      priceYearly: (json['priceYearly'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      maxEmployees: json['maxEmployees'] as int,
      maxLocations: json['maxLocations'] as int? ?? 1,
      dataRetention: json['dataRetention'] as int? ?? 30,
      features: Map<String, bool>.from(json['features'] as Map? ?? {}),
      displayOrder: json['displayOrder'] as int? ?? 0,
      isPopular: json['isPopular'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      level: json['level'] as int? ?? 0,
    );
  }

  /// Calculate yearly savings
  double get yearlySavings {
    if (priceMonthly == 0) return 0;
    final monthlyTotal = priceMonthly * 12;
    return monthlyTotal - priceYearly;
  }

  /// Calculate yearly savings percentage
  double get yearlySavingsPercent {
    if (priceMonthly == 0) return 0;
    final monthlyTotal = priceMonthly * 12;
    return ((monthlyTotal - priceYearly) / monthlyTotal) * 100;
  }

  /// Format price for display
  String formatPrice(bool yearly) {
    final price = yearly ? priceYearly : priceMonthly;
    if (price == 0) return 'Free';
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Get billing period label
  String billingPeriodLabel(bool yearly) {
    if (priceMonthly == 0) return '';
    return yearly ? '/year' : '/month';
  }

  /// Check if a specific feature is enabled
  bool hasFeature(String featureKey) {
    return features[featureKey] ?? false;
  }

  /// Get list of key features for display
  List<String> getKeyFeatures() {
    final List<String> keyFeatures = [];

    // Employee limit
    if (maxEmployees == 999999) {
      keyFeatures.add('Unlimited employees');
    } else {
      keyFeatures.add('Up to $maxEmployees employees');
    }

    // Location limit
    if (maxLocations > 1) {
      keyFeatures.add('$maxLocations locations');
    }

    // Core features
    if (hasFeature('clockInOut')) {
      keyFeatures.add('Clock in/out');
    }
    if (hasFeature('scheduleManagement')) {
      keyFeatures.add('Schedule management');
    }
    if (hasFeature('breakTracking')) {
      keyFeatures.add('Break tracking');
    }
    if (hasFeature('shiftTemplates')) {
      keyFeatures.add('Shift templates');
    }
    if (hasFeature('basicReporting')) {
      keyFeatures.add('Basic reporting');
    }

    // Alerts & Notifications
    if (hasFeature('missedClockoutAlerts')) {
      keyFeatures.add('Missed clockout alerts');
    }
    if (hasFeature('lateClockInAlerts')) {
      keyFeatures.add('Late clock-in alerts');
    }

    // Advanced features
    if (hasFeature('overtimeTracking')) {
      keyFeatures.add('Overtime tracking');
    }
    if (hasFeature('photoVerification')) {
      keyFeatures.add('Photo verification');
    }
    if (hasFeature('gpsTracking')) {
      keyFeatures.add('GPS tracking');
    }
    if (hasFeature('advancedReporting')) {
      keyFeatures.add('Advanced reporting');
    }
    if (hasFeature('exportData')) {
      keyFeatures.add('Export data');
    }
    if (hasFeature('shiftSwapping')) {
      keyFeatures.add('Shift swapping');
    }
    if (hasFeature('payrollIntegration')) {
      keyFeatures.add('Payroll integration');
    }
    if (hasFeature('apiAccess')) {
      keyFeatures.add('API access');
    }

    // Support
    if (hasFeature('emailSupport')) {
      keyFeatures.add('Email support');
    }
    if (hasFeature('prioritySupport')) {
      keyFeatures.add('Priority support');
    }
    if (hasFeature('phoneSupport')) {
      keyFeatures.add('Phone support');
    }
    if (hasFeature('dedicatedManager')) {
      keyFeatures.add('Dedicated account manager');
    }

    return keyFeatures;
  }
}

/// Represents a preview of plan change costs
class PlanChangePreview {
  final bool success;
  final String currentPlan;
  final String currentPlanName;
  final String? currentBillingCycle;
  final String newPlan;
  final String newPlanName;
  final String newBillingCycle;
  final bool isUpgrade;
  final bool immediate;
  final double proratedCredit;
  final double newPlanCharge;
  final double totalDueToday;
  final double savings;
  final String? nextBillingDate;
  final bool hasPaymentMethod;

  PlanChangePreview({
    required this.success,
    required this.currentPlan,
    required this.currentPlanName,
    this.currentBillingCycle,
    required this.newPlan,
    required this.newPlanName,
    required this.newBillingCycle,
    required this.isUpgrade,
    required this.immediate,
    required this.proratedCredit,
    required this.newPlanCharge,
    required this.totalDueToday,
    required this.savings,
    this.nextBillingDate,
    required this.hasPaymentMethod,
  });

  factory PlanChangePreview.fromJson(Map<String, dynamic> json) {
    return PlanChangePreview(
      success: json['success'] as bool,
      currentPlan: json['currentPlan'] as String,
      currentPlanName: json['currentPlanName'] as String,
      currentBillingCycle: json['currentBillingCycle'] as String?,
      newPlan: json['newPlan'] as String,
      newPlanName: json['newPlanName'] as String,
      newBillingCycle: json['newBillingCycle'] as String,
      isUpgrade: json['isUpgrade'] as bool,
      immediate: json['immediate'] as bool,
      proratedCredit: (json['proratedCredit'] as num).toDouble(),
      newPlanCharge: (json['newPlanCharge'] as num).toDouble(),
      totalDueToday: (json['totalDueToday'] as num).toDouble(),
      savings: (json['savings'] as num? ?? 0).toDouble(),
      nextBillingDate: json['nextBillingDate'] as String?,
      hasPaymentMethod: json['hasPaymentMethod'] as bool,
    );
  }
}

/// Result of a plan change operation
class PlanChangeResult {
  final bool success;
  final String message;
  final String effectiveDate;
  final bool immediate;
  final String changeType;
  final double? proratedCredit;
  final double? proratedCharge;
  final double? totalDueToday;
  final String? nextBillingDate;

  PlanChangeResult({
    required this.success,
    required this.message,
    required this.effectiveDate,
    required this.immediate,
    required this.changeType,
    this.proratedCredit,
    this.proratedCharge,
    this.totalDueToday,
    this.nextBillingDate,
  });

  factory PlanChangeResult.fromJson(Map<String, dynamic> json) {
    return PlanChangeResult(
      success: json['success'] as bool,
      message: json['message'] as String,
      effectiveDate: json['effectiveDate'] as String,
      immediate: json['immediate'] as bool,
      changeType: json['changeType'] as String,
      proratedCredit: (json['proratedCredit'] as num?)?.toDouble(),
      proratedCharge: (json['proratedCharge'] as num?)?.toDouble(),
      totalDueToday: (json['totalDueToday'] as num?)?.toDouble(),
      nextBillingDate: json['nextBillingDate'] as String?,
    );
  }
}
