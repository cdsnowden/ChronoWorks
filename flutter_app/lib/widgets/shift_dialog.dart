import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';
import '../services/schedule_service.dart';
import '../services/employee_service.dart';

class ShiftDialog extends StatefulWidget {
  final ShiftModel? shift; // Null for create, populated for edit
  final String currentUserId;
  final String companyId;

  const ShiftDialog({
    super.key,
    this.shift,
    required this.currentUserId,
    required this.companyId,
  });

  @override
  State<ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<ShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final ScheduleService _scheduleService = ScheduleService();
  final EmployeeService _employeeService = EmployeeService();

  List<UserModel> _employees = [];
  bool _isLoading = false;

  // Form fields
  String? _selectedEmployeeId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isPublished = false;

  bool get _isEditMode => widget.shift != null;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _initializeFormFields();
  }

  Future<void> _loadEmployees() async {
    final employees = await _employeeService.getAllEmployees(widget.companyId);
    setState(() {
      _employees = employees;
    });
  }

  void _initializeFormFields() {
    if (_isEditMode) {
      final shift = widget.shift!;
      _selectedEmployeeId = shift.employeeId;
      _selectedDate = shift.startTime ?? DateTime.now();
      _startTime = TimeOfDay.fromDateTime(shift.startTime ?? DateTime.now());
      _endTime = TimeOfDay.fromDateTime(shift.endTime ?? DateTime.now());
      _locationController.text = shift.location ?? '';
      _notesController.text = shift.notes ?? '';
      _isPublished = shift.isPublished;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateTime = _combineDateAndTime(_selectedDate, _startTime);
      final endDateTime = _combineDateAndTime(_selectedDate, _endTime);

      // Validate times
      if (endDateTime.isBefore(startDateTime) ||
          endDateTime.isAtSameMomentAs(startDateTime)) {
        throw Exception('End time must be after start time');
      }

      if (_isEditMode) {
        // Update existing shift
        await _scheduleService.updateShift(
          shiftId: widget.shift!.id,
          employeeId: _selectedEmployeeId,
          startTime: startDateTime,
          endTime: endDateTime,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          location: _locationController.text.isNotEmpty
              ? _locationController.text
              : null,
          isPublished: _isPublished,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift updated successfully')),
          );
        }
      } else {
        // Create new shift
        await _scheduleService.createShift(
          employeeId: _selectedEmployeeId!,
          startTime: startDateTime,
          endTime: endDateTime,
          createdBy: widget.currentUserId,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          location: _locationController.text.isNotEmpty
              ? _locationController.text
              : null,
          isPublished: _isPublished,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shift created successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
        constraints: const BoxConstraints(maxWidth: 500),
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
                        _isEditMode ? 'Edit Shift' : 'Create Shift',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Employee Selection
                  DropdownButtonFormField<String>(
                    value: _selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Employee *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _employees.map((employee) {
                      return DropdownMenuItem<String>(
                        value: employee.id,
                        child: Text(employee.fullName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEmployeeId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an employee';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Selection
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start and End Time
                  Row(
                    children: [
                      // Start Time
                      Expanded(
                        child: InkWell(
                          onTap: _selectStartTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Time *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_startTime.format(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // End Time
                      Expanded(
                        child: InkWell(
                          onTap: _selectEndTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Time *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_endTime.format(context)),
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: ${_calculateDuration()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                      hintText: 'e.g., Main Office, Store #2',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                      hintText: 'Add any special instructions...',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Publish Checkbox
                  CheckboxListTile(
                    value: _isPublished,
                    onChanged: (value) {
                      setState(() {
                        _isPublished = value ?? false;
                      });
                    },
                    title: const Text('Publish to Employee'),
                    subtitle: const Text(
                      'Employee will be able to see this shift on their schedule',
                    ),
                    secondary: const Icon(Icons.visibility),
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
                            : Text(_isEditMode ? 'Update' : 'Create'),
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

  String _calculateDuration() {
    final start = _combineDateAndTime(_selectedDate, _startTime);
    final end = _combineDateAndTime(_selectedDate, _endTime);

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      return 'Invalid';
    }

    final duration = end.difference(start);
    final hours = duration.inMinutes / 60.0;
    return '${hours.toStringAsFixed(1)} hours';
  }
}
