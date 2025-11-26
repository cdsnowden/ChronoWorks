import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

/// Banner widget that displays trial/free plan status and warnings
class TrialStatusBanner extends StatelessWidget {
  final CompanySubscription subscription;
  final VoidCallback onChoosePlan;

  const TrialStatusBanner({
    Key? key,
    required this.subscription,
    required this.onChoosePlan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show banner if on paid plan or locked
    if (subscription.isOnPaidPlan || subscription.isLocked) {
      return const SizedBox.shrink();
    }

    if (subscription.isOnTrial) {
      return _buildTrialBanner(context);
    } else if (subscription.isOnFree) {
      return _buildFreeBanner(context);
    }

    return const SizedBox.shrink();
  }

  /// Builds the trial status banner
  Widget _buildTrialBanner(BuildContext context) {
    final daysLeft = subscription.daysRemainingInTrial ?? 0;
    final totalDays = 30;
    final progress = (totalDays - daysLeft) / totalDays;

    // Determine color and urgency based on days remaining
    Color bannerColor;
    Color progressColor;
    String urgencyText;
    IconData icon;

    if (daysLeft <= 3) {
      bannerColor = Colors.red.shade50;
      progressColor = Colors.red;
      urgencyText = 'Trial ending very soon!';
      icon = Icons.warning_amber_rounded;
    } else if (daysLeft <= 7) {
      bannerColor = Colors.orange.shade50;
      progressColor = Colors.orange;
      urgencyText = 'Trial ending soon';
      icon = Icons.access_time_rounded;
    } else {
      bannerColor = Colors.blue.shade50;
      progressColor = Colors.blue;
      urgencyText = 'Trial active';
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: progressColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: progressColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urgencyText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} remaining in your 30-day trial',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onChoosePlan,
                icon: const Icon(Icons.star, size: 18),
                label: const Text('Choose a Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: progressColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          // Info text
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  daysLeft <= 3
                      ? 'Choose a plan now to avoid downgrade to Free plan (limited features)'
                      : 'After trial: Downgrade to Free plan or choose a paid plan to keep all features',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the free plan status banner
  Widget _buildFreeBanner(BuildContext context) {
    final daysLeft = subscription.daysRemainingInFree ?? 0;
    final totalDays = 30;
    final progress = (totalDays - daysLeft) / totalDays;

    // Determine color and urgency based on days remaining
    Color bannerColor;
    Color progressColor;
    String urgencyText;
    IconData icon;

    if (daysLeft <= 3) {
      bannerColor = Colors.red.shade50;
      progressColor = Colors.red;
      urgencyText = 'Account will be locked in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}!';
      icon = Icons.lock_clock_rounded;
    } else if (daysLeft <= 7) {
      bannerColor = Colors.orange.shade50;
      progressColor = Colors.orange;
      urgencyText = 'Free period ending soon';
      icon = Icons.warning_amber_rounded;
    } else {
      bannerColor = Colors.grey.shade100;
      progressColor = Colors.grey.shade700;
      urgencyText = 'Free Plan Active';
      icon = Icons.account_circle_outlined;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: progressColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: progressColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urgencyText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysLeft <= 0
                          ? 'Your free period has expired'
                          : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left on Free plan',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onChoosePlan,
                icon: const Icon(Icons.upgrade, size: 18),
                label: const Text('Upgrade Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: daysLeft <= 3 ? Colors.red : progressColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          // Warning text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: progressColor.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: progressColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Plan Limitations:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Max 10 employees\n'
                        '• Basic reporting (last 7 days only)\n'
                        '• No overtime tracking or advanced features',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        daysLeft <= 3
                            ? '⚠️ Your account will be LOCKED if you don\'t upgrade!'
                            : 'Upgrade to unlock all features and prevent account lock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: daysLeft <= 3 ? Colors.red : progressColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact trial status widget for app bar or smaller spaces
class CompactTrialStatus extends StatelessWidget {
  final CompanySubscription subscription;
  final VoidCallback onTap;

  const CompactTrialStatus({
    Key? key,
    required this.subscription,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show if on paid plan or locked
    if (subscription.isOnPaidPlan || subscription.isLocked) {
      return const SizedBox.shrink();
    }

    final daysLeft = subscription.isOnTrial
        ? subscription.daysRemainingInTrial
        : subscription.daysRemainingInFree;

    if (daysLeft == null || daysLeft < 0) {
      return const SizedBox.shrink();
    }

    final bool isUrgent = daysLeft <= 3;
    final Color color = isUrgent ? Colors.red : Colors.orange;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUrgent ? Icons.warning_amber_rounded : Icons.access_time_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
