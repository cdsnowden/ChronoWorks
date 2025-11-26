import 'package:flutter/material.dart';
import '../models/subscription_plan.dart';

/// Card widget for displaying a subscription plan
class PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isYearly;
  final bool isCurrent;
  final VoidCallback onSelect;
  final String? buttonText;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isYearly,
    required this.isCurrent,
    required this.onSelect,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    final price = isYearly ? plan.priceYearly : plan.priceMonthly;
    final isFree = price == 0;

    return Card(
      elevation: isCurrent ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? BorderSide(color: Theme.of(context).primaryColor, width: 3)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isCurrent
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.05),
                    Colors.white,
                  ],
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with plan name and popular badge
            _buildHeader(context),

            // Pricing
            _buildPricing(context, price, isFree),

            // Tagline
            if (plan.tagline.isNotEmpty) _buildTagline(context),

            const SizedBox(height: 16),

            // Features list
            Expanded(
              child: _buildFeaturesList(context),
            ),

            // Select button
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildActionButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getPlanColor().withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              plan.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getPlanColor(),
              ),
            ),
          ),
          if (plan.isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPricing(BuildContext context, double price, bool isFree) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (isFree)
            const Text(
              'Free',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  price.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          if (!isFree)
            Text(
              isYearly ? '/year' : '/month',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          if (isYearly && !isFree && plan.yearlySavingsPercent > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Save \$${plan.yearlySavings.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagline(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        plan.tagline,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    final keyFeatures = plan.getKeyFeatures();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: keyFeatures.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                size: 18,
                color: _getPlanColor(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  keyFeatures[index],
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isCurrent) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: _getPlanColor()),
        ),
        child: Text(
          'CURRENT PLAN',
          style: TextStyle(
            color: _getPlanColor(),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return FilledButton(
      onPressed: onSelect,
      style: FilledButton.styleFrom(
        backgroundColor: _getPlanColor(),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        buttonText ?? 'SELECT PLAN',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getPlanColor() {
    switch (plan.planId) {
      case 'free':
        return Colors.grey;
      case 'starter':
        return Colors.blue;
      case 'bronze':
        return Colors.brown;
      case 'silver':
        return Colors.blueGrey;
      case 'gold':
        return Colors.amber;
      case 'platinum':
        return Colors.purple;
      case 'diamond':
        return Colors.cyan;
      default:
        return Colors.blue;
    }
  }
}
