import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/subscription_plan.dart';
import '../services/subscription_service.dart';
import '../services/subscription_token_service.dart';
import '../widgets/plan_card.dart';

/// Public subscription management screen for customers (accessed via secure token link)
class CustomerSubscriptionManagementScreen extends StatefulWidget {
  final String token;

  const CustomerSubscriptionManagementScreen({
    super.key,
    required this.token,
  });

  @override
  State<CustomerSubscriptionManagementScreen> createState() =>
      _CustomerSubscriptionManagementScreenState();
}

class _CustomerSubscriptionManagementScreenState
    extends State<CustomerSubscriptionManagementScreen> {
  final SubscriptionTokenService _tokenService = SubscriptionTokenService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  // Token validation results
  Map<String, dynamic>? _tokenData;
  String? _companyId;
  Map<String, dynamic>? _companyData;

  // Subscription data
  List<SubscriptionPlan> _plans = [];
  CompanySubscription? _currentSubscription;
  bool _isYearly = false;
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _validateTokenAndLoadData();
  }

  Future<void> _validateTokenAndLoadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Validate the token
      final tokenData = await _tokenService.validateToken(widget.token);

      if (tokenData == null) {
        setState(() {
          _error = 'Invalid or expired link. This subscription management link may have '
              'already been used or has expired after 72 hours. Please contact your '
              'account manager for a new link.';
          _isLoading = false;
        });
        return;
      }

      // Token is valid, extract company data
      _tokenData = tokenData;
      _companyId = tokenData['companyId'] as String;
      _companyData = tokenData['companyData'] as Map<String, dynamic>;

      // Load subscription data
      final results = await Future.wait([
        _subscriptionService.getAllPlans(),
        _subscriptionService.getCompanySubscription(_companyId!),
      ]);

      setState(() {
        _plans = results[0] as List<SubscriptionPlan>;
        _currentSubscription = results[1] as CompanySubscription;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading subscription data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePlanChange() async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subscription plan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if same as current plan
    if (_selectedPlanId == _currentSubscription?.currentPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is already your current plan'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show confirmation dialog
      final confirmed = await _showConfirmationDialog();
      if (!confirmed) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Get the selected plan
      final selectedPlan = _plans.firstWhere((p) => p.planId == _selectedPlanId);
      final billingCycle = _isYearly ? 'yearly' : 'monthly';

      // Call Cloud Function to update subscription (bypasses security rules)
      final callable = FirebaseFunctions.instance.httpsCallable('updateSubscriptionViaToken');
      final result = await callable.call({
        'token': widget.token,
        'newPlan': _selectedPlanId,
        'billingCycle': billingCycle,
      });

      // Show success message
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Success!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your subscription has been updated to ${selectedPlan.name} '
                  '(${_isYearly ? "Yearly" : "Monthly"} billing).',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The changes will take effect immediately. You can now close this page.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Reload data to show updated subscription
                  _validateTokenAndLoadData();
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating subscription: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final selectedPlan = _plans.firstWhere((p) => p.planId == _selectedPlanId);
    final price = _isYearly ? selectedPlan.priceYearly : selectedPlan.priceMonthly;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Subscription Change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to change your subscription to:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPlan.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${price.toStringAsFixed(2)} / ${_isYearly ? "year" : "month"}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This change will take effect immediately.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Change'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Your Subscription'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildSubscriptionManagementView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Subscription',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionManagementView() {
    final businessName = _companyData?['businessName'] ?? 'Your Company';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company info header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Plan: ${_getCurrentPlanName()}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Billing cycle toggle
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBillingToggleButton('Monthly', !_isYearly),
                  _buildBillingToggleButton('Yearly', _isYearly),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Available plans
          const Text(
            'Available Plans',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Display plans in a grid
          LayoutBuilder(
            builder: (context, constraints) {
              // Use 2 columns for larger screens, 1 for mobile
              final crossAxisCount = constraints.maxWidth > 800 ? 4 :
                                    constraints.maxWidth > 600 ? 2 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _plans.length,
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  final isCurrentPlan = plan.planId == _currentSubscription?.currentPlan;
                  final isSelected = plan.planId == _selectedPlanId;

                  return _buildPlanCard(plan, isCurrentPlan, isSelected);
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Update button
          if (_selectedPlanId != null && _selectedPlanId != _currentSubscription?.currentPlan)
            Center(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePlanChange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Update Subscription'),
              ),
            ),

          const SizedBox(height: 24),

          // Security notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This secure link can only be used once and will expire after use.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggleButton(String label, bool isActive) {
    return InkWell(
      onTap: () {
        setState(() {
          _isYearly = label == 'Yearly';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, bool isCurrentPlan, bool isSelected) {
    final price = _isYearly ? plan.priceYearly : plan.priceMonthly;

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Colors.blue.shade700
              : isCurrentPlan
                  ? Colors.green.shade700
                  : Colors.grey.shade300,
          width: isSelected || isCurrentPlan ? 3 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPlanId = plan.planId;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan name and badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isCurrentPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Current',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Price
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              Text(
                '/${_isYearly ? "year" : "month"}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 16),

              // Features
              Expanded(
                child: ListView(
                  children: plan.getKeyFeatures().map((feature) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Select button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isCurrentPlan
                      ? null
                      : () {
                          setState(() {
                            _selectedPlanId = plan.planId;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.blue.shade700
                        : Colors.grey.shade200,
                    foregroundColor: isSelected ? Colors.white : Colors.black87,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  child: Text(
                    isCurrentPlan ? 'Current Plan' : isSelected ? 'Selected' : 'Select Plan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentPlanName() {
    if (_currentSubscription == null) return 'Unknown';

    try {
      final currentPlan = _plans.firstWhere(
        (p) => p.planId == _currentSubscription!.currentPlan,
      );
      return currentPlan.name;
    } catch (e) {
      return _currentSubscription!.currentPlan;
    }
  }
}
