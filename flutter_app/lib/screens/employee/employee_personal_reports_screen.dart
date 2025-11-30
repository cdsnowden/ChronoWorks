import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_provider.dart';
import '../../services/time_entry_service.dart';
import '../../models/time_entry_model.dart';

class EmployeePersonalReportsScreen extends StatefulWidget {
  const EmployeePersonalReportsScreen({super.key});

  @override
  State<EmployeePersonalReportsScreen> createState() =>
      _EmployeePersonalReportsScreenState();
}

class _EmployeePersonalReportsScreenState
    extends State<EmployeePersonalReportsScreen> {
  final TimeEntryService _timeEntryService = TimeEntryService();

  String _selectedPeriod = 'this_week';
  bool _isLoading = true;
  List<TimeEntryModel> _timeEntries = [];

  // Computed stats
  double _totalHours = 0;
  double _regularHours = 0;
  double _overtimeHours = 0;
  double _estimatedPay = 0;
  double _overtimePay = 0;
  int _daysWorked = 0;
  int _onTimeArrivals = 0;
  int _lateArrivals = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime get _startDate {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'this_week':
        final weekday = now.weekday % 7; // Sunday = 0
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday));
      case 'last_week':
        final weekday = now.weekday % 7;
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday + 7));
      case 'this_month':
        return DateTime(now.year, now.month, 1);
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return lastMonth;
      default:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday % 7));
    }
  }

  DateTime get _endDate {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'this_week':
        return _startDate.add(const Duration(days: 7));
      case 'last_week':
        return _startDate.add(const Duration(days: 7));
      case 'this_month':
        return DateTime(now.year, now.month + 1, 1);
      case 'last_month':
        return DateTime(now.year, now.month, 1);
      default:
        return _startDate.add(const Duration(days: 7));
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final entries = await _timeEntryService.getTimeEntriesInRange(
        userId: user.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      // Calculate stats
      double totalHours = 0;
      Set<String> workDays = {};
      int onTime = 0;
      int late = 0;

      for (final entry in entries) {
        totalHours += entry.totalHours;

        // Track unique work days
        final dayKey = DateFormat('yyyy-MM-dd').format(entry.clockInTime);
        workDays.add(dayKey);

        // Check on-time vs late (assuming 9 AM start)
        if (entry.clockInTime.hour < 9 ||
            (entry.clockInTime.hour == 9 && entry.clockInTime.minute <= 5)) {
          onTime++;
        } else {
          late++;
        }
      }

      // Calculate regular and overtime (40 hours/week threshold)
      final weeksInPeriod = _endDate.difference(_startDate).inDays / 7;
      final regularThreshold = 40.0 * weeksInPeriod;

      double regularHours = totalHours > regularThreshold ? regularThreshold : totalHours;
      double overtimeHours = totalHours > regularThreshold ? totalHours - regularThreshold : 0;

      // Calculate pay
      final hourlyRate = user.hourlyRate;
      final estimatedPay = regularHours * hourlyRate;
      final overtimePay = overtimeHours * hourlyRate * 1.5;

      setState(() {
        _timeEntries = entries;
        _totalHours = totalHours;
        _regularHours = regularHours;
        _overtimeHours = overtimeHours;
        _estimatedPay = estimatedPay;
        _overtimePay = overtimePay;
        _daysWorked = workDays.length;
        _onTimeArrivals = onTime;
        _lateArrivals = late;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),

                    // Hours Summary Card
                    _buildHoursSummaryCard(),
                    const SizedBox(height: 16),

                    // Pay Estimate Card
                    if (user != null && user.hourlyRate > 0)
                      _buildPayEstimateCard(user.hourlyRate),
                    const SizedBox(height: 16),

                    // Attendance Card
                    _buildAttendanceCard(),
                    const SizedBox(height: 24),

                    // Recent Time Entries
                    _buildRecentEntriesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Period',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'this_week', label: Text('This Week')),
                ButtonSegment(value: 'last_week', label: Text('Last Week')),
                ButtonSegment(value: 'this_month', label: Text('This Month')),
                ButtonSegment(value: 'last_month', label: Text('Last Month')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) {
                setState(() => _selectedPeriod = selection.first);
                _loadData();
              },
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate.subtract(const Duration(days: 1)))}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Hours Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Total Hours',
                    _totalHours.toStringAsFixed(1),
                    Colors.blue,
                    Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Days Worked',
                    _daysWorked.toString(),
                    Colors.green,
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Regular Hours',
                    _regularHours.toStringAsFixed(1),
                    Colors.teal,
                    Icons.work,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Overtime',
                    _overtimeHours.toStringAsFixed(1),
                    _overtimeHours > 0 ? Colors.orange : Colors.grey,
                    Icons.more_time,
                  ),
                ),
              ],
            ),
            if (_daysWorked > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Average per day:',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      '${(_totalHours / _daysWorked).toStringAsFixed(1)} hours',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPayEstimateCard(double hourlyRate) {
    final totalPay = _estimatedPay + _overtimePay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Pay Estimate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Based on \$${hourlyRate.toStringAsFixed(2)}/hour',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const Divider(height: 24),
            _buildPayRow('Regular Pay', _estimatedPay, Colors.black87),
            if (_overtimeHours > 0) ...[
              const SizedBox(height: 8),
              _buildPayRow('Overtime Pay (1.5x)', _overtimePay, Colors.orange.shade700),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '\$${totalPay.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is an estimate. Actual pay may vary based on deductions and adjustments.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
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

  Widget _buildPayRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard() {
    final totalEntries = _onTimeArrivals + _lateArrivals;
    final onTimePercentage = totalEntries > 0 ? (_onTimeArrivals / totalEntries) * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildAttendanceStat(
                    'On Time',
                    _onTimeArrivals,
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAttendanceStat(
                    'Late',
                    _lateArrivals,
                    Colors.red,
                    Icons.warning,
                  ),
                ),
              ],
            ),
            if (totalEntries > 0) ...[
              const SizedBox(height: 16),
              Text(
                'Punctuality Rate',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: onTimePercentage / 100,
                  backgroundColor: Colors.red.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    onTimePercentage >= 90
                        ? Colors.green
                        : onTimePercentage >= 75
                            ? Colors.orange
                            : Colors.red,
                  ),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${onTimePercentage.toStringAsFixed(0)}% on-time arrivals',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: onTimePercentage >= 90
                      ? Colors.green.shade700
                      : onTimePercentage >= 75
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStat(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEntriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Time Entries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${_timeEntries.length} entries',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_timeEntries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No time entries for this period',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _timeEntries.length > 10 ? 10 : _timeEntries.length,
            itemBuilder: (context, index) {
              final entry = _timeEntries[index];
              return _buildTimeEntryCard(entry);
            },
          ),
        if (_timeEntries.length > 10) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/employee/time-entries');
              },
              child: const Text('View All Time Entries'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeEntryCard(TimeEntryModel entry) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  entry.clockInTime.day.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(entry.clockInTime),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFormat.format(entry.clockInTime)} - ${entry.clockOutTime != null ? timeFormat.format(entry.clockOutTime!) : 'Active'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.totalHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (entry.isOffPremises)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Off-site',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
