import 'package:flutter/material.dart';
import '../models/subscription_plan.dart';

/// Modal dialog for confirming plan upgrades with cost breakdown
class UpgradeConfirmationModal extends StatelessWidget {
  final SubscriptionPlan plan;
  final PlanChangePreview preview;
  final bool isYearly;

  const UpgradeConfirmationModal({
    super.key,
    required this.plan,
    required this.preview,
    required this.isYearly,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.arrow_upward, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Text('Upgrade Plan'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Plan change indicator
              _buildPlanChangeIndicator(context),

              const SizedBox(height: 24),

              // Cost breakdown
              _buildCostBreakdown(context),

              const SizedBox(height: 24),

              // New features
              _buildNewFeatures(context),

              // Payment method warning
              if (!preview.hasPaymentMethod) _buildPaymentWarning(context),

              const SizedBox(height: 16),

              // Next billing info
              _buildNextBillingInfo(context),
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
          onPressed: preview.hasPaymentMethod
              ? () => Navigator.pop(context, true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: Text(
            'CONFIRM UPGRADE - \$${preview.totalDueToday.toStringAsFixed(2)}',
          ),
        ),
      ],
    );
  }

  Widget _buildPlanChangeIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            preview.currentPlanName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Text(
            plan.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBreakdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cost Breakdown',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // New plan charge
              _buildCostRow(
                'New Plan Charge',
                preview.newPlanCharge,
                isSubtotal: true,
              ),

              // Prorated credit (if any)
              if (preview.proratedCredit > 0) ...[
                const SizedBox(height: 8),
                _buildCostRow(
                  'Prorated Credit',
                  -preview.proratedCredit,
                  isCredit: true,
                ),
              ],

              const Divider(height: 24),

              // Total due today
              _buildCostRow(
                'Total Due Today',
                preview.totalDueToday,
                isTotal: true,
              ),
            ],
          ),
        ),
        if (isYearly && plan.yearlySavingsPercent > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.savings, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'You\'ll save \$${plan.yearlySavings.toStringAsFixed(2)} per year',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCostRow(
    String label,
    double amount, {
    bool isCredit = false,
    bool isTotal = false,
    bool isSubtotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isCredit ? Colors.green.shade700 : null,
          ),
        ),
        Text(
          '${isCredit ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal || isSubtotal ? FontWeight.bold : FontWeight.normal,
            color: isCredit ? Colors.green.shade700 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildNewFeatures(BuildContext context) {
    final newFeatures = plan.getKeyFeatures().take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Features You\'ll Get',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...newFeatures.map(
          (feature) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentWarning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please add a payment method before upgrading',
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

  Widget _buildNextBillingInfo(BuildContext context) {
    if (preview.nextBillingDate == null) return const SizedBox.shrink();

    final nextBillingDate = DateTime.parse(preview.nextBillingDate!);
    final formattedDate = _formatDate(nextBillingDate);

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
            child: Text(
              'Your next billing date will be $formattedDate for \$${preview.newPlanCharge.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
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
