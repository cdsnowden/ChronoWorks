import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/pto_balance_model.dart';
import '../../services/employee_service.dart';
import '../../services/pto_service.dart';
import '../../services/auth_provider.dart' as app_auth;

class PtoBalanceManagementScreen extends StatefulWidget {
  const PtoBalanceManagementScreen({super.key});

  @override
  State<PtoBalanceManagementScreen> createState() => _PtoBalanceManagementScreenState();
}

class _PtoBalanceManagementScreenState extends State<PtoBalanceManagementScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final PtoService _ptoService = PtoService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  Map<String, PtoBalanceModel> _balances = {};
  Map<String, Map<String, dynamic>> _eligibility = {};

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.currentUser?.companyId ?? '';

    if (companyId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final balances = await _ptoService.getAllBalancesForCompany(companyId, _selectedYear);
      final balanceMap = <String, PtoBalanceModel>{};
      for (final balance in balances) {
        balanceMap[balance.employeeId] = balance;
      }

      setState(() {
        _balances = balanceMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balances: $e')),
        );
      }
    }
  }

  Future<void> _loadEligibilityForEmployee(String employeeId, String companyId) async {
    if (_eligibility.containsKey(employeeId)) return;

    try {
      final eligibility = await _ptoService.checkPtoEligibility(
        employeeId: employeeId,
        companyId: companyId,
      );
      setState(() {
        _eligibility[employeeId] = eligibility;
      });
    } catch (e) {
      // Ignore errors for eligibility loading
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'process_accrual':
        _showProcessAccrualDialog();
        break;
      case 'year_end_rollover':
        _showYearEndRolloverDialog();
        break;
    }
  }

  void _showProcessAccrualDialog() {
    final payPeriodEndController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Pay Period Accrual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will process PTO accrual for all eligible employees based on your company\'s per-pay-period accrual policy.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Only applies to policies with "Per Pay Period" accrual method.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(_selectedYear, 1, 1),
                  lastDate: DateTime(_selectedYear, 12, 31),
                  helpText: 'Select Pay Period End Date',
                );
                if (picked != null) {
                  selectedDate = picked;
                  payPeriodEndController.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Pay Period End Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(payPeriodEndController.text),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processAccrual(selectedDate);
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  Future<void> _processAccrual(DateTime payPeriodEnd) async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.currentUser?.companyId ?? '';

    if (companyId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _ptoService.processPayPeriodAccrual(
        companyId: companyId,
        payPeriodEnd: payPeriodEnd,
      );

      await _loadBalances();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accrual processed for pay period ending ${DateFormat('MMM d, yyyy').format(payPeriodEnd)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing accrual: $e')),
        );
      }
    }
  }

  void _showYearEndRolloverDialog() {
    final nextYear = _selectedYear + 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Year-End Rollover'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create $nextYear balances for all employees and carry over unused PTO from $_selectedYear (subject to carryover limits).',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Carryover limits are defined in your PTO policy. Hours exceeding the limit will expire.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processYearEndRollover(nextYear);
            },
            child: Text('Create $nextYear Balances'),
          ),
        ],
      ),
    );
  }

  Future<void> _processYearEndRollover(int newYear) async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.currentUser?.companyId ?? '';

    if (companyId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Get all active employees
      final employees = await _employeeService.getAllEmployees(companyId);
      int processed = 0;

      for (final employee in employees) {
        if (employee.isActive) {
          await _ptoService.getOrCreateBalance(
            employeeId: employee.id,
            companyId: companyId,
            year: newYear,
          );
          processed++;
        }
      }

      setState(() {
        _selectedYear = newYear;
        _balances = {};
      });

      await _loadBalances();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created $newYear balances for $processed employees with carryover applied'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing rollover: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PTO Balance Management'),
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
                  _loadBalances();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBalances,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'process_accrual',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 8),
                    Text('Process Accrual'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'year_end_rollover',
                child: Row(
                  children: [
                    Icon(Icons.forward),
                    SizedBox(width: 8),
                    Text('Year-End Rollover'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Employee List
          Expanded(
            child: Consumer<app_auth.AuthProvider>(
              builder: (context, authProvider, child) {
                final currentUser = authProvider.currentUser;
                if (currentUser == null) {
                  return const Center(child: Text('Not logged in'));
                }

                return StreamBuilder<List<UserModel>>(
                  stream: _employeeService.getActiveEmployeesStream(currentUser.companyId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _balances.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    var employees = snapshot.data ?? [];

                    // Apply search filter
                    if (_searchQuery.isNotEmpty) {
                      employees = employees.where((emp) {
                        final fullName = emp.fullName.toLowerCase();
                        final email = emp.email.toLowerCase();
                        return fullName.contains(_searchQuery) || email.contains(_searchQuery);
                      }).toList();
                    }

                    if (employees.isEmpty) {
                      return const Center(child: Text('No employees found'));
                    }

                    // Load eligibility for all employees
                    for (final employee in employees) {
                      _loadEligibilityForEmployee(employee.id, currentUser.companyId);
                    }

                    return RefreshIndicator(
                      onRefresh: _loadBalances,
                      child: ListView.builder(
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final employee = employees[index];
                          final balance = _balances[employee.id];
                          final eligibility = _eligibility[employee.id];
                          return _buildEmployeeBalanceCard(
                            employee,
                            balance,
                            eligibility,
                            currentUser.companyId,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalEmployees = _balances.length;
    final totalAvailable = _balances.values.fold(0.0, (sum, b) => sum + b.availableHours);
    final totalUsed = _balances.values.fold(0.0, (sum, b) => sum + b.usedHours);
    final totalPending = _balances.values.fold(0.0, (sum, b) => sum + b.pendingHours);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _buildSummaryCard(
            'Employees',
            totalEmployees.toString(),
            Icons.people,
            Colors.blue,
          ),
          _buildSummaryCard(
            'Available',
            '${(totalAvailable / 8).toStringAsFixed(0)}d',
            Icons.check_circle,
            Colors.green,
          ),
          _buildSummaryCard(
            'Used',
            '${(totalUsed / 8).toStringAsFixed(0)}d',
            Icons.event_busy,
            Colors.orange,
          ),
          _buildSummaryCard(
            'Pending',
            '${(totalPending / 8).toStringAsFixed(0)}d',
            Icons.pending,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeBalanceCard(
    UserModel employee,
    PtoBalanceModel? balance,
    Map<String, dynamic>? eligibility,
    String companyId,
  ) {
    final isEligible = eligibility?['isEligible'] as bool? ?? true;
    final availableHours = balance?.availableHours ?? 0;
    final usedHours = balance?.usedHours ?? 0;
    final pendingHours = balance?.pendingHours ?? 0;
    final totalEarned = balance?.totalEarnedHours ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isEligible ? Colors.teal : Colors.grey,
          child: Text(
            employee.firstName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          employee.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            if (!isEligible)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Not Eligible',
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                ),
              )
            else
              Text(
                '${(availableHours / 8).toStringAsFixed(1)} days available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: isEligible
            ? _buildMiniProgress(usedHours, totalEarned)
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEligible) ...[
                  _buildEligibilityInfo(eligibility),
                  const Divider(height: 24),
                ],

                // Balance Details
                if (balance != null) ...[
                  _buildBalanceRow('Total Earned', totalEarned, Colors.blue),
                  _buildBalanceRow('Used', usedHours, Colors.orange),
                  _buildBalanceRow('Pending', pendingHours, Colors.purple),
                  _buildBalanceRow('Available', availableHours, Colors.green),

                  if (balance.carryoverHours > 0)
                    _buildBalanceRow('Carryover', balance.carryoverHours, Colors.teal),

                  if (balance.adjustmentHours != 0)
                    _buildBalanceRow(
                      'Adjustments',
                      balance.adjustmentHours,
                      balance.adjustmentHours > 0 ? Colors.green : Colors.red,
                    ),

                  const Divider(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showTransactionHistory(employee, balance),
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('History'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAdjustmentDialog(employee, companyId),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Adjust'),
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _initializeBalance(employee.id, companyId),
                      icon: const Icon(Icons.add),
                      label: const Text('Initialize Balance'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(double used, double total) {
    if (total == 0) return const SizedBox.shrink();
    final percentage = (used / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 4,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade200),
          ),
          CircularProgressIndicator(
            value: 1 - percentage,
            strokeWidth: 4,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 0.8 ? Colors.red : percentage > 0.5 ? Colors.orange : Colors.green,
            ),
          ),
          Center(
            child: Text(
              '${((1 - percentage) * 100).toInt()}%',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityInfo(Map<String, dynamic>? eligibility) {
    if (eligibility == null) return const SizedBox.shrink();

    final waitingMonths = eligibility['waitingPeriodMonths'] as int? ?? 12;
    final eligibilityDate = eligibility['eligibilityDate'] as DateTime?;
    final daysUntil = eligibility['daysUntilEligible'] as int? ?? 0;

    return Container(
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
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Not Yet Eligible for PTO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Waiting Period: $waitingMonths months'),
          if (eligibilityDate != null)
            Text('Eligible On: ${DateFormat('MMM d, yyyy').format(eligibilityDate)}'),
          if (daysUntil > 0)
            Text('Days Until Eligible: $daysUntil'),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, double hours, Color color) {
    final days = hours / 8;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Text(
            '(${days.toStringAsFixed(1)}d)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeBalance(String employeeId, String companyId) async {
    try {
      await _ptoService.getOrCreateBalance(
        employeeId: employeeId,
        companyId: companyId,
        year: _selectedYear,
      );
      await _loadBalances();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance initialized')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showTransactionHistory(UserModel employee, PtoBalanceModel balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text(
                    '${employee.fullName} - Transaction History',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: balance.transactions.isEmpty
                  ? const Center(child: Text('No transactions'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: balance.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = balance.transactions[balance.transactions.length - 1 - index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: _getTransactionColor(tx.type),
                            child: Icon(
                              _getTransactionIcon(tx.type),
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(tx.description ?? 'Transaction'),
                          subtitle: Text(DateFormat('MMM d, yyyy').format(tx.date)),
                          trailing: Text(
                            '${tx.hours >= 0 ? '+' : ''}${tx.hours.toStringAsFixed(1)}h',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tx.hours >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTransactionColor(PtoTransactionType type) {
    switch (type) {
      case PtoTransactionType.accrual:
        return Colors.teal;
      case PtoTransactionType.used:
        return Colors.orange;
      case PtoTransactionType.pending:
        return Colors.purple;
      case PtoTransactionType.cancelled:
        return Colors.grey;
      case PtoTransactionType.adjustment:
        return Colors.indigo;
      case PtoTransactionType.carryover:
        return Colors.cyan;
      case PtoTransactionType.expired:
        return Colors.red;
    }
  }

  IconData _getTransactionIcon(PtoTransactionType type) {
    switch (type) {
      case PtoTransactionType.accrual:
        return Icons.trending_up;
      case PtoTransactionType.used:
        return Icons.event_busy;
      case PtoTransactionType.pending:
        return Icons.pending;
      case PtoTransactionType.cancelled:
        return Icons.cancel;
      case PtoTransactionType.adjustment:
        return Icons.edit;
      case PtoTransactionType.carryover:
        return Icons.forward;
      case PtoTransactionType.expired:
        return Icons.timer_off;
    }
  }

  void _showAdjustmentDialog(UserModel employee, String companyId) {
    final hoursController = TextEditingController();
    final reasonController = TextEditingController();
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust PTO - ${employee.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add or Remove toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Add Hours'), icon: Icon(Icons.add)),
                  ButtonSegment(value: false, label: Text('Remove Hours'), icon: Icon(Icons.remove)),
                ],
                selected: {isAdding},
                onSelectionChanged: (value) {
                  setDialogState(() => isAdding = value.first);
                },
              ),
              const SizedBox(height: 16),

              // Hours input
              TextField(
                controller: hoursController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Hours',
                  border: const OutlineInputBorder(),
                  suffixText: 'hours',
                  helperText: 'Enter number of hours to ${isAdding ? 'add' : 'remove'}',
                ),
              ),
              const SizedBox(height: 16),

              // Reason input
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Correction, Bonus PTO, etc.',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final hours = double.tryParse(hoursController.text);
                final reason = reasonController.text.trim();

                if (hours == null || hours <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid hours')),
                  );
                  return;
                }

                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason')),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  final authProvider = context.read<app_auth.AuthProvider>();
                  final adjustedBy = authProvider.currentUser?.fullName ?? 'Admin';

                  await _ptoService.adjustBalance(
                    employeeId: employee.id,
                    companyId: companyId,
                    year: _selectedYear,
                    hours: isAdding ? hours : -hours,
                    reason: reason,
                    adjustedBy: adjustedBy,
                  );

                  await _loadBalances();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${isAdding ? 'Added' : 'Removed'} ${hours.toStringAsFixed(1)} hours for ${employee.fullName}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
