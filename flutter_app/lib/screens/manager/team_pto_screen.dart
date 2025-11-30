import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/pto_balance_model.dart';
import '../../services/employee_service.dart';
import '../../services/pto_service.dart';
import '../../services/auth_provider.dart' as app_auth;

class TeamPtoScreen extends StatefulWidget {
  const TeamPtoScreen({super.key});

  @override
  State<TeamPtoScreen> createState() => _TeamPtoScreenState();
}

class _TeamPtoScreenState extends State<TeamPtoScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final PtoService _ptoService = PtoService();

  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  List<UserModel> _teamMembers = [];
  Map<String, PtoBalanceModel> _balances = {};
  Map<String, Map<String, dynamic>> _eligibility = {};

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Get team members managed by this manager
      final teamMembers = await _employeeService.getEmployeesByManagerId(
        currentUser.id,
        currentUser.companyId,
      );

      // Load balances for each team member
      final balances = <String, PtoBalanceModel>{};
      final eligibility = <String, Map<String, dynamic>>{};

      for (final member in teamMembers) {
        try {
          final balance = await _ptoService.getOrCreateBalance(
            employeeId: member.id,
            companyId: currentUser.companyId,
            year: _selectedYear,
          );
          balances[member.id] = balance;

          final elig = await _ptoService.checkPtoEligibility(
            employeeId: member.id,
            companyId: currentUser.companyId,
          );
          eligibility[member.id] = elig;
        } catch (e) {
          // Skip employees with balance errors
        }
      }

      setState(() {
        _teamMembers = teamMembers;
        _balances = balances;
        _eligibility = eligibility;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team PTO Balances'),
        actions: [
          // Year selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<int>(
              value: _selectedYear,
              underline: const SizedBox(),
              items: [
                for (int year = DateTime.now().year - 1; year <= DateTime.now().year + 1; year++)
                  DropdownMenuItem(
                    value: year,
                    child: Text('$year', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedYear = value;
                    _balances = {};
                  });
                  _loadTeamData();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeamData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teamMembers.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Summary
                    _buildSummaryCard(),

                    // Team list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadTeamData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _teamMembers.length,
                          itemBuilder: (context, index) {
                            final member = _teamMembers[index];
                            final balance = _balances[member.id];
                            final eligibility = _eligibility[member.id];
                            return _buildMemberCard(member, balance, eligibility);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Team Members',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any employees assigned to you.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalMembers = _teamMembers.length;
    final eligibleMembers = _eligibility.values.where((e) => e['isEligible'] == true).length;
    final totalAvailable = _balances.values.fold(0.0, (sum, b) => sum + b.availableHours);
    final totalUsed = _balances.values.fold(0.0, (sum, b) => sum + b.usedHours);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                'Team PTO Summary - $_selectedYear',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem('Team Size', '$totalMembers'),
              _buildSummaryItem('PTO Eligible', '$eligibleMembers'),
              _buildSummaryItem('Available', '${(totalAvailable / 8).toStringAsFixed(0)}d'),
              _buildSummaryItem('Used', '${(totalUsed / 8).toStringAsFixed(0)}d'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    UserModel member,
    PtoBalanceModel? balance,
    Map<String, dynamic>? eligibility,
  ) {
    final isEligible = eligibility?['isEligible'] as bool? ?? true;
    final availableHours = balance?.availableHours ?? 0;
    final usedHours = balance?.usedHours ?? 0;
    final pendingHours = balance?.pendingHours ?? 0;
    final totalEarned = balance?.totalEarnedHours ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isEligible ? Colors.teal : Colors.grey,
                  child: Text(
                    member.firstName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isEligible)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Not Eligible',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

            if (balance != null && isEligible) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Balance stats
              Row(
                children: [
                  _buildBalanceStat('Available', availableHours, Colors.green),
                  _buildBalanceStat('Used', usedHours, Colors.orange),
                  if (pendingHours > 0)
                    _buildBalanceStat('Pending', pendingHours, Colors.purple),
                  _buildBalanceStat('Total', totalEarned, Colors.blue),
                ],
              ),

              // Progress bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalEarned > 0 ? (usedHours / totalEarned).clamp(0, 1) : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getUsageColor(totalEarned > 0 ? usedHours / totalEarned : 0),
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(totalEarned > 0 ? (usedHours / totalEarned * 100) : 0).toStringAsFixed(0)}% used',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ] else if (!isEligible) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Eligible on ${eligibility?['eligibilityDate'] != null ? DateFormat('MMM d, yyyy').format(eligibility!['eligibilityDate'] as DateTime) : 'TBD'}',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
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
  }

  Widget _buildBalanceStat(String label, double hours, Color color) {
    final days = hours / 8;
    return Expanded(
      child: Column(
        children: [
          Text(
            '${days.toStringAsFixed(1)}d',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getUsageColor(double percentage) {
    if (percentage < 0.5) return Colors.green;
    if (percentage < 0.8) return Colors.orange;
    return Colors.red;
  }
}
