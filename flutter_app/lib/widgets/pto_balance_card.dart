import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pto_balance_model.dart';
import '../services/pto_service.dart';

class PtoBalanceCard extends StatefulWidget {
  final String employeeId;
  final String companyId;
  final bool compact;

  const PtoBalanceCard({
    super.key,
    required this.employeeId,
    required this.companyId,
    this.compact = false,
  });

  @override
  State<PtoBalanceCard> createState() => _PtoBalanceCardState();
}

class _PtoBalanceCardState extends State<PtoBalanceCard> {
  final PtoService _ptoService = PtoService();
  bool _isLoading = true;
  Map<String, dynamic>? _summary;
  PtoBalanceModel? _balance;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _ptoService.getEmployeePtoSummary(
        employeeId: widget.employeeId,
        companyId: widget.companyId,
        year: DateTime.now().year,
      );

      // Also load the full balance for transaction history
      final balance = await _ptoService.getOrCreateBalance(
        employeeId: widget.employeeId,
        companyId: widget.companyId,
        year: DateTime.now().year,
      );

      setState(() {
        _summary = summary;
        _balance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 12 : 16),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'PTO balance not available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (_summary == null) {
      return const SizedBox.shrink();
    }

    final availableHours = _summary!['available'] as double;
    final availableDays = _summary!['availableDays'] as double;
    final usedHours = _summary!['used'] as double;
    final usedDays = _summary!['usedDays'] as double;
    final totalHours = _summary!['totalEarned'] as double;
    final totalDays = _summary!['totalDays'] as double;
    final pendingHours = _summary!['pending'] as double;
    final usagePercentage = _summary!['usagePercentage'] as double;

    if (widget.compact) {
      return _buildCompactCard(
        availableHours: availableHours,
        availableDays: availableDays,
        usagePercentage: usagePercentage,
      );
    }

    return _buildFullCard(
      availableHours: availableHours,
      availableDays: availableDays,
      usedHours: usedHours,
      usedDays: usedDays,
      totalHours: totalHours,
      totalDays: totalDays,
      pendingHours: pendingHours,
      usagePercentage: usagePercentage,
    );
  }

  Widget _buildCompactCard({
    required double availableHours,
    required double availableDays,
    required double usagePercentage,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.beach_access,
                color: Colors.teal.shade700,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PTO Balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${availableDays.toStringAsFixed(1)} days',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${availableHours.toStringAsFixed(1)} hours available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            _buildProgressRing(usagePercentage),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard({
    required double availableHours,
    required double availableDays,
    required double usedHours,
    required double usedDays,
    required double totalHours,
    required double totalDays,
    required double pendingHours,
    required double usagePercentage,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.beach_access, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  'PTO Balance ${DateTime.now().year}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadBalance,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const Divider(height: 24),

            // Main balance display
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${availableDays.toStringAsFixed(1)} days',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      Text(
                        '${availableHours.toStringAsFixed(1)} hours',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildProgressRing(usagePercentage, size: 80),
              ],
            ),

            const SizedBox(height: 20),

            // Stats row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _buildStatItem(
                    label: 'Total Earned',
                    value: '${totalDays.toStringAsFixed(1)}d',
                    color: Colors.blue,
                  ),
                  _buildStatDivider(),
                  _buildStatItem(
                    label: 'Used',
                    value: '${usedDays.toStringAsFixed(1)}d',
                    color: Colors.orange,
                  ),
                  if (pendingHours > 0) ...[
                    _buildStatDivider(),
                    _buildStatItem(
                      label: 'Pending',
                      value: '${(pendingHours / 8).toStringAsFixed(1)}d',
                      color: Colors.purple,
                    ),
                  ],
                ],
              ),
            ),

            // View History button
            if (_balance != null && _balance!.transactions.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _showTransactionHistory,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('View Transaction History'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTransactionHistory() {
    if (_balance == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'PTO Transaction History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _balance!.transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No transactions yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _balance!.transactions.length,
                      itemBuilder: (context, index) {
                        // Show newest first
                        final tx = _balance!.transactions[_balance!.transactions.length - 1 - index];
                        return _buildTransactionTile(tx);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(PtoTransaction tx) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: _getTransactionColor(tx.type),
        child: Icon(
          _getTransactionIcon(tx.type),
          size: 18,
          color: Colors.white,
        ),
      ),
      title: Text(
        tx.description ?? _getTransactionTypeLabel(tx.type),
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        DateFormat('MMM d, yyyy').format(tx.date),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Text(
        '${tx.hours >= 0 ? '+' : ''}${tx.hours.toStringAsFixed(1)}h',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: tx.hours >= 0 ? Colors.green.shade700 : Colors.red.shade700,
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

  String _getTransactionTypeLabel(PtoTransactionType type) {
    switch (type) {
      case PtoTransactionType.accrual:
        return 'PTO Accrual';
      case PtoTransactionType.used:
        return 'PTO Used';
      case PtoTransactionType.pending:
        return 'Pending Request';
      case PtoTransactionType.cancelled:
        return 'Request Cancelled';
      case PtoTransactionType.adjustment:
        return 'Manual Adjustment';
      case PtoTransactionType.carryover:
        return 'Carryover from Previous Year';
      case PtoTransactionType.expired:
        return 'PTO Expired';
    }
  }

  Widget _buildProgressRing(double usagePercentage, {double size = 50}) {
    final usagePercent = usagePercentage.clamp(0, 100) / 100;
    final remainingPercent = 1 - usagePercent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: size / 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade200),
          ),
          CircularProgressIndicator(
            value: remainingPercent,
            strokeWidth: size / 10,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(remainingPercent),
            ),
          ),
          Center(
            child: Text(
              '${(remainingPercent * 100).toInt()}%',
              style: TextStyle(
                fontSize: size / 4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double remaining) {
    if (remaining > 0.5) return Colors.teal;
    if (remaining > 0.25) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey.shade300,
    );
  }
}
