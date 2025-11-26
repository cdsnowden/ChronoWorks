import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/account_manager.dart';
import '../../services/account_manager_service.dart';
import '../../services/support_ticket_service.dart';
import '../../routes.dart';
import 'assigned_companies_screen.dart';
import '../support/tickets_list_screen.dart';

class AccountManagerDashboardScreen extends StatefulWidget {
  const AccountManagerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AccountManagerDashboardScreen> createState() =>
      _AccountManagerDashboardScreenState();
}

class _AccountManagerDashboardScreenState
    extends State<AccountManagerDashboardScreen> {
  final AccountManagerService _amService = AccountManagerService();
  final SupportTicketService _ticketService = SupportTicketService();

  AccountManager? _accountManager;
  Map<String, int> _ticketStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);

      // Get current Account Manager profile
      AccountManager? am = await _amService.getCurrentAccountManager();

      if (am != null) {
        // Get ticket statistics (with error handling)
        Map<String, int> stats = {};
        try {
          stats = await _ticketService.getTicketStats(am.id);
        } catch (e) {
          // If ticket stats fail, just use empty stats
          // Silently handle - no need to print as it's handled gracefully
          stats = {
            'total': 0,
            'open': 0,
            'inProgress': 0,
            'resolved': 0,
            'urgent': 0,
          };
        }

        setState(() {
          _accountManager = am;
          _ticketStats = stats;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account Manager profile not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Account Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accountManager == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No Account Manager profile found',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Current UID: ${FirebaseAuth.instance.currentUser?.uid ?? "Not logged in"}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Email: ${FirebaseAuth.instance.currentUser?.email ?? "Unknown"}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Debug: The Account Manager document should exist at:\naccountManagers/{UID}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Card
                        _buildWelcomeCard(),
                        const SizedBox(height: 20),

                        // Metrics Cards
                        _buildMetricsSection(),
                        const SizedBox(height: 20),

                        // Ticket Stats
                        _buildTicketStatsSection(),
                        const SizedBox(height: 20),

                        // Quick Actions
                        _buildQuickActionsSection(),
                        const SizedBox(height: 20),

                        // Recent Companies
                        _buildRecentCompaniesSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue,
              backgroundImage: _accountManager?.photoURL != null
                  ? NetworkImage(_accountManager!.photoURL!)
                  : null,
              child: _accountManager?.photoURL == null
                  ? Text(
                      _accountManager?.displayName[0].toUpperCase() ?? 'A',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_accountManager?.displayName ?? 'Account Manager'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _accountManager?.email ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accountManager?.status == 'active'
                          ? Colors.green[100]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _accountManager?.status.toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _accountManager?.status == 'active'
                            ? Colors.green[800]
                            : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    final metrics = _accountManager?.metrics;
    final capacity = _accountManager?.capacityPercentage ?? 0;
    final isAtCapacity = _accountManager?.isAtCapacity ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Metrics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Assigned',
                _accountManager?.assignedCount.toString() ?? '0',
                '${_accountManager?.maxAssignedCompanies ?? 0} max',
                Icons.business,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Active',
                metrics?.activeCustomers.toString() ?? '0',
                'Last 7 days',
                Icons.trending_up,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Trial',
                metrics?.trialCustomers.toString() ?? '0',
                'On trial plan',
                Icons.timer,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Paid',
                metrics?.paidCustomers.toString() ?? '0',
                'Paying customers',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Capacity Indicator
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Capacity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${capacity.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isAtCapacity ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: capacity / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAtCapacity ? Colors.red : Colors.green,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text(
                  isAtCapacity
                      ? 'At capacity - contact Super Admin to increase'
                      : 'Can accept ${(_accountManager!.maxAssignedCompanies - _accountManager!.assignedCount)} more customers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Support Tickets',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTicketStat(
                  'Open',
                  _ticketStats['open'] ?? 0,
                  Colors.orange,
                ),
                _buildTicketStat(
                  'In Progress',
                  _ticketStats['inProgress'] ?? 0,
                  Colors.blue,
                ),
                _buildTicketStat(
                  'Urgent',
                  _ticketStats['urgent'] ?? 0,
                  Colors.red,
                ),
                _buildTicketStat(
                  'Resolved',
                  _ticketStats['resolved'] ?? 0,
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'View All Customers',
                Icons.business,
                Colors.blue,
                () {
                  if (_accountManager != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignedCompaniesScreen(
                          accountManagerId: _accountManager!.id,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'View Tickets',
                Icons.support_agent,
                Colors.orange,
                () {
                  if (_accountManager != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketsListScreen(
                          accountManagerId: _accountManager!.id,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCompaniesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Assigned Companies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssignedCompaniesScreen(
                      accountManagerId: _accountManager!.id,
                    ),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _amService.getAssignedCompanies(_accountManager!.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final companies = snapshot.data ?? [];

            if (companies.isEmpty) {
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No assigned companies yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Show first 5 companies
            final displayCompanies = companies.take(5).toList();

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayCompanies.length,
              itemBuilder: (context, index) {
                final company = displayCompanies[index];
                return _buildCompanyCard(company);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompanyCard(Map<String, dynamic> company) {
    final healthScore =
        company['healthMetrics']?['overallHealthScore']?.toDouble() ?? 0.0;
    final status = company['status'] ?? 'unknown';
    final businessName = company['businessName'] ?? 'Unknown Company';

    Color healthColor;
    if (healthScore >= 80) {
      healthColor = Colors.green;
    } else if (healthScore >= 60) {
      healthColor = Colors.orange;
    } else {
      healthColor = Colors.red;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: healthColor,
          child: Text(
            healthScore.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          businessName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Status: ${status.toUpperCase()}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to company detail screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('View details for $businessName'),
            ),
          );
        },
      ),
    );
  }
}
