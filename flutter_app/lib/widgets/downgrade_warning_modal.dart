import 'package:flutter/material.dart';
import '../models/subscription_plan.dart';

/// Modal dialog for warning about plan downgrades
class DowngradeWarningModal extends StatelessWidget {
  final SubscriptionPlan currentPlan;
  final SubscriptionPlan newPlan;
  final bool isYearly;
  final DateTime? nextBillingDate;

  const DowngradeWarningModal({
    super.key,
    required this.currentPlan,
    required this.newPlan,
    required this.isYearly,
    this.nextBillingDate,
  });

  @override
  Widget build(BuildContext context) {
    final lostFeatures = _getLostFeatures();
    final effectiveDate =
        nextBillingDate ?? DateTime.now().add(const Duration(days: 30));

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Text('Confirm Downgrade'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning message
              _buildWarningBanner(context),

              const SizedBox(height: 24),

              // Plan change indicator
              _buildPlanChangeIndicator(context),

              const SizedBox(height: 24),

              // Effective date info
              _buildEffectiveDateInfo(context, effectiveDate),

              const SizedBox(height: 24),

              // Lost features
              if (lostFeatures.isNotEmpty) _buildLostFeatures(context, lostFeatures),

              const SizedBox(height: 16),

              // Savings info
              _buildSavingsInfo(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('CONFIRM DOWNGRADE'),
        ),
      ],
    );
  }

  Widget _buildWarningBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your plan will be downgraded at the end of your current billing period. '
              'You\'ll keep all features until then.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanChangeIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                currentPlan.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${(isYearly ? currentPlan.priceYearly : currentPlan.priceMonthly).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                newPlan.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
              Text(
                '\$${(isYearly ? newPlan.priceYearly : newPlan.priceMonthly).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffectiveDateInfo(BuildContext context, DateTime effectiveDate) {
    final formattedDate = _formatDate(effectiveDate);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Effective Date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your plan will change to ${newPlan.name} on $formattedDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLostFeatures(BuildContext context, List<String> lostFeatures) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features You\'ll Lose',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: lostFeatures
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsInfo(BuildContext context) {
    final currentPrice =
        isYearly ? currentPlan.priceYearly : currentPlan.priceMonthly;
    final newPrice = isYearly ? newPlan.priceYearly : newPlan.priceMonthly;
    final monthlySavings =
        isYearly ? (currentPrice - newPrice) / 12 : (currentPrice - newPrice);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.savings, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You\'ll save \$${monthlySavings.toStringAsFixed(2)}/month with this change',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getLostFeatures() {
    final lostFeatures = <String>[];

    // Compare features between plans
    currentPlan.features.forEach((feature, enabled) {
      if (enabled && !(newPlan.features[feature] ?? false)) {
        // Feature exists in current but not in new plan
        lostFeatures.add(_featureNameToDisplayName(feature));
      }
    });

    // Check for employee limit reduction
    if (currentPlan.maxEmployees > newPlan.maxEmployees) {
      lostFeatures.add(
        'Employee limit reduced to ${newPlan.maxEmployees}',
      );
    }

    // Check for location limit reduction
    if (currentPlan.maxLocations > newPlan.maxLocations) {
      lostFeatures.add(
        'Location limit reduced to ${newPlan.maxLocations}',
      );
    }

    // Check for data retention reduction
    if (currentPlan.dataRetention > newPlan.dataRetention) {
      lostFeatures.add(
        'Data retention reduced to ${newPlan.dataRetention} days',
      );
    }

    return lostFeatures;
  }

  String _featureNameToDisplayName(String featureKey) {
    // Convert camelCase feature keys to display names
    final displayNames = {
      'overtimeTracking': 'Overtime Tracking',
      'missedClockoutAlerts': 'Missed Clockout Alerts',
      'lateClockInAlerts': 'Late Clock-in Alerts',
      'photoVerification': 'Photo Verification',
      'gpsTracking': 'GPS Tracking',
      'advancedReporting': 'Advanced Reporting',
      'exportData': 'Data Export',
      'shiftSwapping': 'Shift Swapping',
      'payrollIntegration': 'Payroll Integration',
      'apiAccess': 'API Access',
      'departmentManagement': 'Department Management',
      'autoScheduling': 'Auto Scheduling',
      'laborCostTracking': 'Labor Cost Tracking',
      'paidTimeOff': 'Paid Time Off',
      'customDashboards': 'Custom Dashboards',
      'roleBasedPermissions': 'Role-Based Permissions',
      'customIntegrations': 'Custom Integrations',
      'biometricClockIn': 'Biometric Clock-in',
      'teamMessaging': 'Team Messaging',
      'complianceReports': 'Compliance Reports',
      'prioritySupport': 'Priority Support',
      'dedicatedManager': 'Dedicated Account Manager',
    };

    return displayNames[featureKey] ?? featureKey;
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
