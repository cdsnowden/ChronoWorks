import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/time_entry_model.dart';
import '../../services/time_entry_service.dart';

class EditTimeEntryDialog extends StatefulWidget {
  final TimeEntryModel timeEntry;
  final String employeeName;
  final String editorId;
  final String editorName;

  const EditTimeEntryDialog({
    super.key,
    required this.timeEntry,
    required this.employeeName,
    required this.editorId,
    required this.editorName,
  });

  @override
  State<EditTimeEntryDialog> createState() => _EditTimeEntryDialogState();
}

class _EditTimeEntryDialogState extends State<EditTimeEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final TimeEntryService _timeEntryService = TimeEntryService();
  final TextEditingController _reasonController = TextEditingController();

  late DateTime _newClockInDate;
  late TimeOfDay _newClockInTime;
  late DateTime _newClockOutDate;
  late TimeOfDay _newClockOutTime;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing values
    _newClockInDate = widget.timeEntry.clockInTime;
    _newClockInTime = TimeOfDay.fromDateTime(widget.timeEntry.clockInTime);
    _newClockOutDate = widget.timeEntry.clockOutTime ?? DateTime.now();
    _newClockOutTime =
        TimeOfDay.fromDateTime(widget.timeEntry.clockOutTime ?? DateTime.now());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectClockInDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newClockInDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _newClockInDate = picked;
      });
    }
  }

  Future<void> _selectClockInTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _newClockInTime,
    );

    if (picked != null) {
      setState(() {
        _newClockInTime = picked;
      });
    }
  }

  Future<void> _selectClockOutDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newClockOutDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _newClockOutDate = picked;
      });
    }
  }

  Future<void> _selectClockOutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _newClockOutTime,
    );

    if (picked != null) {
      setState(() {
        _newClockOutTime = picked;
      });
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _calculateDuration() {
    final clockIn = _combineDateAndTime(_newClockInDate, _newClockInTime);
    final clockOut = _combineDateAndTime(_newClockOutDate, _newClockOutTime);

    if (clockOut.isBefore(clockIn) || clockOut.isAtSameMomentAs(clockIn)) {
      return 'Invalid';
    }

    final duration = clockOut.difference(clockIn);
    final hours = duration.inMinutes / 60.0;
    return '${hours.toStringAsFixed(1)} hours';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for editing')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newClockIn = _combineDateAndTime(_newClockInDate, _newClockInTime);
      final newClockOut =
          _combineDateAndTime(_newClockOutDate, _newClockOutTime);

      // Validate times
      if (newClockOut.isBefore(newClockIn) ||
          newClockOut.isAtSameMomentAs(newClockIn)) {
        throw Exception('Clock out time must be after clock in time');
      }

      await _timeEntryService.editTimeEntry(
        timeEntryId: widget.timeEntry.id,
        newClockIn: newClockIn,
        newClockOut: newClockOut,
        editorId: widget.editorId,
        editorName: widget.editorName,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time entry updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Time Entry',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Employee Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Employee: ${widget.employeeName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Original Times Section
                  Text(
                    'Original Times',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.login, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Clock In: ${DateFormat('MMM d, y - h:mm a').format(widget.timeEntry.clockInTime)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.logout, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Clock Out: ${widget.timeEntry.clockOutTime != null ? DateFormat('MMM d, y - h:mm a').format(widget.timeEntry.clockOutTime!) : 'N/A'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // New Times Section
                  Text(
                    'New Clock In Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Clock In Date and Time
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _selectClockInDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('MMM d, yyyy').format(_newClockInDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selectClockInTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_newClockInTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // New Clock Out Time
                  Text(
                    'New Clock Out Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Clock Out Date and Time
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _selectClockOutDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('MMM d, yyyy')
                                  .format(_newClockOutDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selectClockOutTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_newClockOutTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Duration Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _calculateDuration() == 'Invalid'
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: _calculateDuration() == 'Invalid'
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: ${_calculateDuration()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _calculateDuration() == 'Invalid'
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reason Field
                  Text(
                    'Reason for Edit *',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Edit Reason',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_note),
                      hintText: 'e.g., Correcting forgotten clock out',
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a reason for editing';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
