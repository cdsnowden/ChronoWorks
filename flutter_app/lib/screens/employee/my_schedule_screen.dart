import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/shift_model.dart';
import '../../services/auth_provider.dart';
import '../../services/schedule_service.dart';
import '../../services/overtime_service.dart';

class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  DateTime _selectedDate = DateTime.now();

  // Get the start and end of the current week
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
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _today,
            tooltip: 'Go to Today',
          ),
        ],
      ),
      body: Column(
        children: [
          // Week Navigation
          _buildWeekNavigator(),
          const Divider(height: 1),

          // Schedule Content
          Expanded(
            child: StreamBuilder<List<ShiftModel>>(
              stream: _scheduleService.getEmployeeShiftsByDateRange(
                employeeId: userId,
                startDate: _weekStart,
                endDate: _weekEnd,
                publishedOnly: true,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final shifts = snapshot.data ?? [];

                if (shifts.isEmpty) {
                  return _buildEmptyState();
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildWeeklySummary(shifts),
                      const SizedBox(height: 16),
                      _buildShiftsList(shifts),
                    ],
                  ),
                );
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

  Widget _buildWeeklySummary(List<ShiftModel> shifts) {
    final totalHours = shifts.fold<double>(
      0.0,
      (sum, shift) => sum + shift.durationHours,
    );

    final isOvertime = totalHours > 40;
    final isApproaching = totalHours >= 35 && totalHours <= 40;
    final overtimeHours = isOvertime ? totalHours - 40 : 0.0;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.calendar_today,
                label: 'Shifts',
                value: shifts.length.toString(),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey.shade300,
              ),
              _buildSummaryItem(
                icon: Icons.access_time,
                label: 'Hours',
                value: '${totalHours.toStringAsFixed(1)}h',
                valueColor: isOvertime
                    ? Colors.red
                    : isApproaching
                        ? Colors.orange
                        : null,
              ),
            ],
          ),
        ),
        if (isOvertime) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Overtime: You have ${overtimeHours.toStringAsFixed(1)} hours over the 40-hour threshold this week.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isApproaching) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Approaching overtime: You have ${(40 - totalHours).toStringAsFixed(1)} hours remaining before overtime.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: valueColor ?? Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildShiftsList(List<ShiftModel> shifts) {
    // Group shifts by date
    final groupedShifts = <DateTime, List<ShiftModel>>{};
    for (final shift in shifts) {
      final shiftDate = shift.startTime ?? shift.createdAt;
      final date = DateTime(
        shiftDate.year,
        shiftDate.month,
        shiftDate.day,
      );
      groupedShifts.putIfAbsent(date, () => []).add(shift);
    }

    // Sort dates
    final sortedDates = groupedShifts.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayShifts = groupedShifts[date]!;

        return _buildDaySection(date, dayShifts);
      },
    );
  }

  Widget _buildDaySection(DateTime date, List<ShiftModel> shifts) {
    final isToday = _isSameDay(date, DateTime.now());
    final dayFormat = DateFormat('EEEE, MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
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
        ),

        // Shifts for this day
        ...shifts.map((shift) => _buildShiftCard(shift, isToday)),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildShiftCard(ShiftModel shift, bool isToday) {
    final isActive = shift.isActive;
    final isPast = shift.isPast;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isToday
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 20,
                      color: isActive
                          ? Colors.green
                          : isPast
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      shift.formattedTimeRange,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isPast ? Colors.grey : null,
                          ),
                    ),
                  ],
                ),

                // Duration
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.shade100
                        : isPast
                            ? Colors.grey.shade200
                            : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${shift.durationHours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      color: isActive
                          ? Colors.green.shade700
                          : isPast
                              ? Colors.grey.shade700
                              : Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // Status indicator
            if (isActive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Currently Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Location
            if (shift.location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    shift.location!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ],
              ),
            ],

            // Notes
            if (shift.notes != null && shift.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shift.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              'You have no shifts scheduled for this week',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
