import 'package:flutter/material.dart';
import '../../routes.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF1565C0)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.access_time_filled, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ChronoWorks', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
            child: const Text('Login', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(isMobile),
            _buildPricingGrid(context, isMobile),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 40 : 60, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF8FAFF), Color(0xFFEEF4FF)]),
      ),
      child: Column(
        children: [
          Text('Simple, Transparent Pricing', style: TextStyle(fontSize: isMobile ? 32 : 42, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Choose the plan that fits your business.', style: TextStyle(fontSize: 18, color: Color(0xFF4A4A5A)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text('60-Day Free Trial', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    SizedBox(width: 8),
                    Icon(Icons.celebration, color: Colors.white, size: 24),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('First 30 days: All features unlocked', style: TextStyle(fontSize: 14, color: Colors.white)),
                const Text('Next 30 days: Starter features included', style: TextStyle(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Start Your Free Trial', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggle('Monthly', !_isYearly, () => setState(() => _isYearly = false)),
                _buildToggle('Yearly (Save 20%)', _isYearly, () => setState(() => _isYearly = true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: isActive ? const Color(0xFF1E88E5) : Colors.transparent, borderRadius: BorderRadius.circular(25)),
        child: Text(text, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF4A4A5A), fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildPricingGrid(BuildContext context, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 40),
      child: Wrap(
        spacing: 24, runSpacing: 24, alignment: WrapAlignment.center,
        children: [
          _buildPlanCard(context, 'Starter', 29, '1-10', ['Time tracking', 'Basic scheduling', 'Mobile app', 'Email support'], Colors.grey, isMobile, false),
          _buildPlanCard(context, 'Bronze', 49, '11-25', ['Everything in Starter', 'GPS geofencing', 'PTO management', 'Basic reports'], const Color(0xFFCD7F32), isMobile, false),
          _buildPlanCard(context, 'Silver', 99, '26-50', ['Everything in Bronze', 'Face recognition', 'Advanced analytics', 'Priority support'], const Color(0xFFC0C0C0), isMobile, true),
          _buildPlanCard(context, 'Gold', 199, '51-100', ['Everything in Silver', 'Payroll export', 'Compliance alerts', 'Dedicated support'], const Color(0xFFFFD700), isMobile, false),
          _buildPlanCard(context, 'Platinum', 399, '101-250', ['Everything in Gold', 'Multi-location', 'White-glove onboarding', 'Account manager'], const Color(0xFFE5E4E2), isMobile, false),
          _buildPlanCard(context, 'Diamond', 799, '251+', ['Everything in Platinum', 'Unlimited locations', 'API access', '24/7 phone support'], const Color(0xFFB9F2FF), isMobile, false),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, String name, int monthlyPrice, String employees, List<String> features, Color color, bool isMobile, bool isPopular) {
    final price = _isYearly ? (monthlyPrice * 0.8).round() : monthlyPrice;
    return Container(
      width: isMobile ? double.infinity : 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPopular ? const Color(0xFF1E88E5) : const Color(0xFFE5E7EB), width: isPopular ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(12)),
            child: const Text('Most Popular', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$' + price.toString(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            const Text('/mo', style: TextStyle(fontSize: 16, color: Color(0xFF4A4A5A))),
          ]),
          const SizedBox(height: 8),
          Text('\$employees employees', style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A5A))),
          const SizedBox(height: 20),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(f, style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A5A)))),
            ]),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? const Color(0xFF1E88E5) : Colors.white,
                foregroundColor: isPopular ? Colors.white : const Color(0xFF1E88E5),
                side: isPopular ? null : const BorderSide(color: Color(0xFF1E88E5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      color: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          const Text('Questions? We are here to help.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          const Text('Contact us at contact@chronoworks.co', style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Start Your Free Trial', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
