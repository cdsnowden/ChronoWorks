import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/time_entry_model.dart';
import '../../models/break_entry_model.dart';
import '../../services/auth_provider.dart';
import '../../services/time_entry_service.dart';
import '../../services/break_service.dart';
import 'dart:async';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  final TimeEntryService _timeEntryService = TimeEntryService();
  final BreakService _breakService = BreakService();
  TimeEntryModel? _activeTimeEntry;
  BreakEntryModel? _activeBreak;
  List<BreakEntryModel> _todaysBreaks = [];
  BreakSummary? _breakSummary;
  BreakComplianceStatus? _breakCompliance;
  bool _isLoading = false;
  bool _isBreakLoading = false;
  Timer? _timer;
  double _weeklyHours = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Update UI every second when clocked in
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeTimeEntry != null && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final activeEntry = await _timeEntryService.getActiveClockIn(userId);
      final weekHours = await _timeEntryService.getCurrentWeekHours(userId);

      // Load break data if user is clocked in
      BreakEntryModel? activeBreak;
      BreakSummary? breakSummary;
      BreakComplianceStatus? breakCompliance;

      if (activeEntry != null) {
        activeBreak = await _breakService.getActiveBreak(userId);
        breakSummary = await _breakService.getBreakSummary(activeEntry.id);
        breakCompliance = await _breakService.checkBreakCompliance(activeEntry);
      }

      if (mounted) {
        setState(() {
          _activeTimeEntry = activeEntry;
          _weeklyHours = weekHours;
          _activeBreak = activeBreak;
          _breakSummary = breakSummary;
          _breakCompliance = breakCompliance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleClockIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get location (REQUIRED)
      final location = await _timeEntryService.getCurrentLocation();

      // Enforce location requirement
      if (location == null) {
        throw Exception(
            'Location access is required to clock in. Please enable location services and grant permission.');
      }

      final timeEntry = await _timeEntryService.clockIn(
        userId: userId,
        location: location,
      );

      if (mounted) {
        setState(() {
          _activeTimeEntry = timeEntry;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Clocked in at ${DateFormat.jm().format(timeEntry.clockInTime)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleClockOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get location (REQUIRED)
      final location = await _timeEntryService.getCurrentLocation();

      // Enforce location requirement
      if (location == null) {
        throw Exception(
            'Location access is required to clock out. Please enable location services and grant permission.');
      }

      final timeEntry = await _timeEntryService.clockOut(
        userId: userId,
        location: location,
      );

      // Reload weekly hours
      final weekHours = await _timeEntryService.getCurrentWeekHours(userId);

      if (mounted) {
        setState(() {
          _activeTimeEntry = null;
          _weeklyHours = weekHours;
          _activeBreak = null;
          _breakSummary = null;
          _breakCompliance = null;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Clocked out • ${timeEntry.formattedDuration} worked'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleStartBreak() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null || _activeTimeEntry == null) return;

    setState(() {
      _isBreakLoading = true;
    });

    try {
      // Get location (REQUIRED)
      final location = await _timeEntryService.getCurrentLocation();

      // Enforce location requirement
      if (location == null) {
        throw Exception(
            'Location access is required to start a break. Please enable location services and grant permission.');
      }

      final breakEntry = await _breakService.startBreak(
        timeEntryId: _activeTimeEntry!.id,
        userId: userId,
        location: location,
      );

      // Reload break data
      final breakSummary = await _breakService.getBreakSummary(_activeTimeEntry!.id);
      final breakCompliance = await _breakService.checkBreakCompliance(_activeTimeEntry!);

      if (mounted) {
        setState(() {
          _activeBreak = breakEntry;
          _breakSummary = breakSummary;
          _breakCompliance = breakCompliance;
          _isBreakLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Break started at ${DateFormat.jm().format(breakEntry.breakStartTime)}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBreakLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleEndBreak() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null || _activeBreak == null || _activeTimeEntry == null) return;

    setState(() {
      _isBreakLoading = true;
    });

    try {
      // Get location (REQUIRED)
      final location = await _timeEntryService.getCurrentLocation();

      // Enforce location requirement
      if (location == null) {
        throw Exception(
            'Location access is required to end a break. Please enable location services and grant permission.');
      }

      final breakEntry = await _breakService.endBreak(
        breakId: _activeBreak!.id,
        location: location,
      );

      // Reload break data
      final breakSummary = await _breakService.getBreakSummary(_activeTimeEntry!.id);
      final breakCompliance = await _breakService.checkBreakCompliance(_activeTimeEntry!);

      if (mounted) {
        setState(() {
          _activeBreak = null;
          _breakSummary = breakSummary;
          _breakCompliance = breakCompliance;
          _isBreakLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Break ended • ${breakEntry.formattedDuration} break time'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBreakLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Clock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _activeTimeEntry == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current Time
                  _buildCurrentTimeCard(),
                  const SizedBox(height: 24),

                  // Status Card
                  _buildStatusCard(),
                  const SizedBox(height: 24),

                  // Clock In/Out Button
                  _buildClockButton(),

                  // Break compliance warning (if applicable)
                  if (_activeTimeEntry != null && _breakCompliance != null)
                    ...[
                      const SizedBox(height: 16),
                      _buildBreakComplianceCard(),
                    ],

                  // Active break indicator (if on break)
                  if (_activeBreak != null)
                    ...[
                      const SizedBox(height: 16),
                      _buildActiveBreakCard(),
                    ],

                  // Break button (if clocked in)
                  if (_activeTimeEntry != null)
                    ...[
                      const SizedBox(height: 16),
                      _buildBreakButton(),
                    ],

                  // Break summary (if clocked in and has breaks)
                  if (_activeTimeEntry != null && _breakSummary != null && _breakSummary!.breakCount > 0)
                    ...[
                      const SizedBox(height: 16),
                      _buildBreakSummaryCard(),
                    ],

                  const SizedBox(height: 32),

                  // Weekly Hours Card
                  _buildWeeklyHoursCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentTimeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              DateFormat.EEEE().format(DateTime.now()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM d, y').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              DateFormat.jms().format(DateTime.now()),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_activeTimeEntry == null) {
      return Card(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.access_time, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Not Clocked In',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Ready to start your shift?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Calculate current duration
    final now = DateTime.now();
    final duration = now.difference(_activeTimeEntry!.clockInTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.timer, size: 48, color: Colors.green.shade700),
            const SizedBox(height: 16),
            Text(
              'Currently Clocked In',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.green.shade900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Started at ${DateFormat.jm().format(_activeTimeEntry!.clockInTime)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${hours}h ${minutes}m',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockButton() {
    final isClockedIn = _activeTimeEntry != null;

    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (isClockedIn ? _handleClockOut : _handleClockIn),
        style: ElevatedButton.styleFrom(
          backgroundColor: isClockedIn ? Colors.orange : Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isClockedIn ? Icons.logout : Icons.login,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    isClockedIn ? 'Clock Out' : 'Clock In',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildWeeklyHoursCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'This Week',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Hours',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_weeklyHours.toStringAsFixed(1)} hrs',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(40 - _weeklyHours).clamp(0, 40).toStringAsFixed(1)} hrs',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (_weeklyHours / 40).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakButton() {
    final isOnBreak = _activeBreak != null;

    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: _isBreakLoading
            ? null
            : (isOnBreak ? _handleEndBreak : _handleStartBreak),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOnBreak ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isBreakLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOnBreak ? Icons.play_arrow : Icons.pause,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isOnBreak ? 'End Break' : 'Start Break',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActiveBreakCard() {
    if (_activeBreak == null) return const SizedBox.shrink();

    // Calculate current break duration
    final now = DateTime.now();
    final duration = now.difference(_activeBreak!.breakStartTime);
    final minutes = duration.inMinutes;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.coffee, size: 32, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On Break',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Started at ${DateFormat.jm().format(_activeBreak!.breakStartTime)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$minutes min',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
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

  Widget _buildBreakComplianceCard() {
    if (_breakCompliance == null) return const SizedBox.shrink();

    // Only show if there's a warning or requirement
    if (!_breakCompliance!.breakWarning && !_breakCompliance!.breakRequired) {
      return const SizedBox.shrink();
    }

    final isRequired = _breakCompliance!.breakRequired;
    final color = isRequired ? Colors.red : Colors.orange;

    return Card(
      color: color.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isRequired ? Icons.warning : Icons.info_outline,
              color: color.shade700,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRequired ? 'Break Required!' : 'Break Recommended',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _breakCompliance!.statusMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakSummaryCard() {
    if (_breakSummary == null || _breakSummary!.breakCount == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.coffee_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Break Summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Breaks Taken',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_breakSummary!.breakCount}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
                Column(
                  children: [
                    Text(
                      'Total Break Time',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _breakSummary!.formattedTotalBreak,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            if (_breakSummary!.breaks.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Break History',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ..._breakSummary!.breaks.where((b) => !b.isOnBreak).map((breakEntry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.blue.shade300),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat.jm().format(breakEntry.breakStartTime)} - ${DateFormat.jm().format(breakEntry.breakEndTime!)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Text(
                        breakEntry.formattedDuration,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}
