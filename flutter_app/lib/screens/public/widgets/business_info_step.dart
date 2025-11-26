import 'package:flutter/material.dart';
import '../../../models/registration_request.dart';
import '../../../utils/validators.dart';

/// Step 1: Business Information form fields
class BusinessInfoStep extends StatelessWidget {
  final String businessName;
  final String industry;
  final String employeeCount;
  final String website;
  final ValueChanged<String> onBusinessNameChanged;
  final ValueChanged<String> onIndustryChanged;
  final ValueChanged<String> onEmployeeCountChanged;
  final ValueChanged<String> onWebsiteChanged;

  const BusinessInfoStep({
    Key? key,
    required this.businessName,
    required this.industry,
    required this.employeeCount,
    required this.website,
    required this.onBusinessNameChanged,
    required this.onIndustryChanged,
    required this.onEmployeeCountChanged,
    required this.onWebsiteChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tell us about your business',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 24),

        // Business Name
        TextFormField(
          initialValue: businessName,
          decoration: const InputDecoration(
            labelText: 'Business Name',
            hintText: 'Enter your business name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          validator: (value) => Validators.businessName(value),
          onSaved: (value) => onBusinessNameChanged(value ?? ''),
          textCapitalization: TextCapitalization.words,
        ),

        const SizedBox(height: 16),

        // Industry dropdown
        DropdownButtonFormField<String>(
          value: industry.isEmpty ? null : industry,
          decoration: const InputDecoration(
            labelText: 'Industry',
            hintText: 'Select your industry',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: IndustryOptions.industries.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          validator: (value) => Validators.industry(value),
          onChanged: (value) => onIndustryChanged(value ?? ''),
          onSaved: (value) => onIndustryChanged(value ?? ''),
        ),

        const SizedBox(height: 16),

        // Employee Count dropdown
        DropdownButtonFormField<String>(
          value: employeeCount.isEmpty ? null : employeeCount,
          decoration: const InputDecoration(
            labelText: 'Number of Employees',
            hintText: 'Select employee count',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.people),
          ),
          items: EmployeeCountOptions.ranges.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          validator: (value) => Validators.employeeCount(value),
          onChanged: (value) => onEmployeeCountChanged(value ?? ''),
          onSaved: (value) => onEmployeeCountChanged(value ?? ''),
        ),

        const SizedBox(height: 16),

        // Website (optional)
        TextFormField(
          initialValue: website,
          decoration: const InputDecoration(
            labelText: 'Website (Optional)',
            hintText: 'https://www.yourcompany.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.language),
          ),
          validator: (value) => Validators.website(value),
          onSaved: (value) => onWebsiteChanged(value ?? ''),
          keyboardType: TextInputType.url,
        ),

        const SizedBox(height: 16),

        // Help text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This information helps us understand your business needs and recommend the right plan for you.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade900,
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
