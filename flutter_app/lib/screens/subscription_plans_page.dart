import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_plan.dart';
import '../services/subscription_service.dart';
import '../widgets/plan_card.dart';
import '../widgets/upgrade_confirmation_modal.dart';
import '../widgets/downgrade_warning_modal.dart';

/// Main page for viewing and changing subscription plans
class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<SubscriptionPlan> _plans = [];
  CompanySubscription? _currentSubscription;
  Map<String, dynamic>? _billingInfo;
  bool _isLoading = true;
  bool _isYearly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Not authenticated');
      }

      // Get company ID from Firestore user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final companyId = userDoc.data()?['companyId'] as String?;

      if (companyId == null) {
        throw Exception('No company associated with user');
      }

      // Load all data in parallel
      final results = await Future.wait([
        _subscriptionService.getAllPlans(),
        _subscriptionService.getCompanySubscription(companyId),
        _subscriptionService.getCurrentBillingInfo(companyId),
      ]);

      setState(() {
        _plans = results[0] as List<SubscriptionPlan>;
        _currentSubscription = results[1] as CompanySubscription;
        _billingInfo = results[2] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePlanSelection(SubscriptionPlan plan) async {
    if (_currentSubscription == null) return;

    // Check if it's the current plan
    if (plan.planId == _currentSubscription!.currentPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already on this plan'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Determine if it's an upgrade or downgrade
    final currentPlan = _plans.firstWhere(
      (p) => p.planId == _currentSubscription!.currentPlan,
      orElse: () => _plans.first,
    );

    final isUpgrade = plan.level > currentPlan.level;

    // Show appropriate modal
    if (isUpgrade) {
      await _showUpgradeConfirmation(plan);
    } else {
      await _showDowngradeWarning(plan);
    }
  }

  Future<void> _showUpgradeConfirmation(SubscriptionPlan plan) async {
    final billingCycle = _isYearly ? 'yearly' : 'monthly';

    // Get upgrade preview
    final preview = await _showLoadingDialog<PlanChangePreview>(
      future: _subscriptionService.getUpgradePreview(
        newPlan: plan.planId,
        newBillingCycle: billingCycle,
      ),
      loadingMessage: 'Calculating costs...',
    );

    if (preview == null || !mounted) return;

    // Show confirmation modal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => UpgradeConfirmationModal(
        plan: plan,
        preview: preview,
        isYearly: _isYearly,
      ),
    );

    if (confirmed == true) {
      await _executePlanChange(plan.planId, billingCycle);
    }
  }

  Future<void> _showDowngradeWarning(SubscriptionPlan plan) async {
    final billingCycle = _isYearly ? 'yearly' : 'monthly';

    // Get current plan details
    final currentPlan = _plans.firstWhere(
      (p) => p.planId == _currentSubscription!.currentPlan,
    );

    // Show downgrade warning modal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DowngradeWarningModal(
        currentPlan: currentPlan,
        newPlan: plan,
        isYearly: _isYearly,
        nextBillingDate: _billingInfo?['nextBillingDate']?.toDate(),
      ),
    );

    if (confirmed == true) {
      await _executePlanChange(plan.planId, billingCycle);
    }
  }

  Future<void> _executePlanChange(String newPlan, String billingCycle) async {
    final result = await _showLoadingDialog<PlanChangeResult>(
      future: _subscriptionService.changePlan(
        newPlan: newPlan,
        newBillingCycle: billingCycle,
      ),
      loadingMessage: 'Processing plan change...',
    );

    if (result == null || !mounted) return;

    if (result.success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Reload subscription data
      await _loadSubscriptionData();
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleCancelScheduledChange() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scheduled Change?'),
        content: const Text(
          'This will cancel your scheduled plan change and keep you on your current plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP SCHEDULED CHANGE'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CANCEL CHANGE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _showLoadingDialog(
        future: _subscriptionService.cancelScheduledChange(),
        loadingMessage: 'Cancelling scheduled change...',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled plan change cancelled'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadSubscriptionData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<T?> _showLoadingDialog<T>({
    required Future<T> future,
    required String loadingMessage,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(loadingMessage)),
          ],
        ),
      ),
    );

    try {
      final result = await future;
      if (mounted) Navigator.pop(context); // Close loading dialog
      return result;
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error Loading Plans',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadSubscriptionData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Scheduled change banner
        if (_billingInfo?['scheduledPlanChange'] != null)
          _buildScheduledChangeBanner(),

        // Current plan indicator
        if (_currentSubscription != null) _buildCurrentPlanIndicator(),

        // Billing cycle toggle
        _buildBillingCycleToggle(),

        // Plans grid
        Expanded(
          child: _buildPlansGrid(),
        ),
      ],
    );
  }

  Widget _buildScheduledChangeBanner() {
    final scheduledChange =
        _billingInfo!['scheduledPlanChange'] as Map<String, dynamic>;
    final newPlanId = scheduledChange['newPlan'] as String;
    final effectiveDate = (scheduledChange['effectiveDate'] as Timestamp?)?.toDate();

    final newPlan = _plans.firstWhere(
      (p) => p.planId == newPlanId,
      orElse: () => _plans.first,
    );

    return Container(
      color: Colors.blue.shade100,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.blue.shade900),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduled Plan Change',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                Text(
                  'Changing to ${newPlan.name} on ${effectiveDate != null ? _formatDate(effectiveDate) : 'next billing date'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _handleCancelScheduledChange,
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanIndicator() {
    final currentPlan = _plans.firstWhere(
      (p) => p.planId == _currentSubscription!.currentPlan,
      orElse: () => _plans.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            'Current Plan: ${currentPlan.name}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCycleToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Monthly', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Switch(
            value: _isYearly,
            onChanged: (value) {
              setState(() {
                _isYearly = value;
              });
            },
          ),
          const SizedBox(width: 12),
          const Text('Yearly', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Save 17%',
              style: TextStyle(
                color: Colors.green.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine number of columns based on width
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _plans.length,
          itemBuilder: (context, index) {
            final plan = _plans[index];
            final isCurrent = plan.planId == _currentSubscription?.currentPlan;

            return PlanCard(
              plan: plan,
              isYearly: _isYearly,
              isCurrent: isCurrent,
              onSelect: () => _handlePlanSelection(plan),
            );
          },
        );
      },
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
