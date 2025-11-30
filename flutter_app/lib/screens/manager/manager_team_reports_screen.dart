import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';

import '../../services/auth_provider.dart';
import '../../services/employee_service.dart';
import '../../services/time_entry_service.dart';
import '../../services/schedule_service.dart';

class ManagerTeamReportsScreen extends StatefulWidget {
  const ManagerTeamReportsScreen({super.key});

  @override
  State<ManagerTeamReportsScreen> createState() => _ManagerTeamReportsScreenState();
}

class _ManagerTeamReportsScreenState extends State<ManagerTeamReportsScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final TimeEntryService _timeEntryService = TimeEntryService();
  final ScheduleService _scheduleService = ScheduleService();

  List<UserModel> _teamMembers = [];
  Map<String, _EmployeeReportData> _reportData = {};
  bool _isLoading = true;
  String _selectedPeriod = 'this_week';
  DateTime _periodStart = DateTime.now();
  DateTime _periodEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setPeriodDates();
    _loadTeamData();
  }

  void _setPeriodDates() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'this_week':
        // Start from Sunday
        final weekStart = now.subtract(Duration(days: now.weekday % 7));
        _periodStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
        _periodEnd = _periodStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'last_week':
        final lastWeekEnd = now.subtract(Duration(days: now.weekday % 7 + 1));
        final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
        _periodStart = DateTime(lastWeekStart.year, lastWeekStart.month, lastWeekStart.day);
        _periodEnd = DateTime(lastWeekEnd.year, lastWeekEnd.month, lastWeekEnd.day, 23, 59, 59);
        break;
      case 'this_month':
        _periodStart = DateTime(now.year, now.month, 1);
        _periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _periodStart = lastMonth;
        _periodEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
    }
  }

  Future<void> _loadTeamData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get team members (employees managed by this manager)
      List<UserModel> team;
      if (currentUser.role == 'admin') {
        // Admins see all employees
        team = await _employeeService.getAllEmployees(currentUser.companyId);
        // Filter out non-employees
        team = team.where((u) => u.role == 'employee' || u.role == 'manager').toList();
      } else {
        // Managers see their direct reports
        team = await _employeeService.getEmployeesByManagerId(currentUser.id, currentUser.companyId);
      }

      setState(() {
        _teamMembers = team;
      });

      // Load report data for each team member
      final reportData = <String, _EmployeeReportData>{};

      for (final employee in team) {
        final data = await _loadEmployeeReportData(employee);
        reportData[employee.id] = data;
      }

      setState(() {
        _reportData = reportData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading team data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<_EmployeeReportData> _loadEmployeeReportData(UserModel employee) async {
    // Get actual worked hours
    final timeEntries = await _timeEntryService.getTimeEntriesInRange(
      userId: employee.id,
      startDate: _periodStart,
      endDate: _periodEnd,
    );

    double actualHours = 0;
    int totalEntries = 0;
    int lateArrivals = 0;
    int earlyDepartures = 0;

    for (final entry in timeEntries) {
      actualHours += entry.totalHours;
      totalEntries++;
    }

    // Get scheduled hours
    final scheduledHours = await _scheduleService.getScheduledHours(
      employeeId: employee.id,
      startDate: _periodStart,
      endDate: _periodEnd,
    );

    // Calculate attendance rate
    double attendanceRate = 0;
    if (scheduledHours > 0) {
      attendanceRate = (actualHours / scheduledHours * 100).clamp(0.0, 150.0).toDouble();
    } else if (actualHours > 0) {
      attendanceRate = 100; // Worked but no schedule = 100%
    }

    // Calculate overtime
    final regularHoursLimit = 40.0; // Standard work week
    final overtimeHours = actualHours > regularHoursLimit ? actualHours - regularHoursLimit : 0.0;

    return _EmployeeReportData(
      employee: employee,
      actualHours: actualHours,
      scheduledHours: scheduledHours,
      attendanceRate: attendanceRate,
      totalEntries: totalEntries,
      lateArrivals: lateArrivals,
      earlyDepartures: earlyDepartures,
      overtimeHours: overtimeHours,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Reports'),
      ),
      body: Column(
        children: [
          // Period Selector
          _buildPeriodSelector(),

          // Summary Cards
          if (!_isLoading) _buildSummaryCards(),

          // Team Members List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _teamMembers.isEmpty
                    ? _buildEmptyState()
                    : _buildTeamList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Text('Period: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                DropdownMenuItem(value: 'last_week', child: Text('Last Week')),
                DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                DropdownMenuItem(value: 'last_month', child: Text('Last Month')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPeriod = value;
                    _setPeriodDates();
                  });
                  _loadTeamData();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${DateFormat('MMM d').format(_periodStart)} - ${DateFormat('MMM d, yyyy').format(_periodEnd)}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    // Calculate team totals
    double totalActualHours = 0;
    double totalScheduledHours = 0;
    double totalOvertimeHours = 0;
    int activeEmployees = 0;

    for (final data in _reportData.values) {
      totalActualHours += data.actualHours;
      totalScheduledHours += data.scheduledHours;
      totalOvertimeHours += data.overtimeHours;
      if (data.actualHours > 0) activeEmployees++;
    }

    final avgAttendance = totalScheduledHours > 0
        ? (totalActualHours / totalScheduledHours * 100).clamp(0.0, 150.0).toDouble()
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildSummaryCard('Team Members', _teamMembers.length.toString(), Icons.people, Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Active', activeEmployees.toString(), Icons.person_pin, Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Total Hours', totalActualHours.toStringAsFixed(1), Icons.access_time, Colors.purple)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Overtime', totalOvertimeHours.toStringAsFixed(1), Icons.timer, Colors.orange)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('Avg Attendance', '${avgAttendance.toStringAsFixed(0)}%', Icons.check_circle, _getAttendanceColor(avgAttendance))),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
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
          Text('No team members found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Employees assigned to you will appear here', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildTeamList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _teamMembers.length,
      itemBuilder: (context, index) {
        final employee = _teamMembers[index];
        final data = _reportData[employee.id];

        if (data == null) {
          return const SizedBox.shrink();
        }

        return _buildEmployeeCard(data);
      },
    );
  }

  Widget _buildEmployeeCard(_EmployeeReportData data) {
    final employee = data.employee;
    final hoursVariance = data.actualHours - data.scheduledHours;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getAttendanceColor(data.attendanceRate),
          child: Text(
            employee.firstName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(employee.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            _buildChip('${data.actualHours.toStringAsFixed(1)}h worked', Colors.blue),
            const SizedBox(width: 8),
            if (data.overtimeHours > 0)
              _buildChip('${data.overtimeHours.toStringAsFixed(1)}h OT', Colors.orange),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${data.attendanceRate.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getAttendanceColor(data.attendanceRate),
              ),
            ),
            Text('attendance', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Scheduled Hours', '${data.scheduledHours.toStringAsFixed(1)}h'),
                _buildDetailRow('Actual Hours', '${data.actualHours.toStringAsFixed(1)}h'),
                _buildDetailRow(
                  'Variance',
                  '${hoursVariance >= 0 ? '+' : ''}${hoursVariance.toStringAsFixed(1)}h',
                  valueColor: hoursVariance >= 0 ? Colors.green : Colors.red,
                ),
                _buildDetailRow('Time Entries', data.totalEntries.toString()),
                _buildDetailRow('Overtime Hours', '${data.overtimeHours.toStringAsFixed(1)}h'),
                const Divider(),
                _buildDetailRow('Hourly Rate', '\$${employee.hourlyRate.toStringAsFixed(2)}'),
                _buildDetailRow('Est. Regular Pay', '\$${(data.actualHours.clamp(0, 40) * employee.hourlyRate).toStringAsFixed(2)}'),
                if (data.overtimeHours > 0)
                  _buildDetailRow('Est. OT Pay', '\$${(data.overtimeHours * employee.hourlyRate * 1.5).toStringAsFixed(2)}', valueColor: Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  Color _getAttendanceColor(double rate) {
    if (rate >= 95) return Colors.green;
    if (rate >= 80) return Colors.lightGreen;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }
}

class _EmployeeReportData {
  final UserModel employee;
  final double actualHours;
  final double scheduledHours;
  final double attendanceRate;
  final int totalEntries;
  final int lateArrivals;
  final int earlyDepartures;
  final double overtimeHours;

  _EmployeeReportData({
    required this.employee,
    required this.actualHours,
    required this.scheduledHours,
    required this.attendanceRate,
    required this.totalEntries,
    required this.lateArrivals,
    required this.earlyDepartures,
    required this.overtimeHours,
  });
}
