import 'package:flutter/material.dart';
import '../routes.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 70,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF1565C0)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.access_time_filled, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Text('ChronoWorks', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: -0.5)),
              ],
            ),
            actions: [
              if (!isMobile) ...[
                
                TextButton(onPressed: () => Navigator.of(context).pushNamed(AppRoutes.pricing), child: const Text('Pricing', style: TextStyle(color: Color(0xFF4A4A5A), fontSize: 15, fontWeight: FontWeight.w500))),
              ],
              const SizedBox(width: 8),
              TextButton(onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login), child: const Text('Login', style: TextStyle(color: Color(0xFF1E88E5), fontSize: 15, fontWeight: FontWeight.w600))),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  child: const Text('Start Free Trial', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeroSection(context, isMobile),
                _buildFeaturesSection(context, isMobile),
                _buildStatsSection(context, isMobile),
                _buildBenefitsSection(context, isMobile),
                _buildTestimonialSection(context, isMobile),
                _buildCtaSection(context, isMobile),
                _buildFooter(context, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF8FAFF), Color(0xFFEEF4FF)])),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: isMobile ? 20 : 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.2))),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.verified, color: Color(0xFF1E88E5), size: 18), SizedBox(width: 8), Text('Trusted by 500+ Businesses Nationwide', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w600, fontSize: 14))],
            ),
          ),
          const SizedBox(height: 32),
          Text('Workforce Management\nMade Simple', style: TextStyle(fontSize: isMobile ? 40 : 56, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E), height: 1.1, letterSpacing: -1), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: const Text('The all-in-one platform for time tracking, scheduling, compliance, and payroll. Biometric verification, GPS geofencing, and 50-state labor law compliance built in.', style: TextStyle(fontSize: 20, color: Color(0xFF4A4A5A), height: 1.6), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Start Your Free Trial', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 20)]),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), side: const BorderSide(color: Color(0xFF1E88E5), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Sign In to Your Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1E88E5))),
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Wrap(
            spacing: 32, runSpacing: 16, alignment: WrapAlignment.center,
            children: [_TrustBadge(icon: Icons.restaurant, label: 'Restaurants'), _TrustBadge(icon: Icons.local_hospital, label: 'Healthcare'), _TrustBadge(icon: Icons.storefront, label: 'Retail'), _TrustBadge(icon: Icons.engineering, label: 'Construction'), _TrustBadge(icon: Icons.cleaning_services, label: 'Services')],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: isMobile ? 20 : 40),
      color: Colors.white,
      child: Column(
        children: [
          const Text('POWERFUL FEATURES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E88E5), letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text('Everything You Need to Manage\nYour Workforce', style: TextStyle(fontSize: isMobile ? 32 : 42, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E), height: 1.2), textAlign: TextAlign.center),
          const SizedBox(height: 64),
          const Wrap(
            spacing: 24, runSpacing: 24, alignment: WrapAlignment.center,
            children: [
              _ModernFeatureCard(icon: Icons.face, title: 'Biometric Clock-In', description: 'Face recognition verification prevents buddy punching and ensures accurate attendance records.', gradient: [Color(0xFF667EEA), Color(0xFF764BA2)]),
              _ModernFeatureCard(icon: Icons.calendar_month, title: 'Smart Scheduling', description: 'Easy scheduling with shift templates, conflict detection, and automatic notifications.', gradient: [Color(0xFF11998E), Color(0xFF38EF7D)]),
              _ModernFeatureCard(icon: Icons.location_on, title: 'GPS Geofencing', description: 'Ensure employees clock in from authorized locations with customizable geofence boundaries.', gradient: [Color(0xFFFF6B6B), Color(0xFFFFE66D)]),
              _ModernFeatureCard(icon: Icons.payments, title: 'Payroll Export', description: 'One-click payroll reports with automatic overtime calculations and PTO tracking.', gradient: [Color(0xFF4FACFE), Color(0xFF00F2FE)]),
              _ModernFeatureCard(icon: Icons.beach_access, title: 'PTO Management', description: 'Streamlined time-off requests with manager approvals, balance tracking, and blackout dates.', gradient: [Color(0xFFF093FB), Color(0xFFF5576C)]),
              _ModernFeatureCard(icon: Icons.gavel, title: '50-State Compliance', description: 'Stay compliant with labor laws across all 50 states with automatic rule updates.', gradient: [Color(0xFF5B86E5), Color(0xFF36D1DC)]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 80, horizontal: isMobile ? 20 : 40),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E88E5), Color(0xFF1565C0)])),
      child: Column(
        children: [
          Text('Why Businesses Choose ChronoWorks', style: TextStyle(fontSize: isMobile ? 28 : 36, fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 48),
          const Wrap(
            spacing: 48, runSpacing: 32, alignment: WrapAlignment.center,
            children: [
              _StatCard(value: '80%', label: 'Reduction in\nPayroll Errors'),
              _StatCard(value: '5+ hrs', label: 'Saved per Week\non Admin Tasks'),
              _StatCard(value: '99.9%', label: 'Uptime\nGuarantee'),
              _StatCard(value: '24/7', label: 'Customer\nSupport'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: isMobile ? 20 : 40),
      color: const Color(0xFFF8FAFF),
      child: Column(
        children: [
          Text('Built for Modern Businesses', style: TextStyle(fontSize: isMobile ? 32 : 42, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: const Text('From small teams to enterprise organizations, ChronoWorks scales with your business.', style: TextStyle(fontSize: 18, color: Color(0xFF4A4A5A), height: 1.6), textAlign: TextAlign.center)),
          const SizedBox(height: 48),
          const Wrap(
            spacing: 24, runSpacing: 24, alignment: WrapAlignment.center,
            children: [
              _BenefitCard(icon: Icons.speed, title: 'Fast Setup', description: 'Get started in minutes with our intuitive onboarding process.'),
              _BenefitCard(icon: Icons.phone_android, title: 'Mobile First', description: 'Native iOS and Android apps for on-the-go workforce management.'),
              _BenefitCard(icon: Icons.lock, title: 'Enterprise Security', description: 'Bank-level encryption and SOC 2 compliant infrastructure.'),
              _BenefitCard(icon: Icons.sync, title: 'Real-Time Sync', description: 'Instant updates across all devices and platforms.'),
              _BenefitCard(icon: Icons.analytics, title: 'Advanced Analytics', description: 'Actionable insights with customizable reports and dashboards.'),
              _BenefitCard(icon: Icons.support_agent, title: 'Dedicated Support', description: 'US-based support team available whenever you need help.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialSection(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 80, horizontal: isMobile ? 20 : 40),
      color: Colors.white,
      child: Column(
        children: [
          const Icon(Icons.format_quote, size: 48, color: Color(0xFF1E88E5)),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Text('"ChronoWorks transformed how we manage our 200+ employees across 12 locations. The geofencing and face recognition features eliminated time theft completely, saving us over  ,000 annually."', style: TextStyle(fontSize: isMobile ? 20 : 24, color: const Color(0xFF1A1A2E), fontStyle: FontStyle.italic, height: 1.6), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 32),
          const Text('Sarah Mitchell', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          const Text('HR Director, Metro Healthcare Group', style: TextStyle(fontSize: 16, color: Color(0xFF4A4A5A))),
        ],
      ),
    );
  }

  Widget _buildCtaSection(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 100, horizontal: isMobile ? 20 : 40),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF1A1A2E), const Color(0xFF1A1A2E).withOpacity(0.95)])),
      child: Column(
        children: [
          Text('Ready to Transform Your\nWorkforce Management?', style: TextStyle(fontSize: isMobile ? 32 : 42, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const Text('Join thousands of businesses saving time and money with ChronoWorks.', style: TextStyle(fontSize: 18, color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('View Plans & Pricing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), side: const BorderSide(color: Colors.white70, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Sign In', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 40 : 60, horizontal: isMobile ? 20 : 40),
      color: const Color(0xFF0D0D1A),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.access_time_filled, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('ChronoWorks', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 32, runSpacing: 16, alignment: WrapAlignment.center,
            children: [
              TextButton(onPressed: () {}, child: const Text('Privacy Policy', style: TextStyle(color: Colors.white60))),
              TextButton(onPressed: () {}, child: const Text('Terms of Service', style: TextStyle(color: Colors.white60))),
              TextButton(onPressed: () {}, child: const Text('Contact Us', style: TextStyle(color: Colors.white60))),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 24),
          const Text('\u00a9 2025 ChronoWorks. All rights reserved.', style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ModernFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  const _ModernFeatureCard({required this.icon, required this.title, required this.description, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(fontSize: 15, color: Color(0xFF4A4A5A), height: 1.6)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.4), textAlign: TextAlign.center),
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _BenefitCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 24, color: const Color(0xFF1E88E5)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A5A), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
