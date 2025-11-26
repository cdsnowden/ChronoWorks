import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/blocked_date_model.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../services/blocked_dates_service.dart';

class BlockedDatesScreen extends StatefulWidget {
  const BlockedDatesScreen({Key? key}) : super(key: key);

  @override
  State<BlockedDatesScreen> createState() => _BlockedDatesScreenState();
}

class _BlockedDatesScreenState extends State<BlockedDatesScreen> {
  final _blockedDatesService = BlockedDatesService();
  final _reasonController = TextEditingController();
  DateTime? _selectedDate;
  DateTime? _rangeStartDate;
  DateTime? _rangeEndDate;
  bool _isRangeMode = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Select Date to Block',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _rangeStartDate != null && _rangeEndDate != null
          ? DateTimeRange(start: _rangeStartDate!, end: _rangeEndDate!)
          : null,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Select Date Range to Block',
    );

    if (picked != null) {
      setState(() {
        _rangeStartDate = picked.start;
        _rangeEndDate = picked.end;
      });
    }
  }

  Future<void> _addBlockedDate() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for blocking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isRangeMode && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isRangeMode && (_rangeStartDate == null || _rangeEndDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (_isRangeMode) {
        await _blockedDatesService.createBlockedDateRange(
          companyId: user.companyId,
          startDate: _rangeStartDate!,
          endDate: _rangeEndDate!,
          reason: _reasonController.text.trim(),
          createdBy: user.id,
        );
      } else {
        await _blockedDatesService.createBlockedDate(
          companyId: user.companyId,
          date: _selectedDate!,
          reason: _reasonController.text.trim(),
          createdBy: user.id,
        );
      }

      if (mounted) {
        setState(() {
          _selectedDate = null;
          _rangeStartDate = null;
          _rangeEndDate = null;
          _reasonController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blocked date(s) added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBlockedDate(BlockedDate blockedDate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Blocked Date'),
        content: Text(
          'Are you sure you want to remove the block for ${DateFormat('MMM dd, yyyy').format(blockedDate.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _blockedDatesService.deleteBlockedDate(blockedDate.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Blocked date removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildBlockedDateCard(BlockedDate blockedDate) {
    final isPast = blockedDate.date.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isPast ? Colors.grey.shade100 : null,
      child: ListTile(
        leading: Icon(
          Icons.block,
          color: isPast ? Colors.grey : Colors.red,
        ),
        title: Text(
          DateFormat('EEEE, MMMM dd, yyyy').format(blockedDate.date),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPast ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          blockedDate.reason,
          style: TextStyle(
            color: isPast ? Colors.grey : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteBlockedDate(blockedDate),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Blocked Dates')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Dates'),
      ),
      body: Column(
        children: [
          // Add blocked date form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.block, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Block Dates from Time Off Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _isRangeMode,
                      onChanged: (value) {
                        setState(() {
                          _isRangeMode = value;
                          _selectedDate = null;
                          _rangeStartDate = null;
                          _rangeEndDate = null;
                        });
                      },
                    ),
                    Text(_isRangeMode ? 'Range' : 'Single'),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_isRangeMode) ...[
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _selectedDate != null
                            ? DateFormat('MMMM dd, yyyy').format(_selectedDate!)
                            : 'Select a date to block',
                        style: TextStyle(
                          color: _selectedDate != null
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: _selectDateRange,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select Date Range',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      child: Text(
                        _rangeStartDate != null && _rangeEndDate != null
                            ? '${DateFormat('MMM dd').format(_rangeStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_rangeEndDate!)}'
                            : 'Select a date range to block',
                        style: TextStyle(
                          color: _rangeStartDate != null
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'e.g., Company Holiday, Team Event',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _addBlockedDate,
                  icon: const Icon(Icons.add),
                  label: Text(_isRangeMode ? 'Block Date Range' : 'Block Date'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // List of blocked dates
          Expanded(
            child: StreamBuilder<List<BlockedDate>>(
              stream: _blockedDatesService.getBlockedDatesStream(user.companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final blockedDates = snapshot.data ?? [];

                if (blockedDates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No blocked dates',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add dates to prevent time off requests',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Separate upcoming and past blocked dates
                final now = DateTime.now();
                final normalizedNow = DateTime(now.year, now.month, now.day);
                final upcomingDates = blockedDates
                    .where((d) =>
                        d.date.isAfter(normalizedNow) ||
                        d.date.isAtSameMomentAs(normalizedNow))
                    .toList();
                final pastDates = blockedDates
                    .where((d) => d.date.isBefore(normalizedNow))
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (upcomingDates.isNotEmpty) ...[
                      const Text(
                        'Upcoming & Current',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...upcomingDates.map((date) => _buildBlockedDateCard(date)),
                      if (pastDates.isNotEmpty) const SizedBox(height: 24),
                    ],
                    if (pastDates.isNotEmpty) ...[
                      const Text(
                        'Past',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...pastDates.map((date) => _buildBlockedDateCard(date)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
