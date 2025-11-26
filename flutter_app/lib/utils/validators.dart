/// Form validation utilities for registration
class Validators {
  /// Validates required text fields
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates email format
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validates US phone number format
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // Remove all non-digit characters
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }

    return null;
  }

  /// Formats phone number as (XXX) XXX-XXXX
  static String formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length >= 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, 10)}';
    } else if (digits.length >= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length >= 3) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else if (digits.isNotEmpty) {
      return '($digits';
    }

    return '';
  }

  /// Validates US ZIP code format
  static String? zipCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'ZIP code is required';
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 5) {
      return 'Please enter a valid 5-digit ZIP code';
    }

    return null;
  }

  /// Validates password strength
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Check for at least one uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Validates password confirmation matches
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Calculates password strength (0-4)
  /// 0: Very Weak, 1: Weak, 2: Fair, 3: Good, 4: Strong
  static int passwordStrength(String password) {
    if (password.isEmpty) return 0;

    int strength = 0;

    // Length check
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;

    // Character variety checks
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    // Normalize to 0-4 scale
    if (strength >= 6) return 4;
    if (strength >= 5) return 3;
    if (strength >= 4) return 2;
    if (strength >= 2) return 1;
    return 0;
  }

  /// Gets password strength label
  static String passwordStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Very Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Very Weak';
    }
  }

  /// Validates website URL format (optional field)
  static String? website(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    final urlRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}',
    );

    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid website URL';
    }

    return null;
  }

  /// Validates checkbox is checked
  static String? checkbox(bool? value, String message) {
    if (value == null || !value) {
      return message;
    }
    return null;
  }

  /// Validates business name
  static String? businessName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Business name is required';
    }

    if (value.trim().length < 2) {
      return 'Business name must be at least 2 characters';
    }

    return null;
  }

  /// Validates owner name
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }

    // Check for at least first and last name
    if (!value.trim().contains(' ')) {
      return 'Please enter your full name (first and last)';
    }

    return null;
  }

  /// Validates street address
  static String? streetAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Street address is required';
    }

    if (value.trim().length < 5) {
      return 'Please enter a complete street address';
    }

    return null;
  }

  /// Validates city name
  static String? city(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'City is required';
    }

    if (value.trim().length < 2) {
      return 'Please enter a valid city name';
    }

    return null;
  }

  /// Validates state selection
  static String? state(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'State is required';
    }

    return null;
  }

  /// Validates industry selection
  static String? industry(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Industry is required';
    }

    return null;
  }

  /// Validates employee count selection
  static String? employeeCount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Number of employees is required';
    }

    return null;
  }
}

/// US States list
class USStates {
  static const List<Map<String, String>> states = [
    {'code': 'AL', 'name': 'Alabama'},
    {'code': 'AK', 'name': 'Alaska'},
    {'code': 'AZ', 'name': 'Arizona'},
    {'code': 'AR', 'name': 'Arkansas'},
    {'code': 'CA', 'name': 'California'},
    {'code': 'CO', 'name': 'Colorado'},
    {'code': 'CT', 'name': 'Connecticut'},
    {'code': 'DE', 'name': 'Delaware'},
    {'code': 'FL', 'name': 'Florida'},
    {'code': 'GA', 'name': 'Georgia'},
    {'code': 'HI', 'name': 'Hawaii'},
    {'code': 'ID', 'name': 'Idaho'},
    {'code': 'IL', 'name': 'Illinois'},
    {'code': 'IN', 'name': 'Indiana'},
    {'code': 'IA', 'name': 'Iowa'},
    {'code': 'KS', 'name': 'Kansas'},
    {'code': 'KY', 'name': 'Kentucky'},
    {'code': 'LA', 'name': 'Louisiana'},
    {'code': 'ME', 'name': 'Maine'},
    {'code': 'MD', 'name': 'Maryland'},
    {'code': 'MA', 'name': 'Massachusetts'},
    {'code': 'MI', 'name': 'Michigan'},
    {'code': 'MN', 'name': 'Minnesota'},
    {'code': 'MS', 'name': 'Mississippi'},
    {'code': 'MO', 'name': 'Missouri'},
    {'code': 'MT', 'name': 'Montana'},
    {'code': 'NE', 'name': 'Nebraska'},
    {'code': 'NV', 'name': 'Nevada'},
    {'code': 'NH', 'name': 'New Hampshire'},
    {'code': 'NJ', 'name': 'New Jersey'},
    {'code': 'NM', 'name': 'New Mexico'},
    {'code': 'NY', 'name': 'New York'},
    {'code': 'NC', 'name': 'North Carolina'},
    {'code': 'ND', 'name': 'North Dakota'},
    {'code': 'OH', 'name': 'Ohio'},
    {'code': 'OK', 'name': 'Oklahoma'},
    {'code': 'OR', 'name': 'Oregon'},
    {'code': 'PA', 'name': 'Pennsylvania'},
    {'code': 'RI', 'name': 'Rhode Island'},
    {'code': 'SC', 'name': 'South Carolina'},
    {'code': 'SD', 'name': 'South Dakota'},
    {'code': 'TN', 'name': 'Tennessee'},
    {'code': 'TX', 'name': 'Texas'},
    {'code': 'UT', 'name': 'Utah'},
    {'code': 'VT', 'name': 'Vermont'},
    {'code': 'VA', 'name': 'Virginia'},
    {'code': 'WA', 'name': 'Washington'},
    {'code': 'WV', 'name': 'West Virginia'},
    {'code': 'WI', 'name': 'Wisconsin'},
    {'code': 'WY', 'name': 'Wyoming'},
  ];

  static List<String> get stateNames =>
      states.map((s) => s['name']!).toList();

  static List<String> get stateCodes =>
      states.map((s) => s['code']!).toList();
}
