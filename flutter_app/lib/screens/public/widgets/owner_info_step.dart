import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/validators.dart';

/// Step 2: Owner Information form fields
class OwnerInfoStep extends StatefulWidget {
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String jobTitle;
  final String hrName;
  final String hrEmail;
  final ValueChanged<String> onOwnerNameChanged;
  final ValueChanged<String> onOwnerEmailChanged;
  final ValueChanged<String> onOwnerPhoneChanged;
  final ValueChanged<String> onJobTitleChanged;
  final ValueChanged<String> onHrNameChanged;
  final ValueChanged<String> onHrEmailChanged;

  const OwnerInfoStep({
    Key? key,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.jobTitle,
    required this.hrName,
    required this.hrEmail,
    required this.onOwnerNameChanged,
    required this.onOwnerEmailChanged,
    required this.onOwnerPhoneChanged,
    required this.onJobTitleChanged,
    required this.onHrNameChanged,
    required this.onHrEmailChanged,
  }) : super(key: key);

  @override
  State<OwnerInfoStep> createState() => _OwnerInfoStepState();
}

class _OwnerInfoStepState extends State<OwnerInfoStep> {
  final _phoneController = TextEditingController();
  bool _showHrFields = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.ownerPhone;
    _phoneController.addListener(_formatPhoneNumber);
    // Show HR fields if already filled
    _showHrFields = widget.hrName.isNotEmpty || widget.hrEmail.isNotEmpty;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Formats phone number as user types
  void _formatPhoneNumber() {
    final text = _phoneController.text;
    final formatted = Validators.formatPhone(text);

    if (formatted != text) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    widget.onOwnerPhoneChanged(formatted);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Who will be the primary account owner?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 24),

        // Owner Full Name
        TextFormField(
          initialValue: widget.ownerName,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'First and Last Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) => Validators.name(value),
          onSaved: (value) => widget.onOwnerNameChanged(value ?? ''),
          textCapitalization: TextCapitalization.words,
        ),

        const SizedBox(height: 16),

        // Email Address
        TextFormField(
          initialValue: widget.ownerEmail,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'your.email@company.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          validator: (value) => Validators.email(value),
          onSaved: (value) => widget.onOwnerEmailChanged(value ?? ''),
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
        ),

        const SizedBox(height: 16),

        // Phone Number
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '(123) 456-7890',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          validator: (value) => Validators.phone(value),
          onSaved: (value) => widget.onOwnerPhoneChanged(value ?? ''),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9() -]')),
            LengthLimitingTextInputFormatter(14), // (123) 456-7890
          ],
        ),

        const SizedBox(height: 16),

        // Job Title (optional)
        TextFormField(
          initialValue: widget.jobTitle,
          decoration: const InputDecoration(
            labelText: 'Job Title (Optional)',
            hintText: 'Owner, Manager, CEO, etc.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.work),
          ),
          onSaved: (value) => widget.onJobTitleChanged(value ?? ''),
          textCapitalization: TextCapitalization.words,
        ),

        const SizedBox(height: 24),

        // Add HR Person toggle
        Row(
          children: [
            Expanded(
              child: Divider(color: Colors.grey.shade300),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showHrFields = !_showHrFields;
                    // Clear fields when hiding
                    if (!_showHrFields) {
                      widget.onHrNameChanged('');
                      widget.onHrEmailChanged('');
                    }
                  });
                },
                icon: Icon(_showHrFields ? Icons.remove : Icons.add),
                label: Text(_showHrFields
                    ? 'Remove HR Person'
                    : 'Add HR Person (Optional)'),
              ),
            ),
            Expanded(
              child: Divider(color: Colors.grey.shade300),
            ),
          ],
        ),

        // HR Person fields (conditional)
        if (_showHrFields) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.business_center, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'HR Person Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This person will also have admin access to manage employees and schedules.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: widget.hrName,
                  decoration: const InputDecoration(
                    labelText: 'HR Person Name (Optional)',
                    hintText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSaved: (value) => widget.onHrNameChanged(value ?? ''),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: widget.hrEmail,
                  decoration: const InputDecoration(
                    labelText: 'HR Person Email (Optional)',
                    hintText: 'hr@company.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    // Only validate if a value is provided
                    if (value != null && value.trim().isNotEmpty) {
                      return Validators.email(value);
                    }
                    return null;
                  },
                  onSaved: (value) => widget.onHrEmailChanged(value ?? ''),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Help text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.security,
                size: 20,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This information will be used to create your account and contact you about your registration.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
