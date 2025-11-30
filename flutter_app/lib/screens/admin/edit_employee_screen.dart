import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/employee_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/constants.dart';

class EditEmployeeScreen extends StatefulWidget {
  final UserModel employee;

  const EditEmployeeScreen({
    super.key,
    required this.employee,
  });

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final EmployeeService _employeeService = EmployeeService();

  // Controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _hourlyRateController;

  // State
  late String _selectedRole;
  late String _selectedEmploymentType;
  String? _selectedManagerId;
  List<UserModel> _managers = [];
  bool _isLoading = false;
  late bool _isKeyholder;
  late bool _isActive;
  DateTime? _hireDate;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current employee data
    _firstNameController = TextEditingController(text: widget.employee.firstName);
    _lastNameController = TextEditingController(text: widget.employee.lastName);
    _phoneController = TextEditingController(text: widget.employee.phoneNumber ?? '');
    _hourlyRateController = TextEditingController(text: widget.employee.hourlyRate.toString());

    // Initialize state with current employee data
    _selectedRole = widget.employee.role;
    _selectedEmploymentType = widget.employee.employmentType;
    _selectedManagerId = widget.employee.managerId;
    _isKeyholder = widget.employee.isKeyholder;
    _isActive = widget.employee.isActive;
    _hireDate = widget.employee.hireDate;

    _loadManagers();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _loadManagers() async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId ?? '';

    if (companyId.isEmpty) return;

    final managers = await _employeeService.getManagers(companyId);
    setState(() {
      _managers = managers;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated employee model
      final updatedEmployee = widget.employee.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        role: _selectedRole,
        employmentType: _selectedEmploymentType,
        hourlyRate: double.tryParse(_hourlyRateController.text) ?? 0.0,
        managerId: _selectedManagerId,
        isKeyholder: _isKeyholder,
        isActive: _isActive,
        hireDate: _hireDate,
        updatedAt: DateTime.now(),
      );

      await _employeeService.updateEmployee(updatedEmployee);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedEmployee.fullName} updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.employee.fullName}'),
        actions: [
          // Status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Chip(
                label: Text(
                  _isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: _isActive ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Info Card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              widget.employee.firstName[0].toUpperCase() +
                                  widget.employee.lastName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.employee.fullName,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.employee.email,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Member since ${_formatDate(widget.employee.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information Section
              Text(
                'Personal Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // First Name
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  hintText: 'Enter first name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  hintText: 'Enter last name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (Read-only)
              TextFormField(
                initialValue: widget.employee.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Email cannot be changed',
                  prefixIcon: Icon(Icons.email),
                  helperText: 'Email address cannot be modified',
                ),
              ),
              const SizedBox(height: 16),

              // Phone (Optional)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'Enter phone number',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 24),

              // Employment Details Section
              Text(
                'Employment Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Role Selection
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: const [
                  DropdownMenuItem(
                    value: UserRoles.employee,
                    child: Text('Employee'),
                  ),
                  DropdownMenuItem(
                    value: UserRoles.manager,
                    child: Text('Manager'),
                  ),
                  DropdownMenuItem(
                    value: UserRoles.admin,
                    child: Text('Admin'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Employment Type
              DropdownButtonFormField<String>(
                value: _selectedEmploymentType,
                decoration: const InputDecoration(
                  labelText: 'Employment Type *',
                  prefixIcon: Icon(Icons.work),
                ),
                items: const [
                  DropdownMenuItem(
                    value: EmploymentTypes.fullTime,
                    child: Text('Full-Time'),
                  ),
                  DropdownMenuItem(
                    value: EmploymentTypes.partTime,
                    child: Text('Part-Time'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedEmploymentType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Hourly Rate
              TextFormField(
                controller: _hourlyRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hourly Rate *',
                  hintText: 'Enter hourly rate',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: '/hour',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter hourly rate';
                  }
                  final rate = double.tryParse(value);
                  if (rate == null || rate < 0) {
                    return 'Please enter a valid rate';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Hire Date
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _hireDate ?? widget.employee.createdAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: 'Select Hire Date',
                  );
                  if (picked != null) {
                    setState(() {
                      _hireDate = picked;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Hire Date',
                    hintText: 'Select hire date for PTO calculations',
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _hireDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _hireDate = null;
                              });
                            },
                          )
                        : null,
                  ),
                  child: Text(
                    _hireDate != null
                        ? DateFormat('MMM d, yyyy').format(_hireDate!)
                        : 'Not set (using account creation date)',
                    style: TextStyle(
                      color: _hireDate != null ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Hire date is used for PTO eligibility calculations. If not set, the account creation date will be used.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Manager Selection (if employee role)
              if (_selectedRole == UserRoles.employee && _managers.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedManagerId,
                  decoration: const InputDecoration(
                    labelText: 'Assign Manager (Optional)',
                    prefixIcon: Icon(Icons.supervisor_account),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Manager'),
                    ),
                    ..._managers.map((manager) {
                      return DropdownMenuItem(
                        value: manager.id,
                        child: Text(manager.fullName),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedManagerId = value;
                    });
                  },
                ),
              if (_selectedRole == UserRoles.employee && _managers.isNotEmpty)
                const SizedBox(height: 16),

              // Keyholder Checkbox
              Card(
                child: CheckboxListTile(
                  title: const Text('Keyholder'),
                  subtitle: const Text(
                    'This employee has building key access and can open/close',
                  ),
                  value: _isKeyholder,
                  onChanged: (value) {
                    setState(() {
                      _isKeyholder = value ?? false;
                    });
                  },
                  secondary: const Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 16),

              // Active Status Checkbox
              Card(
                color: _isActive
                    ? Colors.green.shade50
                    : Colors.grey.shade200,
                child: CheckboxListTile(
                  title: const Text('Active Employee'),
                  subtitle: Text(
                    _isActive
                        ? 'Employee can log in and access the system'
                        : 'Employee is deactivated and cannot log in',
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value ?? true;
                    });
                  },
                  secondary: Icon(
                    _isActive ? Icons.check_circle : Icons.block,
                    color: _isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
