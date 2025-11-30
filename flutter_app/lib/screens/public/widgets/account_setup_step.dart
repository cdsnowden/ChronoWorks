import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/validators.dart';

/// Step 4: Account Setup form fields (password and terms)
class AccountSetupStep extends StatefulWidget {
  final String password;
  final String confirmPassword;
  final bool agreeToTerms;
  final bool agreeToPrivacy;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onConfirmPasswordChanged;
  final ValueChanged<bool?> onAgreeToTermsChanged;
  final ValueChanged<bool?> onAgreeToPrivacyChanged;

  const AccountSetupStep({
    Key? key,
    required this.password,
    required this.confirmPassword,
    required this.agreeToTerms,
    required this.agreeToPrivacy,
    required this.onPasswordChanged,
    required this.onConfirmPasswordChanged,
    required this.onAgreeToTermsChanged,
    required this.onAgreeToPrivacyChanged,
  }) : super(key: key);

  @override
  State<AccountSetupStep> createState() => _AccountSetupStepState();
}

class _AccountSetupStepState extends State<AccountSetupStep> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _passwordStrength = 0;

  // Privacy Policy URL
  static const String _privacyPolicyUrl = 'https://chronoworks.co/privacy-policy.html';

  void _updatePasswordStrength(String password) {
    setState(() {
      _passwordStrength = Validators.passwordStrength(password);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create your account credentials',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 24),

        // Password
        TextFormField(
          initialValue: widget.password,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Minimum 8 characters',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          validator: (value) => Validators.password(value),
          onChanged: (value) {
            widget.onPasswordChanged(value);
            _updatePasswordStrength(value);
          },
          onSaved: (value) => widget.onPasswordChanged(value ?? ''),
          obscureText: _obscurePassword,
        ),

        const SizedBox(height: 8),

        // Password strength indicator
        if (widget.password.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index < 3 ? 4 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: index < _passwordStrength
                            ? _getStrengthColor(_passwordStrength)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                'Password Strength: ${Validators.passwordStrengthLabel(_passwordStrength)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _getStrengthColor(_passwordStrength),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Confirm Password
        TextFormField(
          initialValue: widget.confirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          validator: (value) =>
              Validators.confirmPassword(value, widget.password),
          onSaved: (value) => widget.onConfirmPasswordChanged(value ?? ''),
          obscureText: _obscureConfirmPassword,
        ),

        const SizedBox(height: 24),

        // Password requirements
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
              Text(
                'Password Requirements:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildRequirement(
                  'At least 8 characters', widget.password.length >= 8),
              _buildRequirement('One uppercase letter',
                  widget.password.contains(RegExp(r'[A-Z]'))),
              _buildRequirement('One lowercase letter',
                  widget.password.contains(RegExp(r'[a-z]'))),
              _buildRequirement(
                  'One number', widget.password.contains(RegExp(r'[0-9]'))),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Terms of Service checkbox
        CheckboxListTile(
          value: widget.agreeToTerms,
          onChanged: widget.onAgreeToTermsChanged,
          title: Row(
            children: [
              const Text('I agree to the '),
              InkWell(
                onTap: () {
                  // Open terms of service
                  _showTermsDialog(context);
                },
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        // Privacy Policy checkbox
        CheckboxListTile(
          value: widget.agreeToPrivacy,
          onChanged: widget.onAgreeToPrivacyChanged,
          title: Row(
            children: [
              const Text('I agree to the '),
              InkWell(
                onTap: () {
                  // Open privacy policy
                  _openPrivacyPolicy();
                },
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 16),

        // Final help text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: Colors.purple.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'By submitting, your registration will be reviewed by our team. You\'ll receive an email once approved.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a password requirement item with checkmark
  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: met ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Gets color based on password strength
  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Shows Terms of Service dialog
  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'Terms of Service content goes here.\n\n'
            'This is a placeholder. In production, you would include your actual Terms of Service text.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Opens Privacy Policy in browser
  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse(_privacyPolicyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // If we can't launch the URL, show an error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open privacy policy. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
