import 'package:flutter/material.dart';
import '../../models/registration_request.dart';
import '../../services/registration_service.dart';
import '../../utils/validators.dart';
import 'widgets/business_info_step.dart';
import 'widgets/owner_info_step.dart';
import 'widgets/address_step.dart';
import 'widgets/account_setup_step.dart';
import 'register_success_page.dart';

/// Multi-step registration page for new businesses
class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _registrationService = RegistrationService();

  // Current step (0-3)
  int _currentStep = 0;

  // Loading state
  bool _isSubmitting = false;
  String? _errorMessage;

  // Form data
  // Step 1: Business Information
  String _businessName = '';
  String _industry = '';
  String _employeeCount = '';
  String _website = '';

  // Step 2: Owner Information
  String _ownerName = '';
  String _ownerEmail = '';
  String _ownerPhone = '';
  String _jobTitle = '';
  String _hrName = '';
  String _hrEmail = '';

  // Step 3: Business Address
  String _street = '';
  String _city = '';
  String _state = '';
  String _zip = '';
  String _timezone = 'America/New_York'; // Default timezone

  // Step 4: Account Setup
  String _password = '';
  String _confirmPassword = '';
  bool _agreeToTerms = false;
  bool _agreeToPrivacy = false;

  @override
  void initState() {
    super.initState();
    _detectTimezone();
  }

  /// Attempts to detect user's timezone
  void _detectTimezone() {
    // In a real app, you would use a package like 'timezone' or 'flutter_timezone'
    // For now, we'll use a default
    setState(() {
      _timezone = 'America/New_York';
    });
  }

  /// Advances to next step if current step is valid
  void _nextStep() {
    if (_validateCurrentStep()) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });
    }
  }

  /// Goes back to previous step
  void _previousStep() {
    setState(() {
      _currentStep--;
      _errorMessage = null;
    });
  }

  /// Validates the current step's form fields
  bool _validateCurrentStep() {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return false;
    }

    _formKey.currentState!.save();

    // Additional validation for Step 4
    if (_currentStep == 3) {
      if (!_agreeToTerms) {
        setState(() {
          _errorMessage = 'You must agree to the Terms of Service';
        });
        return false;
      }
      if (!_agreeToPrivacy) {
        setState(() {
          _errorMessage = 'You must agree to the Privacy Policy';
        });
        return false;
      }
    }

    return true;
  }

  /// Submits the registration request
  Future<void> _submitRegistration() async {
    if (!_validateCurrentStep()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Create registration request object
      final request = RegistrationRequest(
        status: 'pending',
        businessName: _businessName,
        industry: _industry,
        numberOfEmployees: EmployeeCountOptions.getMaxEmployees(_employeeCount),
        website: _website.isNotEmpty ? _website : null,
        ownerName: _ownerName,
        ownerEmail: _ownerEmail,
        ownerPhone: _ownerPhone,
        jobTitle: _jobTitle.isNotEmpty ? _jobTitle : null,
        address: Address(
          street: _street,
          city: _city,
          state: _state,
          zip: _zip,
        ),
        timezone: _timezone,
        password: _password,
        submittedAt: DateTime.now(),
      );

      // Normalize and validate data
      final normalizedRequest = _registrationService.normalizeRegistrationData(request);
      final validationError = _registrationService.validateRegistrationData(normalizedRequest);

      if (validationError != null) {
        setState(() {
          _errorMessage = validationError;
          _isSubmitting = false;
        });
        return;
      }

      // Check if email already registered
      final emailExists = await _registrationService.isEmailAlreadyRegistered(_ownerEmail);
      if (emailExists) {
        setState(() {
          _errorMessage = 'This email address is already registered. Please use a different email or contact support.';
          _isSubmitting = false;
        });
        return;
      }

      // Submit registration
      final requestId = await _registrationService.submitRegistration(normalizedRequest);

      // Navigate to success page
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RegisterSuccessPage(
            businessName: _businessName,
            ownerEmail: _ownerEmail,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit registration: ${e.toString()}';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register for ChronoWorks'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress indicator
                _buildProgressIndicator(),
                const SizedBox(height: 32),

                // Form
                Form(
                  key: _formKey,
                  child: _buildCurrentStep(),
                ),

                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),

                if (_errorMessage != null) const SizedBox(height: 16),

                // Navigation buttons
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the step progress indicator
  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
          children: List.generate(4, (index) {
            final isCompleted = index < _currentStep;
            final isCurrent = index == _currentStep;

            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index < 3 ? 8 : 0,
                ),
                decoration: BoxDecoration(
                  color: isCompleted || isCurrent
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          _getStepTitle(_currentStep),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${_currentStep + 1} of 4',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }

  /// Gets the title for each step
  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Business Information';
      case 1:
        return 'Owner Information';
      case 2:
        return 'Business Address';
      case 3:
        return 'Account Setup';
      default:
        return '';
    }
  }

  /// Builds the form for the current step
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return BusinessInfoStep(
          businessName: _businessName,
          industry: _industry,
          employeeCount: _employeeCount,
          website: _website,
          onBusinessNameChanged: (value) => _businessName = value,
          onIndustryChanged: (value) => _industry = value,
          onEmployeeCountChanged: (value) => _employeeCount = value,
          onWebsiteChanged: (value) => _website = value,
        );
      case 1:
        return OwnerInfoStep(
          ownerName: _ownerName,
          ownerEmail: _ownerEmail,
          ownerPhone: _ownerPhone,
          jobTitle: _jobTitle,
          hrName: _hrName,
          hrEmail: _hrEmail,
          onOwnerNameChanged: (value) => _ownerName = value,
          onOwnerEmailChanged: (value) => _ownerEmail = value,
          onOwnerPhoneChanged: (value) => _ownerPhone = value,
          onJobTitleChanged: (value) => _jobTitle = value,
          onHrNameChanged: (value) => _hrName = value,
          onHrEmailChanged: (value) => _hrEmail = value,
        );
      case 2:
        return AddressStep(
          street: _street,
          city: _city,
          state: _state,
          zip: _zip,
          timezone: _timezone,
          onStreetChanged: (value) => _street = value,
          onCityChanged: (value) => _city = value,
          onStateChanged: (value) => _state = value,
          onZipChanged: (value) => _zip = value,
          onTimezoneChanged: (value) => _timezone = value,
        );
      case 3:
        return AccountSetupStep(
          password: _password,
          confirmPassword: _confirmPassword,
          agreeToTerms: _agreeToTerms,
          agreeToPrivacy: _agreeToPrivacy,
          onPasswordChanged: (value) => _password = value,
          onConfirmPasswordChanged: (value) => _confirmPassword = value,
          onAgreeToTermsChanged: (value) => setState(() => _agreeToTerms = value ?? false),
          onAgreeToPrivacyChanged: (value) => setState(() => _agreeToPrivacy = value ?? false),
        );
      default:
        return Container();
    }
  }

  /// Builds the navigation buttons (Back/Next/Submit)
  Widget _buildNavigationButtons() {
    return Row(
      children: [
        // Back button (shown after first step)
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _previousStep,
              child: const Text('Back'),
            ),
          ),

        if (_currentStep > 0) const SizedBox(width: 16),

        // Next/Submit button
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : () {
              if (_currentStep < 3) {
                _nextStep();
              } else {
                _submitRegistration();
              }
            },
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(_currentStep < 3 ? 'Next' : 'Submit Registration'),
          ),
        ),
      ],
    );
  }
}
