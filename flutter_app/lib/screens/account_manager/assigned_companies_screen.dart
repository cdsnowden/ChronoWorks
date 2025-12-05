import 'package:flutter/material.dart';
import '../../services/account_manager_service.dart';
import '../../services/support_ticket_service.dart';
import '../notes/customer_notes_screen.dart';
import '../support/tickets_list_screen.dart';
import 'company_dashboard_screen.dart';

class AssignedCompaniesScreen extends StatefulWidget {
  final String accountManagerId;

  const AssignedCompaniesScreen({
    Key? key,
    required this.accountManagerId,
  }) : super(key: key);

  @override
  State<AssignedCompaniesScreen> createState() =>
      _AssignedCompaniesScreenState();
}

class _AssignedCompaniesScreenState extends State<AssignedCompaniesScreen> {
  final AccountManagerService _amService = AccountManagerService();
  final SupportTicketService _ticketService = SupportTicketService();
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Companies'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'trial', child: Text('Trial')),
              const PopupMenuItem(value: 'active', child: Text('Active')),
              const PopupMenuItem(value: 'inactive', child: Text('Inactive')),
              const PopupMenuItem(
                  value: 'suspended', child: Text('Suspended')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search companies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Companies List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _amService.getAssignedCompanies(widget.accountManagerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                List<Map<String, dynamic>> companies = snapshot.data ?? [];

                // Apply filters
                if (_filterStatus != 'all') {
                  companies = companies
                      .where((c) => c['status'] == _filterStatus)
                      .toList();
                }

                if (_searchQuery.isNotEmpty) {
                  companies = companies.where((c) {
                    final name =
                        (c['businessName'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();
                }

                if (companies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterStatus != 'all'
                              ? 'No companies match your filters'
                              : 'No assigned companies yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: companies.length,
                  itemBuilder: (context, index) {
                    return _buildCompanyCard(companies[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(Map<String, dynamic> company) {
    final companyId = company['id'] ?? '';
    final businessName = company['businessName'] ?? 'Unknown Company';
    final status = company['status'] ?? 'unknown';
    final subscriptionPlan = company['subscriptionPlan'] ?? 'unknown';

    // Health metrics
    final healthMetrics = company['healthMetrics'] as Map<String, dynamic>?;
    final healthScore = healthMetrics?['overallHealthScore']?.toDouble() ?? 0.0;
    final daysSinceLastLogin = healthMetrics?['daysSinceLastLogin'] ?? 999;
    final avgWeeklyHours = healthMetrics?['avgWeeklyHours']?.toDouble() ?? 0.0;

    // Colors
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'trial':
        statusColor = Colors.orange;
        break;
      case 'inactive':
        statusColor = Colors.grey;
        break;
      case 'suspended':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showCompanyOptions(context, company),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Health Score Badge
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: healthColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          healthScore.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Health',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Company Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              subscriptionPlan.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Ticket Indicator
                  FutureBuilder<Map<String, dynamic>>(
                    future: _ticketService.getCompanyTicketInfo(companyId),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final ticketInfo = snapshot.data!;
                        final count = ticketInfo['count'] as int;
                        final priority = ticketInfo['highestPriority'] as String;

                        if (count > 0) {
                          return _buildTicketIndicator(count, priority);
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // More Icon
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    Icons.timer,
                    'Last Login',
                    daysSinceLastLogin < 999
                        ? '$daysSinceLastLogin days ago'
                        : 'Never',
                    daysSinceLastLogin > 7 ? Colors.red : Colors.green,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildMetricItem(
                    Icons.access_time,
                    'Weekly Hours',
                    '${avgWeeklyHours.toStringAsFixed(1)} hrs',
                    Colors.blue,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildMetricItem(
                    Icons.people,
                    'Users',
                    '${company['userCount'] ?? 0}',
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTicketIndicator(int count, String priority) {
    // Determine color based on priority
    Color indicatorColor;
    switch (priority) {
      case 'urgent':
        indicatorColor = Colors.red;
        break;
      case 'high':
        indicatorColor = Colors.orange;
        break;
      case 'medium':
        indicatorColor = Colors.amber;
        break;
      default:
        indicatorColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: indicatorColor,
            size: 20,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: indicatorColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompanyOptions(
      BuildContext context, Map<String, dynamic> company) {
    final companyId = company['id'] ?? '';
    final businessName = company['businessName'] ?? 'Unknown';

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                businessName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('View Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompanyDashboardScreen(
                      companyId: companyId,
                      companyName: businessName,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.note),
              title: const Text('View Notes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerNotesScreen(
                      companyId: companyId,
                      companyName: businessName,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('View Support Tickets'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TicketsListScreen(
                      companyId: companyId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('View Analytics'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/analytics');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Company Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/compliance-settings');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: const Text('Request Deletion', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _requestCompanyDeletion(companyId, businessName);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _requestCompanyDeletion(String companyId, String businessName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Company Deletion'),
        content: Text(
          'Are you sure you want to request deletion of "$businessName"?\n\n'
          'This will send a request to the Super Admin for review. '
          'The Super Admin will decide whether to delete or archive this company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('REQUEST DELETION'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show reason dialog
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for this deletion request:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g., Company is no longer active, duplicate account, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );

    if (reason == null || reason.trim().isEmpty) return;

    // Submit the deletion request
    try {
      await _amService.requestCompanyDeletion(
        companyId: companyId,
        companyName: businessName,
        accountManagerId: widget.accountManagerId,
        reason: reason.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deletion request submitted for $businessName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting deletion request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
