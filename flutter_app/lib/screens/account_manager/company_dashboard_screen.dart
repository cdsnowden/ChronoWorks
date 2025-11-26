import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/support_ticket_service.dart';
import '../../services/customer_note_service.dart';
import '../../services/subscription_token_service.dart';
import '../../models/support_ticket.dart';
import '../../models/customer_note.dart';
import '../notes/customer_notes_screen.dart';
import '../support/tickets_list_screen.dart';
import '../support/create_ticket_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CompanyDashboardScreen({
    Key? key,
    required this.companyId,
    required this.companyName,
  }) : super(key: key);

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupportTicketService _ticketService = SupportTicketService();
  final CustomerNoteService _noteService = CustomerNoteService();
  final SubscriptionTokenService _tokenService = SubscriptionTokenService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.companyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Info Header
              _buildCompanyHeader(),
              const SizedBox(height: 24),

              // Subscription Details Section
              _buildSubscriptionDetailsSection(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Health Metrics
              _buildHealthMetrics(),
              const SizedBox(height: 24),

              // Open Tickets Section
              _buildOpenTicketsSection(),
              const SizedBox(height: 24),

              // Recent Notes Section
              _buildRecentNotesSection(),
              const SizedBox(height: 24),

              // Active Users Section
              _buildActiveUsersSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('companies').doc(widget.companyId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Error loading company info'),
            ),
          );
        }

        Map<String, dynamic> company =
            snapshot.data!.data() as Map<String, dynamic>;
        String status = company['status'] ?? 'unknown';
        String subscriptionPlan = company['subscriptionPlan'] ?? 'unknown';
        DateTime? trialEndDate = company['trialEndDate'] != null
            ? (company['trialEndDate'] as Timestamp).toDate()
            : null;

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

        return Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.business, size: 40, color: Colors.blue[700]),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.companyName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  subscriptionPlan.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (status == 'trial' && trialEndDate != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 20, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Trial ends: ${_formatDate(trialEndDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_daysUntil(trialEndDate)} days left)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionDetailsSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('companies').doc(widget.companyId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Unable to load subscription details'),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final subscription = data['subscription'] as Map<String, dynamic>?;
        final customPricing = data['customPricing'] as Map<String, dynamic>?;
        final hasCustomPricing = customPricing?['enabled'] == true;

        final currentPlan = subscription?['currentPlan'] ?? 'free';
        final billingCycle = subscription?['billingCycle'] ?? 'monthly';
        final status = subscription?['status'] ?? 'active';

        return Card(
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
                      'Subscription Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _generateSubscriptionToken(),
                      icon: const Icon(Icons.email, size: 18),
                      label: const Text('Send Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Current Plan
                _buildInfoRow(
                  'Current Plan',
                  _formatPlanName(currentPlan),
                  icon: Icons.workspace_premium,
                  iconColor: _getPlanColor(currentPlan),
                ),
                const SizedBox(height: 12),

                // Billing Cycle
                _buildInfoRow(
                  'Billing Cycle',
                  _formatBillingCycle(billingCycle),
                  icon: Icons.calendar_today,
                ),
                const SizedBox(height: 12),

                // Status
                _buildInfoRow(
                  'Status',
                  _formatStatus(status),
                  icon: Icons.info_outline,
                  iconColor: status == 'active' ? Colors.green : Colors.orange,
                ),

                // Custom Pricing Indicator
                if (hasCustomPricing) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Custom Pricing Active',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monthly: \$${customPricing?['monthlyPrice']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Yearly: \$${customPricing?['yearlyPrice']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (customPricing?['notes'] != null && customPricing!['notes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Notes: ${customPricing['notes']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Trial Information
                if (subscription?['trialEndDate'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Trial ends: ${_formatDate(subscription!['trialEndDate'])}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: iconColor ?? Colors.grey.shade600),
          const SizedBox(width: 8),
        ],
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  String _formatPlanName(String plan) {
    switch (plan.toLowerCase()) {
      case 'free':
        return 'Free Plan';
      case 'basic':
        return 'Basic Plan';
      case 'professional':
        return 'Professional Plan';
      case 'enterprise':
        return 'Enterprise Plan';
      default:
        return plan;
    }
  }

  Color _getPlanColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'free':
        return Colors.grey;
      case 'basic':
        return Colors.blue;
      case 'professional':
        return Colors.purple;
      case 'enterprise':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatBillingCycle(String cycle) {
    return cycle == 'monthly' ? 'Monthly' : 'Yearly';
  }

  String _formatStatus(String status) {
    return status.substring(0, 1).toUpperCase() + status.substring(1);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }

      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.note_add,
                    label: 'Add Note',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerNotesScreen(
                            companyId: widget.companyId,
                            companyName: widget.companyName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.confirmation_number,
                    label: 'Create Ticket',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateTicketScreen(
                            companyId: widget.companyId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.support_agent,
                    label: 'View Tickets',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TicketsListScreen(
                            companyId: widget.companyId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.analytics,
                    label: 'Analytics',
                    color: Colors.purple,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Analytics coming soon...')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetrics() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('companies').doc(widget.companyId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        Map<String, dynamic> company =
            snapshot.data!.data() as Map<String, dynamic>;
        Map<String, dynamic>? healthMetrics =
            company['healthMetrics'] as Map<String, dynamic>?;

        if (healthMetrics == null) {
          return const SizedBox.shrink();
        }

        double healthScore =
            healthMetrics['overallHealthScore']?.toDouble() ?? 0.0;
        int daysSinceLastLogin = healthMetrics['daysSinceLastLogin'] ?? 999;
        double avgWeeklyHours = healthMetrics['avgWeeklyHours']?.toDouble() ?? 0.0;
        int userCount = company['userCount'] ?? 0;

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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Health Score Badge
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: healthColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            healthScore.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Health Score',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _buildMetricRow(
                            Icons.timer,
                            'Last Login',
                            daysSinceLastLogin < 999
                                ? '$daysSinceLastLogin days ago'
                                : 'Never',
                            daysSinceLastLogin > 7 ? Colors.red : Colors.green,
                          ),
                          const SizedBox(height: 12),
                          _buildMetricRow(
                            Icons.access_time,
                            'Weekly Hours',
                            '${avgWeeklyHours.toStringAsFixed(1)} hrs',
                            Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          _buildMetricRow(
                            Icons.people,
                            'Active Users',
                            '$userCount',
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildOpenTicketsSection() {
    return Card(
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
                  'Open Support Tickets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketsListScreen(
                          companyId: widget.companyId,
                        ),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<SupportTicket>>(
              stream: _ticketService.getTicketsForCompany(widget.companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                List<SupportTicket> tickets = snapshot.data ?? [];
                List<SupportTicket> openTickets = tickets
                    .where((t) =>
                        t.status == TicketStatus.open ||
                        t.status == TicketStatus.inProgress)
                    .take(3)
                    .toList();

                if (openTickets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: Colors.green[300]),
                          const SizedBox(height: 8),
                          Text(
                            'No open tickets',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: openTickets
                      .map((ticket) => _buildTicketItem(ticket))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketItem(SupportTicket ticket) {
    Color priorityColor;
    switch (ticket.priority) {
      case TicketPriority.urgent:
        priorityColor = Colors.red;
        break;
      case TicketPriority.high:
        priorityColor = Colors.orange;
        break;
      case TicketPriority.medium:
        priorityColor = Colors.amber;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.ticketNumber,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ticket.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ticket.category,
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
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildRecentNotesSection() {
    return Card(
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
                  'Recent Customer Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerNotesScreen(
                          companyId: widget.companyId,
                          companyName: widget.companyName,
                        ),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<CustomerNote>>(
              stream: _noteService.getNotesForCompany(widget.companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                List<CustomerNote> notes = snapshot.data ?? [];
                List<CustomerNote> recentNotes = notes.take(3).toList();

                if (recentNotes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.note_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'No notes yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: recentNotes
                      .map((note) => _buildNoteItem(note))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(CustomerNote note) {
    Color sentimentColor;
    IconData sentimentIcon;
    switch (note.sentiment) {
      case NoteSentiment.positive:
        sentimentColor = Colors.green;
        sentimentIcon = Icons.sentiment_satisfied;
        break;
      case NoteSentiment.negative:
        sentimentColor = Colors.red;
        sentimentIcon = Icons.sentiment_dissatisfied;
        break;
      default:
        sentimentColor = Colors.grey;
        sentimentIcon = Icons.sentiment_neutral;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sentimentIcon, color: sentimentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.noteType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Text(
                _formatDate(note.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.note,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (note.followUpRequired && !note.followUpCompleted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Follow-up required',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveUsersSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('companyId', isEqualTo: widget.companyId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                List<Map<String, dynamic>> users = snapshot.data!.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList();

                if (users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'No active users',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children:
                      users.map((user) => _buildUserItem(user)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    String displayName = user['displayName'] ?? 'Unknown User';
    String email = user['email'] ?? '';
    String role = user['role'] ?? 'user';

    Color roleColor;
    switch (role) {
      case 'admin':
        roleColor = Colors.purple;
        break;
      case 'manager':
        roleColor = Colors.blue;
        break;
      default:
        roleColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: roleColor.withOpacity(0.2),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: roleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _daysUntil(DateTime date) {
    return date.difference(DateTime.now()).inDays;
  }

  Future<void> _generateSubscriptionToken() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Call Cloud Function to generate token and send email
      final response = await http.post(
        Uri.parse('https://us-central1-chronoworks-dcfd6.cloudfunctions.net/sendSubscriptionManagementEmail'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'companyId': widget.companyId,
          'accountManagerId': currentUser.uid,
        }),
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Show success message
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text('Email Sent Successfully!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A subscription management email has been sent to the company owner.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The email contains a secure link that:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Expires in 72 hours', style: TextStyle(fontSize: 13)),
                  const Text('• Can only be used once', style: TextStyle(fontSize: 13)),
                  const Text('• Allows the customer to manage their subscription', style: TextStyle(fontSize: 13)),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Show error message
        final errorMessage = jsonDecode(response.body)['error'] ?? 'Unknown error occurred';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send email: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
