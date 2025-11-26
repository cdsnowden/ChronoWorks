import 'package:flutter/material.dart';
import '../../models/subscription_plan.dart';
import '../../services/subscription_service.dart';
import '../../widgets/plan_card.dart';
import 'company_signup_form_screen.dart';

/// Plan selection screen - can be used standalone or in selection mode
class PlanSelectionScreen extends StatefulWidget {
  final bool isSelectionMode;

  const PlanSelectionScreen({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = true;
  bool _isYearly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plans = await _subscriptionService.getAllPlans();
      setState(() {
        _plans = plans.where((p) => p.isVisible).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handlePlanSelection(SubscriptionPlan plan) {
    final billingCycle = _isYearly ? 'yearly' : 'monthly';

    if (widget.isSelectionMode) {
      // Return the selected plan to the calling screen
      Navigator.pop(context, {
        'plan': plan,
        'billingCycle': billingCycle,
      });
    } else {
      // Navigate to company information form with selected plan
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompanySignupFormScreen(
            selectedPlan: plan,
            billingCycle: billingCycle,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
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
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFC62828)),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Plans',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPlans,
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
        // Header section
        _buildHeader(),

        // Billing cycle toggle
        _buildBillingCycleToggle(),

        // Plans grid
        Expanded(
          child: _buildPlansGrid(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D47A1),
            const Color(0xFF1A237E),
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Welcome to ChronoWorks',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the plan that best fits your needs',
            style: TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '✓ 60-Day Free Trial • No Credit Card Required',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCycleToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Monthly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Switch(
            value: _isYearly,
            onChanged: (value) {
              setState(() {
                _isYearly = value;
              });
            },
            activeColor: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 12),
          const Text('Yearly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E7D32)),
            ),
            child: const Text(
              'SAVE 17%',
              style: TextStyle(
                color: Color(0xFF2E7D32),
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

            return PlanCard(
              plan: plan,
              isYearly: _isYearly,
              isCurrent: false,
              onSelect: () => _handlePlanSelection(plan),
              buttonText: 'Get Started',
            );
          },
        );
      },
    );
  }
}
