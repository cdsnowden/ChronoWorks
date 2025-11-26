import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../services/employee_service.dart';
import '../../routes.dart';
import '../../utils/constants.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({Key? key}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeService = EmployeeService();

  // Controllers for missing fields
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDateOfBirth;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      // Pre-fill existing data if available
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneController.text = user.phoneNumber!;
      }
      if (user.address != null && user.address!.isNotEmpty) {
        _addressController.text = user.address!;
      }
      if (user.dateOfBirth != null) {
        _selectedDateOfBirth = user.dateOfBirth;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Check which fields are missing
  List<String> _getMissingFields(UserModel user) {
    final missing = <String>[];

    if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
      missing.add('Phone Number');
    }
    if (user.address == null || user.address!.isEmpty) {
      missing.add('Address');
    }
    if (user.dateOfBirth == null) {
      missing.add('Date of Birth');
    }

    return missing;
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select Your Date of Birth',
    );

    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage = 'User not found. Please log in again.';
      });
      return;
    }

    // Validate that all required fields are filled
    if (_phoneController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Phone number is required.';
      });
      return;
    }

    if (_addressController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Address is required.';
      });
      return;
    }

    if (_selectedDateOfBirth == null) {
      setState(() {
        _errorMessage = 'Date of birth is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Update user with the completed profile information
      final updatedUser = user.copyWith(
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        updatedAt: DateTime.now(),
      );

      await _employeeService.updateEmployee(updatedUser);

      // Refresh user data in the provider
      await authProvider.refreshUser();

      if (!mounted) return;

      // Navigate to employee dashboard
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.employeeDashboard,
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Complete Profile'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Text('Please log in to complete your profile.'),
        ),
      );
    }

    final missingFields = _getMissingFields(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false, // Prevent back navigation
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).primaryColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            'Profile Completion Required',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome ${user.firstName}! To get started, please complete your profile by providing the following information:',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ...missingFields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16),
                              const SizedBox(width: 8),
                              Text('• $field'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '(555) 123-4567',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Home Address *',
                    hintText: '123 Main St, City, State ZIP',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a complete address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Date of Birth
                InkWell(
                  onTap: _selectDateOfBirth,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth *',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                      errorText: _selectedDateOfBirth == null
                          ? 'Date of birth is required'
                          : null,
                    ),
                    child: Text(
                      _selectedDateOfBirth != null
                          ? DateFormat('MMMM dd, yyyy').format(_selectedDateOfBirth!)
                          : 'Select your date of birth',
                      style: TextStyle(
                        color: _selectedDateOfBirth != null
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Submit button
                ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Complete Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // Info text
                const Text(
                  '* All fields are required to access the application',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
