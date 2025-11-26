import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/validators.dart';

/// Step 3: Business Address form fields
class AddressStep extends StatelessWidget {
  final String street;
  final String city;
  final String state;
  final String zip;
  final String timezone;
  final ValueChanged<String> onStreetChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onStateChanged;
  final ValueChanged<String> onZipChanged;
  final ValueChanged<String> onTimezoneChanged;

  const AddressStep({
    Key? key,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.timezone,
    required this.onStreetChanged,
    required this.onCityChanged,
    required this.onStateChanged,
    required this.onZipChanged,
    required this.onTimezoneChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Where is your business located?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 24),

        // Street Address
        TextFormField(
          initialValue: street,
          decoration: const InputDecoration(
            labelText: 'Street Address',
            hintText: '123 Main Street',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
          validator: (value) => Validators.streetAddress(value),
          onSaved: (value) => onStreetChanged(value ?? ''),
          textCapitalization: TextCapitalization.words,
        ),

        const SizedBox(height: 16),

        // City
        TextFormField(
          initialValue: city,
          decoration: const InputDecoration(
            labelText: 'City',
            hintText: 'Enter city name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
          ),
          validator: (value) => Validators.city(value),
          onSaved: (value) => onCityChanged(value ?? ''),
          textCapitalization: TextCapitalization.words,
        ),

        const SizedBox(height: 16),

        // State and ZIP in a row
        Row(
          children: [
            // State dropdown
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: state.isEmpty ? null : state,
                decoration: const InputDecoration(
                  labelText: 'State',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map),
                ),
                items: USStates.stateNames.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                validator: (value) => Validators.state(value),
                onChanged: (value) => onStateChanged(value ?? ''),
                onSaved: (value) => onStateChanged(value ?? ''),
              ),
            ),

            const SizedBox(width: 16),

            // ZIP Code
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: zip,
                decoration: const InputDecoration(
                  labelText: 'ZIP',
                  hintText: '12345',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => Validators.zipCode(value),
                onSaved: (value) => onZipChanged(value ?? ''),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Timezone dropdown
        DropdownButtonFormField<String>(
          value: timezone.isEmpty ? 'America/New_York' : timezone,
          decoration: const InputDecoration(
            labelText: 'Timezone',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.schedule),
          ),
          items: _getTimezones().map((Map<String, String> tz) {
            return DropdownMenuItem<String>(
              value: tz['value'],
              child: Text(tz['label']!),
            );
          }).toList(),
          onChanged: (value) => onTimezoneChanged(value ?? 'America/New_York'),
          onSaved: (value) => onTimezoneChanged(value ?? 'America/New_York'),
        ),

        const SizedBox(height: 16),

        // Help text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.access_time,
                size: 20,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your timezone is important for accurate time tracking and scheduling.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Returns list of common US timezones
  List<Map<String, String>> _getTimezones() {
    return [
      {'value': 'America/New_York', 'label': 'Eastern Time (ET)'},
      {'value': 'America/Chicago', 'label': 'Central Time (CT)'},
      {'value': 'America/Denver', 'label': 'Mountain Time (MT)'},
      {'value': 'America/Phoenix', 'label': 'Arizona (MST)'},
      {'value': 'America/Los_Angeles', 'label': 'Pacific Time (PT)'},
      {'value': 'America/Anchorage', 'label': 'Alaska Time (AKT)'},
      {'value': 'Pacific/Honolulu', 'label': 'Hawaii Time (HST)'},
    ];
  }
}
