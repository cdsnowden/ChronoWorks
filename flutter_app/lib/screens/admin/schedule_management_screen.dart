import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_provider.dart';
import '../../services/schedule_service.dart';
import '../../services/employee_service.dart';
import '../../widgets/shift_dialog.dart';
import '../../utils/constants.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final EmployeeService _employeeService = EmployeeService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  List<UserModel> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null || currentUser.companyId.isEmpty) {
      print('ERROR: No current user or companyId found');
      setState(() {
        _employees = [];
      });
      return;
    }

    List<UserModel> employees;

    // If manager, only show their team members (with companyId filtering)
    if (currentUser.role == UserRoles.manager) {
      employees = await _employeeService.getEmployeesByManagerId(currentUser.id, currentUser.companyId);
    } else {
      // Admin sees all employees from their company
      employees = await _employeeService.getAllEmployees(currentUser.companyId);
    }

    setState(() {
      _employees = employees;
    });
  }

  DateTime get _weekStart {
    final now = _selectedDate;
    final difference = now.weekday % 7; // Sunday = 0
    return DateTime(now.year, now.month, now.day).subtract(
      Duration(days: difference),
    );
  }

  DateTime get _weekEnd {
    return _weekStart.add(const Duration(days: 7));
  }

  void _previousWeek() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 7));
    });
  }

  void _today() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _today,
            tooltip: 'Go to Today',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateShiftDialog(currentUserId),
            tooltip: 'Create Shift',
          ),
        ],
      ),
      body: Column(
        children: [
          // Week Navigator
          _buildWeekNavigator(),

          // Employee Filter
          _buildEmployeeFilter(),

          const Divider(height: 1),

          // Shifts List
          Expanded(
            child: StreamBuilder<List<ShiftModel>>(
              stream: _selectedEmployeeId != null
                  ? _scheduleService.getEmployeeShiftsByDateRange(
                      employeeId: _selectedEmployeeId!,
                      startDate: _weekStart,
                      endDate: _weekEnd,
                    )
                  : _scheduleService.getShiftsByDateRange(
                      startDate: _weekStart,
                      endDate: _weekEnd,
                    ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final shifts = snapshot.data ?? [];

                if (shifts.isEmpty) {
                  return _buildEmptyState(currentUserId);
                }

                return _buildShiftsList(shifts, currentUserId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator() {
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousWeek,
          ),
          Column(
            children: [
              Text(
                '${startFormat.format(_weekStart)} - ${endFormat.format(_weekEnd.subtract(const Duration(days: 1)))}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _isCurrentWeek() ? 'This Week' : '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextWeek,
          ),
        ],
      ),
    );
  }

  bool _isCurrentWeek() {
    final now = DateTime.now();
    return _weekStart.isBefore(now) && _weekEnd.isAfter(now);
  }

  Widget _buildEmployeeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.filter_list),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _selectedEmployeeId,
              decoration: const InputDecoration(
                labelText: 'Filter by Employee',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Employees'),
                ),
                ..._employees.map((employee) {
                  return DropdownMenuItem<String?>(
                    value: employee.id,
                    child: Text(employee.fullName),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedEmployeeId = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsList(List<ShiftModel> shifts, String currentUserId) {
    // Group shifts by date
    final groupedShifts = <DateTime, List<ShiftModel>>{};
    for (final shift in shifts) {
      final date = DateTime(
        shift.startTime.year,
        shift.startTime.month,
        shift.startTime.day,
      );
      groupedShifts.putIfAbsent(date, () => []).add(shift);
    }

    // Sort dates
    final sortedDates = groupedShifts.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayShifts = groupedShifts[date]!;

        return _buildDaySection(date, dayShifts, currentUserId);
      },
    );
  }

  Widget _buildDaySection(
      DateTime date, List<ShiftModel> shifts, String currentUserId) {
    final isToday = _isSameDay(date, DateTime.now());
    final dayFormat = DateFormat('EEEE, MMM d');
    final totalHours = shifts.fold<double>(
      0.0,
      (sum, shift) => sum + shift.durationHours,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Header with Summary
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    dayFormat.format(date),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${shifts.length} shifts • ${totalHours.toStringAsFixed(1)}h',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),

        // Shifts for this day
        ...shifts.map((shift) => _buildShiftCard(shift, currentUserId)),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildShiftCard(ShiftModel shift, String currentUserId) {
    final employee = _employees.firstWhere(
      (e) => e.id == shift.employeeId,
      orElse: () => UserModel(
        id: '',
        email: '',
        firstName: 'Unknown',
        lastName: 'Employee',
        role: 'employee',
        employmentType: 'full-time',
        hourlyRate: 0.0,
        createdAt: DateTime.now(),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: shift.isPublished ? Colors.green : Colors.orange,
          child: Text(
            employee.firstName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Text(employee.fullName),
            const SizedBox(width: 8),
            if (!shift.isPublished)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text(
                  'Draft',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shift.formattedTimeRange),
            if (shift.location != null)
              Text(
                shift.location!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${shift.durationHours.toStringAsFixed(1)}h',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditShiftDialog(shift, currentUserId);
                    break;
                  case 'publish':
                    _togglePublishShift(shift);
                    break;
                  case 'delete':
                    _deleteShift(shift);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(shift.isPublished
                          ? Icons.visibility_off
                          : Icons.visibility),
                      const SizedBox(width: 8),
                      Text(shift.isPublished ? 'Unpublish' : 'Publish'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String currentUserId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Shifts Scheduled',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create shifts for this week to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateShiftDialog(currentUserId),
              icon: const Icon(Icons.add),
              label: const Text('Create Shift'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateShiftDialog(String currentUserId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyId = authProvider.currentUser?.companyId ?? '';

    showDialog(
      context: context,
      builder: (context) => ShiftDialog(
        currentUserId: currentUserId,
        companyId: companyId,
      ),
    );
  }

  void _showEditShiftDialog(ShiftModel shift, String currentUserId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyId = authProvider.currentUser?.companyId ?? '';

    showDialog(
      context: context,
      builder: (context) => ShiftDialog(
        shift: shift,
        currentUserId: currentUserId,
        companyId: companyId,
      ),
    );
  }

  Future<void> _togglePublishShift(ShiftModel shift) async {
    try {
      if (shift.isPublished) {
        await _scheduleService.unpublishShift(shift.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift unpublished')),
          );
        }
      } else {
        await _scheduleService.publishShift(shift.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift published')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteShift(ShiftModel shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: const Text('Are you sure you want to delete this shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _scheduleService.deleteShift(shift.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift deleted')),
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
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
