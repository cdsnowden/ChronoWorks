import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_plan.dart';
import '../../models/registration_request.dart';
import '../../services/registration_service.dart';
import '../../routes.dart';
import 'plan_selection_screen.dart';

/// Company signup form with integrated plan selection
class CompanySignupFormScreen extends StatefulWidget {
  final SubscriptionPlan? selectedPlan;
  final String? billingCycle;

  const CompanySignupFormScreen({
    super.key,
    this.selectedPlan,
    this.billingCycle,
  });

  @override
  State<CompanySignupFormScreen> createState() => _CompanySignupFormScreenState();
}

class _CompanySignupFormScreenState extends State<CompanySignupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final RegistrationService _registrationService = RegistrationService();

  // Selected plan state
  SubscriptionPlan? _selectedPlan;
  String? _selectedBillingCycle;

  // Form controllers
  final _companyNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Dropdown selections
  String? _selectedIndustry;
  String? _selectedEmployeeRange;
  String? _selectedPayrollService;
  String? _selectedPayPeriod;
  String? _selectedWorkWeekStart;
  String? _selectedState;
  String? _selectedTimezone;

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    // Initialize with passed values if any
    _selectedPlan = widget.selectedPlan;
    _selectedBillingCycle = widget.billingCycle;
  }

  Future<void> _selectPlan() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const PlanSelectionScreen(isSelectionMode: true),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedPlan = result['plan'] as SubscriptionPlan;
        _selectedBillingCycle = result['billingCycle'] as String;
      });
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _jobTitleController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // Check if plan is selected
    if (_selectedPlan == null || _selectedBillingCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subscription plan before submitting'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final employeeCount = EmployeeCountOptions.getMaxEmployees(_selectedEmployeeRange ?? '1-10');

      final request = RegistrationRequest(
        status: 'pending',
        businessName: _companyNameController.text.trim(),
        industry: _selectedIndustry!,
        numberOfEmployees: employeeCount,
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
        payrollService: _selectedPayrollService,
        payPeriodType: _selectedPayPeriod,
        workWeekStartDay: _selectedWorkWeekStart,
        selectedPlanId: _selectedPlan!.planId,
        billingCycle: _selectedBillingCycle!,
        ownerName: _adminNameController.text.trim(),
        ownerEmail: _adminEmailController.text.trim(),
        ownerPhone: _adminPhoneController.text.trim(),
        jobTitle: _jobTitleController.text.trim().isEmpty ? null : _jobTitleController.text.trim(),
        address: Address(
          street: _streetController.text.trim(),
          city: _cityController.text.trim(),
          state: _selectedState!,
          zip: _zipController.text.trim(),
        ),
        timezone: _selectedTimezone!,
        password: _passwordController.text,
      );

      // Normalize and validate
      final normalizedRequest = _registrationService.normalizeRegistrationData(request);
      final validationError = _registrationService.validateRegistrationData(normalizedRequest);

      if (validationError != null) {
        throw Exception(validationError);
      }

      // Submit registration
      await _registrationService.submitRegistration(normalizedRequest);

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 64),
          title: const Text('Registration Submitted!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thank you for choosing ChronoWorks!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0D47A1), width: 1),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.schedule, size: 20, color: Color(0xFF0D47A1)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'What happens next?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Our team will review your registration\n'
                      '2. You\'ll be assigned a dedicated Account Manager\n'
                      '3. You\'ll receive approval within 24-48 hours\n'
                      '4. Start your 60-day free trial immediately',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We\'ll send updates to:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _adminEmailController.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false
                ); // Return to login
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Information'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Selected plan banner
          _buildSelectedPlanBanner(),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Company Information'),
                    _buildCompanySection(),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Administrator Account'),
                    _buildAdminSection(),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Business Address'),
                    _buildAddressSection(),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Payroll & Scheduling'),
                    _buildPayrollSection(),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Create Password'),
                    _buildPasswordSection(),
                    const SizedBox(height: 40),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Submit Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPlanBanner() {
    final bool hasPlan = _selectedPlan != null && _selectedBillingCycle != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPlan ? const Color(0xFF0D47A1) : const Color(0xFF2E7D32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: hasPlan ? _buildPlanSelected() : _buildNoPlanSelected(),
    );
  }

  Widget _buildPlanSelected() {
    final price = _selectedBillingCycle == 'yearly'
        ? _selectedPlan!.priceYearly
        : _selectedPlan!.priceMonthly;
    final period = _selectedBillingCycle == 'yearly' ? 'year' : 'month';

    return Row(
      children: [
        const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedPlan!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                price == 0 ? 'Free' : '\$${price.toStringAsFixed(2)}/$period',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _selectPlan,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
          child: const Text('Change Plan'),
        ),
      ],
    );
  }

  Widget _buildNoPlanSelected() {
    return InkWell(
      onTap: _selectPlan,
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Plan Selected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tap to choose your subscription plan',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _selectPlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Select Plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1),
        ),
      ),
    );
  }

  Widget _buildCompanySection() {
    return Column(
      children: [
        TextFormField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Company Name *',
            hintText: 'e.g., Acme Corporation',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Company name is required';
            }
            if (value.trim().length < 2) {
              return 'Company name must be at least 2 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _selectedIndustry,
          decoration: const InputDecoration(
            labelText: 'Industry *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: IndustryOptions.industries.map((industry) {
            return DropdownMenuItem(value: industry, child: Text(industry));
          }).toList(),
          onChanged: (value) => setState(() => _selectedIndustry = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select an industry';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _selectedEmployeeRange,
          decoration: const InputDecoration(
            labelText: 'Number of Employees *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.people),
          ),
          items: EmployeeCountOptions.ranges.map((range) {
            return DropdownMenuItem(value: range, child: Text(range));
          }).toList(),
          onChanged: (value) => setState(() => _selectedEmployeeRange = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select employee count';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _websiteController,
          decoration: const InputDecoration(
            labelText: 'Website (Optional)',
            hintText: 'https://www.example.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.language),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _taxIdController,
          decoration: const InputDecoration(
            labelText: 'Tax ID / EIN (Optional)',
            hintText: 'XX-XXXXXXX',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminSection() {
    return Column(
      children: [
        TextFormField(
          controller: _adminNameController,
          decoration: const InputDecoration(
            labelText: 'Administrator Name *',
            hintText: 'Full Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Administrator name is required';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _adminEmailController,
          decoration: const InputDecoration(
            labelText: 'Email Address *',
            hintText: 'admin@company.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email is required';
            }
            final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
            if (!emailRegex.hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _adminPhoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            hintText: '(555) 123-4567',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9()\-\s]')),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Phone number is required';
            }
            final digits = value.replaceAll(RegExp(r'\D'), '');
            if (digits.length != 10) {
              return 'Please enter a 10-digit phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _jobTitleController,
          decoration: const InputDecoration(
            labelText: 'Job Title (Optional)',
            hintText: 'e.g., HR Manager, Owner',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.work),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      children: [
        TextFormField(
          controller: _streetController,
          decoration: const InputDecoration(
            labelText: 'Street Address *',
            hintText: '123 Main St',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Street address is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'City is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'State *',
                  border: OutlineInputBorder(),
                ),
                items: _usStates.map((state) {
                  return DropdownMenuItem(value: state, child: Text(state));
                }).toList(),
                onChanged: (value) => setState(() => _selectedState = value),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'State required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _zipController,
          decoration: const InputDecoration(
            labelText: 'ZIP Code *',
            hintText: '12345',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'ZIP code is required';
            }
            if (value.length != 5) {
              return 'ZIP code must be 5 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _selectedTimezone,
          decoration: const InputDecoration(
            labelText: 'Timezone *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.access_time),
          ),
          items: _usTimezones.map((tz) {
            return DropdownMenuItem(value: tz, child: Text(tz));
          }).toList(),
          onChanged: (value) => setState(() => _selectedTimezone = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a timezone';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPayrollSection() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedPayrollService,
          decoration: const InputDecoration(
            labelText: 'Payroll Service (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_balance),
          ),
          items: PayrollServiceOptions.services.map((service) {
            return DropdownMenuItem(value: service, child: Text(service));
          }).toList(),
          onChanged: (value) => setState(() => _selectedPayrollService = value),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _selectedPayPeriod,
          decoration: const InputDecoration(
            labelText: 'Pay Period (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
          ),
          items: PayPeriodOptions.types.map((type) {
            return DropdownMenuItem(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) => setState(() => _selectedPayPeriod = value),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _selectedWorkWeekStart,
          decoration: const InputDecoration(
            labelText: 'Work Week Starts On (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.event),
          ),
          items: WorkWeekStartOptions.days.map((day) {
            return DropdownMenuItem(value: day, child: Text(day));
          }).toList(),
          onChanged: (value) => setState(() => _selectedWorkWeekStart = value),
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      children: [
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password *',
            hintText: 'Minimum 8 characters',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            if (!value.contains(RegExp(r'[A-Z]'))) {
              return 'Password must contain at least one uppercase letter';
            }
            if (!value.contains(RegExp(r'[a-z]'))) {
              return 'Password must contain at least one lowercase letter';
            }
            if (!value.contains(RegExp(r'[0-9]'))) {
              return 'Password must contain at least one number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password *',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0D47A1), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 20, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Password must be at least 8 characters and contain uppercase, lowercase, and numbers.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // US States list
  static const List<String> _usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
  ];

  // US Timezones
  static const List<String> _usTimezones = [
    'America/New_York (Eastern)',
    'America/Chicago (Central)',
    'America/Denver (Mountain)',
    'America/Phoenix (Mountain - No DST)',
    'America/Los_Angeles (Pacific)',
    'America/Anchorage (Alaska)',
    'Pacific/Honolulu (Hawaii)',
  ];
}
