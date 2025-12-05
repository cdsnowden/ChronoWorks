import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/shift_model.dart';
import '../../models/shift_template_model.dart';
import '../../models/user_model.dart';
import '../../models/time_off_request_model.dart';
import '../../services/auth_provider.dart';
import '../../services/schedule_service.dart';
import '../../services/shift_template_service.dart';
import '../../services/employee_service.dart';
import '../../services/overtime_service.dart';
import '../../services/overtime_request_service.dart';
import '../../services/time_off_request_service.dart';
import '../../utils/constants.dart';
import '../../routes.dart';

class ScheduleGridScreen extends StatefulWidget {
  const ScheduleGridScreen({super.key});

  @override
  State<ScheduleGridScreen> createState() => _ScheduleGridScreenState();
}

class _ScheduleGridScreenState extends State<ScheduleGridScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final EmployeeService _employeeService = EmployeeService();
  final TimeOffRequestService _timeOffService = TimeOffRequestService();

  DateTime _selectedDate = DateTime.now();
  List<UserModel> _employees = [];
  Map<String, List<ShiftModel>> _shiftsMap = {}; // employeeId -> shifts
  Map<String, List<TimeOffRequestModel>> _timeOffMap = {}; // employeeId -> time-off requests

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    print('DEBUG: Loading data for user: ${currentUser?.email} (${currentUser?.role})');

    List<UserModel> employees;

    if (currentUser == null || currentUser.companyId.isEmpty) {
      print('ERROR: No current user or companyId found');
      setState(() {
        _employees = [];
      });
      return;
    }

    // Get users from the same company (service now filters by companyId)
    final allUsers = await _employeeService.getAllEmployees(currentUser.companyId);
    print('DEBUG: Loaded ${allUsers.length} users from company ${currentUser.companyId}');

    // Filter to show employees, managers, and admins (all schedulable)
    employees = allUsers.where((u) =>
      u.role == UserRoles.employee ||
      u.role == UserRoles.manager ||
      u.role == UserRoles.admin
    ).toList();

    print('DEBUG: After filtering, ${employees.length} employees/managers/admins to schedule');
    for (var emp in employees) {
      print('  - ${emp.fullName} (${emp.role})');
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

  List<DateTime> get _weekDays {
    return List.generate(7, (index) => _weekStart.add(Duration(days: index)));
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

  double _getEmployeeWeekHours(String employeeId, List<ShiftModel> shifts) {
    return shifts.fold<double>(
      0.0,
      (sum, shift) => sum + shift.durationHours,
    );
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
        title: const Text('Schedule Grid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.access_time),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.shiftTemplates);
            },
            tooltip: 'Shift Templates',
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _today,
            tooltip: 'Go to Today',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _publishSchedule(context),
              icon: const Icon(Icons.send),
              label: const Text('Save & Publish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekNavigator(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ShiftModel>>(
              stream: _scheduleService.getShiftsByDateRangeForEmployees(
                startDate: _weekStart,
                endDate: _weekStart.add(const Duration(days: 7)),
                employeeIds: _employees.map((e) => e.id).toList(),
              ),
              builder: (context, shiftSnapshot) {
                if (shiftSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allShifts = shiftSnapshot.data ?? [];

                // Group shifts by employee
                final shiftsMap = <String, List<ShiftModel>>{};
                for (final shift in allShifts) {
                  shiftsMap.putIfAbsent(shift.employeeId, () => []).add(shift);
                }

                // Get time-off data for the week
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final companyId = authProvider.currentUser?.companyId ?? '';

                return FutureBuilder<List<TimeOffRequestModel>>(
                  future: _timeOffService.getApprovedTimeOffForDateRange(
                    companyId: companyId,
                    startDate: _weekStart,
                    endDate: _weekStart.add(const Duration(days: 7)),
                  ),
                  builder: (context, timeOffSnapshot) {
                    final allTimeOff = timeOffSnapshot.data ?? [];

                    // Group time-off by employee
                    final timeOffMap = <String, List<TimeOffRequestModel>>{};
                    for (final timeOff in allTimeOff) {
                      timeOffMap.putIfAbsent(timeOff.employeeId, () => []).add(timeOff);
                    }

                    return _buildScheduleGrid(currentUserId, companyId, shiftsMap, timeOffMap);
                  },
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
    final weekEnd = _weekStart.add(const Duration(days: 6));

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
                '${startFormat.format(_weekStart)} - ${endFormat.format(weekEnd)}',
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
    final weekEnd = _weekStart.add(const Duration(days: 7));
    return _weekStart.isBefore(now) && weekEnd.isAfter(now);
  }

  Widget _buildScheduleGrid(
    String currentUserId,
    String companyId,
    Map<String, List<ShiftModel>> shiftsMap,
    Map<String, List<TimeOffRequestModel>> timeOffMap,
  ) {
    if (_employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No employees to schedule',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          ),
          dataRowHeight: 120,
          border: TableBorder.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          columns: [
            DataColumn(
              label: SizedBox(
                width: 150,
                child: Text(
                  'Employee',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            ..._weekDays.map((day) {
              final isToday = _isSameDay(day, DateTime.now());
              return DataColumn(
                label: SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(day),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      Text(
                        DateFormat('M/d').format(day),
                        style: TextStyle(
                          fontSize: 12,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          rows: _employees.map((employee) {
            final employeeShifts = shiftsMap[employee.id] ?? [];
            final employeeTimeOff = timeOffMap[employee.id] ?? [];
            final weekHours = _getEmployeeWeekHours(employee.id, employeeShifts);

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                employee.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (weekHours >= 35) ...[
                              Icon(
                                weekHours > 40
                                    ? Icons.warning_amber_rounded
                                    : Icons.info_outline,
                                size: 16,
                                color: weekHours > 40
                                    ? Colors.red
                                    : weekHours >= 38
                                        ? Colors.orange
                                        : Colors.blue,
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${weekHours.toStringAsFixed(1)} hrs',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: weekHours >= 35 ? FontWeight.w600 : FontWeight.normal,
                                color: weekHours > 40
                                    ? Colors.red
                                    : weekHours >= 38
                                        ? Colors.orange
                                        : weekHours >= 35
                                            ? Colors.blue
                                            : Colors.grey.shade600,
                              ),
                            ),
                            if (weekHours > 40) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(+${(weekHours - 40).toStringAsFixed(1)} OT)',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ..._weekDays.map((day) {
                  final shift = _getShiftForDay(employeeShifts, day);
                  final timeOff = _getTimeOffForDay(employeeTimeOff, day);
                  final isToday = _isSameDay(day, DateTime.now());

                  Widget cellContent;
                  if (timeOff != null) {
                    // Show time-off (takes priority over shifts)
                    cellContent = _buildTimeOffCell(timeOff);
                  } else if (shift != null) {
                    // Show shift
                    cellContent = _buildShiftCell(shift);
                  } else {
                    // Show empty cell with add icon
                    cellContent = const Center(
                      child: Icon(
                        Icons.add_circle_outline,
                        color: Colors.grey,
                        size: 20,
                      ),
                    );
                  }

                  return DataCell(
                    InkWell(
                      onTap: () => _showShiftOptions(
                        currentUserId,
                        companyId,
                        employee,
                        day,
                        shift,
                      ),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.2)
                              : null,
                        ),
                        child: cellContent,
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  ShiftModel? _getShiftForDay(List<ShiftModel> shifts, DateTime day) {
    for (final shift in shifts) {
      final shiftDate = shift.startTime ?? shift.createdAt;
      if (_isSameDay(shiftDate, day)) {
        return shift;
      }
    }
    return null;
  }

  Widget _buildShiftCell(ShiftModel shift) {
    return Container(
      decoration: BoxDecoration(
        color: shift.isPublished ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(4),
      child: shift.isDayOff
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    shift.dayOffType == 'holiday'
                        ? Icons.celebration
                        : Icons.event_busy,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shift.dayOffType == 'paid'
                        ? 'Paid Off'
                        : shift.dayOffType == 'holiday'
                            ? 'Holiday'
                            : 'Day Off',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (shift.paidHours != null)
                    Text(
                      '${shift.paidHours!.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shift.formattedTimeRange.split(' - ')[0], // Start time
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  shift.formattedTimeRange.split(' - ')[1], // End time
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  '${shift.durationHours.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
    );
  }

  void _showShiftOptions(
    String currentUserId,
    String companyId,
    UserModel employee,
    DateTime day,
    ShiftModel? existingShift,
  ) {
    showDialog(
      context: context,
      builder: (context) => _ShiftOptionsDialog(
        currentUserId: currentUserId,
        companyId: companyId,
        employee: employee,
        day: day,
        existingShift: existingShift,
        scheduleService: _scheduleService,
      ),
    );
  }

  TimeOffRequestModel? _getTimeOffForDay(List<TimeOffRequestModel> timeOffRequests, DateTime day) {
    for (final timeOff in timeOffRequests) {
      // Check if the day falls within the time-off date range
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);

      if ((timeOff.startDate.isBefore(dayEnd) || timeOff.startDate.isAtSameMomentAs(dayStart)) &&
          (timeOff.endDate.isAfter(dayStart) || timeOff.endDate.isAtSameMomentAs(dayStart))) {
        return timeOff;
      }
    }
    return null;
  }

  Widget _buildTimeOffCell(TimeOffRequestModel timeOff) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.purple.shade300, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.beach_access,
              size: 20,
              color: Colors.purple.shade700,
            ),
            const SizedBox(height: 4),
            Text(
              timeOff.typeLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            if (timeOff.daysRequested > 1)
              Text(
                '(${timeOff.daysRequested} days)',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.purple.shade700,
                ),
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

  // Check if there's a keyholder covering all hours when someone is working
  Future<List<String>> _checkKeyholdersForWeek(
    List<ShiftModel> allShifts,
    Map<String, List<ShiftModel>> shiftsMap,
  ) async {
    final daysWithoutKeyholders = <String>[];

    print('DEBUG: Checking keyholders for week with ${allShifts.length} total shifts');

    for (final day in _weekDays) {
      // Get all shifts for this day across all employees
      final dayShifts = allShifts.where((shift) {
        final shiftDate = shift.startTime ?? shift.createdAt;
        return _isSameDay(shiftDate, day) && !shift.isDayOff;
      }).toList();

      if (dayShifts.isEmpty) {
        print('DEBUG: No shifts on ${DateFormat('EEEE, MMM d').format(day)}');
        continue; // No shifts on this day
      }

      print('DEBUG: ${dayShifts.length} shifts on ${DateFormat('EEEE, MMM d').format(day)}');

      // Get employee data for all shifts
      final shiftsWithEmployees = <Map<String, dynamic>>[];
      for (final shift in dayShifts) {
        try {
          final employeeDoc = await _employeeService.getEmployeeById(shift.employeeId);
          if (employeeDoc != null && shift.startTime != null && shift.endTime != null) {
            shiftsWithEmployees.add({
              'shift': shift,
              'employee': employeeDoc,
              'startTime': shift.startTime!,
              'endTime': shift.endTime!,
            });
            print('DEBUG: ${employeeDoc.fullName} (${shift.startTime!.hour}:${shift.startTime!.minute.toString().padLeft(2, '0')} - ${shift.endTime!.hour}:${shift.endTime!.minute.toString().padLeft(2, '0')}) - Keyholder: ${employeeDoc.isKeyholder}');
          }
        } catch (e) {
          print('ERROR: Failed to check employee ${shift.employeeId}: $e');
        }
      }

      if (shiftsWithEmployees.isEmpty) continue;

      // Find the earliest and latest times
      DateTime? earliestStart;
      DateTime? latestEnd;
      for (final data in shiftsWithEmployees) {
        final start = data['startTime'] as DateTime;
        final end = data['endTime'] as DateTime;
        if (earliestStart == null || start.isBefore(earliestStart)) {
          earliestStart = start;
        }
        if (latestEnd == null || end.isAfter(latestEnd)) {
          latestEnd = end;
        }
      }

      if (earliestStart == null || latestEnd == null) continue;

      // Check every 30-minute interval to ensure keyholder coverage
      bool hasGap = false;
      String? gapDetails;

      DateTime currentTime = earliestStart;
      while (currentTime.isBefore(latestEnd)) {
        // Check if there's a keyholder working at this time
        bool keyholderPresent = false;

        for (final data in shiftsWithEmployees) {
          final employee = data['employee'] as UserModel;
          final shiftStart = data['startTime'] as DateTime;
          final shiftEnd = data['endTime'] as DateTime;

          // Check if this employee is working at currentTime
          if (employee.isKeyholder &&
              (currentTime.isAtSameMomentAs(shiftStart) || currentTime.isAfter(shiftStart)) &&
              currentTime.isBefore(shiftEnd)) {
            keyholderPresent = true;
            break;
          }
        }

        if (!keyholderPresent) {
          // Check if anyone is working at this time
          bool someoneWorking = false;
          for (final data in shiftsWithEmployees) {
            final shiftStart = data['startTime'] as DateTime;
            final shiftEnd = data['endTime'] as DateTime;

            if ((currentTime.isAtSameMomentAs(shiftStart) || currentTime.isAfter(shiftStart)) &&
                currentTime.isBefore(shiftEnd)) {
              someoneWorking = true;
              break;
            }
          }

          if (someoneWorking) {
            hasGap = true;
            final timeStr = '${currentTime.hour}:${currentTime.minute.toString().padLeft(2, '0')}';
            gapDetails = gapDetails == null ? timeStr : '$gapDetails, $timeStr';
            print('WARNING: No keyholder at $timeStr on ${DateFormat('EEEE, MMM d').format(day)}');
          }
        }

        // Move to next 30-minute interval
        currentTime = currentTime.add(const Duration(minutes: 30));
      }

      if (hasGap) {
        final dayName = DateFormat('EEEE, MMM d').format(day);
        print('WARNING: Keyholder gap found on $dayName');
        daysWithoutKeyholders.add('$dayName (missing keyholder coverage)');
      }
    }

    print('DEBUG: Days without full keyholder coverage: ${daysWithoutKeyholders.length}');
    return daysWithoutKeyholders;
  }

  // Publish schedule and send emails
  Future<void> _publishSchedule(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companyId = authProvider.currentUser?.companyId;

    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No company ID found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get all shifts for the week
      final allShifts = await _scheduleService.getShiftsByDateRangeForEmployees(
        startDate: _weekStart,
        endDate: _weekStart.add(const Duration(days: 7)),
        employeeIds: _employees.map((e) => e.id).toList(),
      ).first;

      if (allShifts.isEmpty) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No shifts to publish for this week'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Group shifts by employee
      final shiftsMap = <String, List<ShiftModel>>{};
      for (final shift in allShifts) {
        shiftsMap.putIfAbsent(shift.employeeId, () => []).add(shift);
      }

      // Check for keyholders
      final daysWithoutKeyholders = await _checkKeyholdersForWeek(allShifts, shiftsMap);

      Navigator.of(context).pop(); // Close loading

      // Show warning if there are days without keyholders
      if (daysWithoutKeyholders.isNotEmpty && context.mounted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text('Keyholder Warning'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The following days do not have a keyholder scheduled:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...daysWithoutKeyholders.map((day) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(day),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                const Text('Do you want to continue publishing the schedule anyway?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Publish Anyway'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) return;
      }

      // Show publishing dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Publishing schedule and sending emails...'),
              ],
            ),
          ),
        );
      }

      // Call Cloud Function to publish schedule
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('publishSchedule').call({
        'companyId': companyId,
        'weekStart': _weekStart.toIso8601String(),
        'weekEnd': _weekStart.add(const Duration(days: 6)).toIso8601String(),
      });

      if (context.mounted) {
        Navigator.of(context).pop(); // Close publishing dialog

        final emailsSent = result.data['emailsSent'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Schedule published successfully! Emails sent to $emailsSent employees.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close any open dialogs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing schedule: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

class _ShiftOptionsDialog extends StatefulWidget {
  final String currentUserId;
  final String companyId;
  final UserModel employee;
  final DateTime day;
  final ShiftModel? existingShift;
  final ScheduleService scheduleService;

  const _ShiftOptionsDialog({
    required this.currentUserId,
    required this.companyId,
    required this.employee,
    required this.day,
    required this.existingShift,
    required this.scheduleService,
  });

  @override
  State<_ShiftOptionsDialog> createState() => _ShiftOptionsDialogState();
}

class _ShiftOptionsDialogState extends State<_ShiftOptionsDialog> {
  final ShiftTemplateService _templateService = ShiftTemplateService();
  final OvertimeService _overtimeService = OvertimeService();
  final OvertimeRequestService _overtimeRequestService = OvertimeRequestService();
  List<ShiftTemplateModel> _customTemplates = [];
  bool _loadingTemplates = true;

  @override
  void initState() {
    super.initState();
    _loadCustomTemplates();
  }

  Future<void> _loadCustomTemplates() async {
    try {
      final templates = await _templateService.getCompanyTemplatesStream(widget.companyId).first;
      setState(() {
        _customTemplates = templates;
        _loadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        _loadingTemplates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingShift != null ? 'Edit Shift' : 'Add Shift',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.employee.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                DateFormat('EEEE, MMM d, yyyy').format(widget.day),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 24),
              if (widget.existingShift != null) ...[
              Text(
                'Current Shift:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingShift!.formattedTimeRange,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('${widget.existingShift!.durationHours.toStringAsFixed(1)} hrs'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_customTemplates.isNotEmpty) ...[
              Text(
                'Templates:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              ..._customTemplates.map((template) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton(
                    onPressed: () => _assignCustomTemplate(context, template),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: template.isGlobal ? const Color(0xFF2E7D32) : const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (template.isGlobal)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.public, size: 16, color: Color(0xFFFDD835)),
                              ),
                            Text(template.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          template.formattedTimeRange,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.shiftTemplates);
              },
              icon: const Icon(Icons.settings),
              label: const Text('Manage Templates'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            if (widget.existingShift != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteShift(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _togglePublish(context),
                      icon: Icon(widget.existingShift!.isPublished
                          ? Icons.visibility_off
                          : Icons.visibility),
                      label: Text(widget.existingShift!.isPublished
                          ? 'Unpublish'
                          : 'Publish'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _assignCustomTemplate(BuildContext context, ShiftTemplateModel template) async {
    try {
      DateTime? startTime;
      DateTime? endTime;
      OvertimeCheckResult? overtimeCheck;

      if (!template.isDayOff) {
        // Regular shift - need times
        if (template.startTime == null || template.endTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template is missing start or end time')),
          );
          return;
        }

        startTime = DateTime(
          widget.day.year,
          widget.day.month,
          widget.day.day,
          template.startTime!.hour,
          template.startTime!.minute,
        );
        endTime = DateTime(
          widget.day.year,
          widget.day.month,
          widget.day.day,
          template.endTime!.hour,
          template.endTime!.minute,
        );

        // Check for overtime on regular shifts (not day offs)
        overtimeCheck = await _overtimeService.checkScheduleOvertime(
          employeeId: widget.employee.id,
          shiftStartTime: startTime,
          shiftEndTime: endTime,
          excludeShiftId: widget.existingShift?.id,
        );

        if (overtimeCheck.wouldCauseOvertime) {
          // Show overtime warning dialog
          final proceed = await _showOvertimeWarningDialog(context, overtimeCheck);
          if (proceed != true) {
            return; // User cancelled
          }
        }
      } else {
        // Day off - set startTime to beginning of day for date tracking
        startTime = DateTime(
          widget.day.year,
          widget.day.month,
          widget.day.day,
        );
      }

      ShiftModel? createdShift;

      if (widget.existingShift != null) {
        // Update existing shift
        await widget.scheduleService.updateShift(
          shiftId: widget.existingShift!.id,
          startTime: startTime,
          endTime: endTime,
        );
      } else {
        // Create new shift
        createdShift = await widget.scheduleService.createShift(
          employeeId: widget.employee.id,
          startTime: startTime,
          endTime: endTime,
          createdBy: widget.currentUserId,
          isPublished: false,
          isDayOff: template.isDayOff,
          dayOffType: template.dayOffType,
          paidHours: template.paidHours,
        );
      }

      // If overtime was detected and this is a new shift, create an overtime request
      if (overtimeCheck != null && overtimeCheck.wouldCauseOvertime && createdShift != null) {
        await _createOvertimeRequest(createdShift, overtimeCheck);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingShift != null
                  ? 'Shift updated successfully'
                  : overtimeCheck?.wouldCauseOvertime == true
                      ? 'Overtime shift created - Admin will be notified'
                      : 'Shift created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createOvertimeRequest(ShiftModel shift, OvertimeCheckResult overtimeCheck) async {
    try {
      // Get current user info (manager who created the shift)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        print('Error: Current user is null, cannot create overtime request');
        return;
      }

      await _overtimeRequestService.createOvertimeRequest(
        shiftId: shift.id,
        employeeId: widget.employee.id,
        employeeName: widget.employee.fullName,
        managerId: currentUser.id,
        managerName: currentUser.fullName,
        shiftStartTime: shift.startTime!,
        shiftEndTime: shift.endTime!,
        shiftHours: overtimeCheck.newShiftHours,
        weeklyHoursBeforeShift: overtimeCheck.currentWeeklyHours,
        projectedWeeklyHours: overtimeCheck.projectedTotalHours,
        overtimeHours: overtimeCheck.overtimeHours,
        weekStartDate: overtimeCheck.weekStartDate,
        weekEndDate: overtimeCheck.weekEndDate,
      );

      print('Overtime request created for shift ${shift.id}');
    } catch (e) {
      print('Error creating overtime request: $e');
      // Don't throw - we don't want to fail the shift creation if the overtime request fails
    }
  }

  Future<bool?> _showOvertimeWarningDialog(
    BuildContext context,
    OvertimeCheckResult overtimeCheck,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Overtime Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This shift will cause ${widget.employee.fullName} to exceed 40 hours this week.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  _buildOvertimeRow(
                    'Current hours:',
                    '${overtimeCheck.currentWeeklyHours.toStringAsFixed(1)}h',
                    Colors.grey.shade700,
                  ),
                  const SizedBox(height: 8),
                  _buildOvertimeRow(
                    'New shift:',
                    '${overtimeCheck.newShiftHours.toStringAsFixed(1)}h',
                    Colors.blue.shade700,
                  ),
                  const Divider(height: 16),
                  _buildOvertimeRow(
                    'Projected total:',
                    '${overtimeCheck.projectedTotalHours.toStringAsFixed(1)}h',
                    Colors.orange.shade800,
                  ),
                  const SizedBox(height: 8),
                  _buildOvertimeRow(
                    'Overtime hours:',
                    '${overtimeCheck.overtimeHours.toStringAsFixed(1)}h',
                    Colors.red.shade700,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Week: ${DateFormat('MMM d').format(overtimeCheck.weekStartDate)} - ${DateFormat('MMM d, yyyy').format(overtimeCheck.weekEndDate)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteShift(BuildContext context) async {
    if (widget.existingShift == null) return;

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await widget.scheduleService.deleteShift(widget.existingShift!.id);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _togglePublish(BuildContext context) async {
    if (widget.existingShift == null) return;

    try {
      if (widget.existingShift!.isPublished) {
        await widget.scheduleService.unpublishShift(widget.existingShift!.id);
      } else {
        await widget.scheduleService.publishShift(widget.existingShift!.id);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingShift!.isPublished
                  ? 'Shift unpublished'
                  : 'Shift published',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
