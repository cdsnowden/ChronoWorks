import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/time_entry_model.dart';
import '../../models/user_model.dart';
import '../../services/time_entry_service.dart';
import '../../services/employee_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/dialogs/edit_time_entry_dialog.dart';

class AdminTimeTrackingScreen extends StatefulWidget {
  const AdminTimeTrackingScreen({super.key});

  @override
  State<AdminTimeTrackingScreen> createState() =>
      _AdminTimeTrackingScreenState();
}

class _AdminTimeTrackingScreenState extends State<AdminTimeTrackingScreen> {
  final TimeEntryService _timeEntryService = TimeEntryService();
  final EmployeeService _employeeService = EmployeeService();
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditDialog(
      TimeEntryModel entry, String employeeName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get current user details
    final currentUserDetails = await _employeeService.getEmployeeById(currentUser.uid);
    if (currentUserDetails == null || !mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditTimeEntryDialog(
        timeEntry: entry,
        employeeName: employeeName,
        editorId: currentUser.uid,
        editorName: currentUserDetails.fullName,
      ),
    );

    // If dialog returned true (successful edit), show success message
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time entry updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Time Tracking Overview'),
        ),
        body: const Center(
          child: Text('Error loading user data. Please try again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Tracking Overview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Cards
            _buildStatisticsSection(),
            const SizedBox(height: 24),

            // Currently Clocked In
            Text(
              'Currently Clocked In',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildClockedInSection(),
            const SizedBox(height: 24),

            // Recent Time Entries
            Text(
              'Recent Time Entries',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildRecentEntriesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return StreamBuilder<List<UserModel>>(
      stream: _employeeService.getActiveEmployeesStream(_currentUser!.companyId),
      builder: (context, employeeSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirebaseCollections.activeClockIns)
              .snapshots(),
          builder: (context, clockInSnapshot) {
            // Filter clock-ins by company employees only
            final companyEmployeeIds = employeeSnapshot.data?.map((e) => e.id).toSet() ?? {};
            final filteredDocs = clockInSnapshot.data?.docs
                .where((doc) => companyEmployeeIds.contains(doc.id))
                .toList() ?? [];

            final totalEmployees = employeeSnapshot.data?.length ?? 0;
            final clockedInCount = filteredDocs.length;

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Employees',
                    value: totalEmployees.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Clocked In',
                    value: clockedInCount.toString(),
                    icon: Icons.access_time,
                    color: Colors.green,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockedInSection() {
    return StreamBuilder<List<UserModel>>(
      stream: _employeeService.getActiveEmployeesStream(_currentUser!.companyId),
      builder: (context, employeeSnapshot) {
        if (employeeSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final companyEmployeeIds = employeeSnapshot.data?.map((e) => e.id).toSet() ?? {};

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirebaseCollections.activeClockIns)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filter to only show employees from this company
            final filteredDocs = snapshot.data?.docs
                .where((doc) => companyEmployeeIds.contains(doc.id))
                .toList() ?? [];

            if (filteredDocs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No one is currently clocked in',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final userId = doc.id;
                final clockInTime =
                    (doc.data() as Map<String, dynamic>)['clockInTime'] as Timestamp;

                return FutureBuilder<UserModel?>(
                  future: _employeeService.getEmployeeById(userId),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final user = userSnapshot.data!;
                    // Double-check company ID for extra security
                    if (user.companyId != _currentUser!.companyId) {
                      return const SizedBox.shrink();
                    }
                    final duration = DateTime.now().difference(clockInTime.toDate());
                    final hours = duration.inHours;
                    final minutes = duration.inMinutes.remainder(60);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            user.firstName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(user.fullName),
                        subtitle: Text(
                          'Clocked in at ${DateFormat.jm().format(clockInTime.toDate())}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${hours}h ${minutes}m',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecentEntriesSection() {
    // First get the list of employees in the company
    return StreamBuilder<List<UserModel>>(
      stream: _employeeService.getActiveEmployeesStream(_currentUser!.companyId),
      builder: (context, employeeSnapshot) {
        if (employeeSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final companyEmployeeIds = employeeSnapshot.data?.map((e) => e.id).toList() ?? [];

        if (companyEmployeeIds.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No employees in your company',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        return StreamBuilder<List<TimeEntryModel>>(
          stream: _timeEntryService.getTimeEntriesForEmployees(companyEmployeeIds),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No time entries yet',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              );
            }

            final entries = snapshot.data!.take(10).toList();

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];

                return FutureBuilder<UserModel?>(
                  future: _employeeService.getEmployeeById(entry.userId),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final user = userSnapshot.data!;
                    // Double-check company ID for extra security
                    if (user.companyId != _currentUser!.companyId) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: entry.isClockedIn
                              ? Colors.green
                              : Colors.blue,
                          child: Text(
                            user.firstName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(user.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, y - h:mm a')
                                  .format(entry.clockInTime),
                            ),
                            if (entry.clockOutTime != null)
                              Text(
                                'Clocked out: ${DateFormat('h:mm a').format(entry.clockOutTime!)}',
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
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (entry.isClockedIn)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Active',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    entry.formattedDuration,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            // Only show edit button for completed entries
                            if (!entry.isClockedIn) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                color: Colors.blue,
                                tooltip: 'Edit Time Entry',
                                onPressed: () => _showEditDialog(entry, user.fullName),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
