import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a business registration request
class RegistrationRequest {
  final String? requestId;
  final String status; // 'pending', 'approved', 'rejected'

  // Business Information
  final String businessName;
  final String industry;
  final int numberOfEmployees;
  final String? website;
  final String? taxId; // EIN for payroll integration
  final String? payrollService; // e.g., "ADP", "Paychex", "Gusto", "QuickBooks", etc.
  final String? payPeriodType; // "weekly", "bi-weekly", "semi-monthly", "monthly"
  final String? workWeekStartDay; // "Sunday", "Monday", etc.

  // Subscription Information
  final String? selectedPlanId;
  final String? billingCycle; // "monthly" or "yearly"

  // Owner Information
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String? jobTitle;

  // HR Person (Optional)
  final String? hrName;
  final String? hrEmail;

  // Address
  final Address address;
  final String timezone;

  // Password (only used during submission, not stored in Firestore)
  final String? password;

  // Metadata
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? companyId;

  RegistrationRequest({
    this.requestId,
    required this.status,
    required this.businessName,
    required this.industry,
    required this.numberOfEmployees,
    this.website,
    this.taxId,
    this.payrollService,
    this.payPeriodType,
    this.workWeekStartDay,
    this.selectedPlanId,
    this.billingCycle,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    this.jobTitle,
    this.hrName,
    this.hrEmail,
    required this.address,
    required this.timezone,
    this.password,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.companyId,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'businessName': businessName,
      'industry': industry,
      'numberOfEmployees': numberOfEmployees,
      if (website != null) 'website': website,
      if (taxId != null) 'taxId': taxId,
      if (payrollService != null) 'payrollService': payrollService,
      if (payPeriodType != null) 'payPeriodType': payPeriodType,
      if (workWeekStartDay != null) 'workWeekStartDay': workWeekStartDay,
      if (selectedPlanId != null) 'selectedPlanId': selectedPlanId,
      if (billingCycle != null) 'billingCycle': billingCycle,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerPhone': ownerPhone,
      if (jobTitle != null) 'jobTitle': jobTitle,
      if (hrName != null) 'hrName': hrName,
      if (hrEmail != null) 'hrEmail': hrEmail,
      'address': address.toJson(),
      'timezone': timezone,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : FieldValue.serverTimestamp(),
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null)
        'approvedAt': Timestamp.fromDate(approvedAt!),
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (rejectedAt != null)
        'rejectedAt': Timestamp.fromDate(rejectedAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (companyId != null) 'companyId': companyId,
    };
  }

  /// Create from Firestore document
  factory RegistrationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegistrationRequest(
      requestId: doc.id,
      status: data['status'] ?? 'pending',
      businessName: data['businessName'] ?? '',
      industry: data['industry'] ?? '',
      numberOfEmployees: data['numberOfEmployees'] ?? 0,
      website: data['website'],
      taxId: data['taxId'],
      payrollService: data['payrollService'],
      payPeriodType: data['payPeriodType'],
      workWeekStartDay: data['workWeekStartDay'],
      selectedPlanId: data['selectedPlanId'],
      billingCycle: data['billingCycle'],
      ownerName: data['ownerName'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      ownerPhone: data['ownerPhone'] ?? '',
      jobTitle: data['jobTitle'],
      hrName: data['hrName'],
      hrEmail: data['hrEmail'],
      address: Address.fromJson(data['address'] ?? {}),
      timezone: data['timezone'] ?? 'America/New_York',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      approvedBy: data['approvedBy'],
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedBy: data['rejectedBy'],
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
      companyId: data['companyId'],
    );
  }

  /// Create a copy with updated fields
  RegistrationRequest copyWith({
    String? requestId,
    String? status,
    String? businessName,
    String? industry,
    int? numberOfEmployees,
    String? website,
    String? taxId,
    String? payrollService,
    String? payPeriodType,
    String? workWeekStartDay,
    String? selectedPlanId,
    String? billingCycle,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    String? jobTitle,
    String? hrName,
    String? hrEmail,
    Address? address,
    String? timezone,
    String? password,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? rejectionReason,
    String? companyId,
  }) {
    return RegistrationRequest(
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      businessName: businessName ?? this.businessName,
      industry: industry ?? this.industry,
      numberOfEmployees: numberOfEmployees ?? this.numberOfEmployees,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      payrollService: payrollService ?? this.payrollService,
      payPeriodType: payPeriodType ?? this.payPeriodType,
      workWeekStartDay: workWeekStartDay ?? this.workWeekStartDay,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      billingCycle: billingCycle ?? this.billingCycle,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      jobTitle: jobTitle ?? this.jobTitle,
      hrName: hrName ?? this.hrName,
      hrEmail: hrEmail ?? this.hrEmail,
      address: address ?? this.address,
      timezone: timezone ?? this.timezone,
      password: password ?? this.password,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      companyId: companyId ?? this.companyId,
    );
  }
}

/// Represents a business address
class Address {
  final String street;
  final String city;
  final String state;
  final String zip;

  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
  });

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zip': zip,
    };
  }

  factory Address.fromJson(dynamic json) {
    // Handle case where json might not be a Map
    if (json == null) {
      return Address(street: '', city: '', state: '', zip: '');
    }

    // Convert to Map if it's not already
    final Map<String, dynamic> addressMap = json is Map<String, dynamic>
        ? json
        : json is Map
            ? Map<String, dynamic>.from(json)
            : <String, dynamic>{};

    return Address(
      street: addressMap['street']?.toString() ?? '',
      city: addressMap['city']?.toString() ?? '',
      state: addressMap['state']?.toString() ?? '',
      zip: addressMap['zip']?.toString() ?? '',
    );
  }

  Address copyWith({
    String? street,
    String? city,
    String? state,
    String? zip,
  }) {
    return Address(
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
    );
  }

  @override
  String toString() {
    return '$street, $city, $state $zip';
  }
}

/// Industry options for registration
class IndustryOptions {
  static const List<String> industries = [
    'Retail',
    'Restaurant / Food Service',
    'Healthcare',
    'Construction',
    'Manufacturing',
    'Professional Services',
    'Technology',
    'Education',
    'Hospitality',
    'Transportation',
    'Warehouse / Logistics',
    'Non-Profit',
    'Other',
  ];
}

/// Employee count options
class EmployeeCountOptions {
  static const List<String> ranges = [
    '1-10',
    '11-25',
    '26-50',
    '51-100',
    '101-250',
    '251-500',
    '500+',
  ];

  static int getMaxEmployees(String range) {
    switch (range) {
      case '1-10':
        return 10;
      case '11-25':
        return 25;
      case '26-50':
        return 50;
      case '51-100':
        return 100;
      case '101-250':
        return 250;
      case '251-500':
        return 500;
      case '500+':
        return 999999;
      default:
        return 10;
    }
  }
}

/// Payroll service options
class PayrollServiceOptions {
  static const List<String> services = [
    'None / Manual',
    'ADP',
    'Paychex',
    'Gusto',
    'QuickBooks Payroll',
    'Rippling',
    'Paylocity',
    'Workday',
    'UKG (Ultimate Kronos Group)',
    'Square Payroll',
    'OnPay',
    'Other',
  ];
}

/// Pay period type options
class PayPeriodOptions {
  static const List<String> types = [
    'Weekly',
    'Bi-Weekly (Every 2 weeks)',
    'Semi-Monthly (Twice per month)',
    'Monthly',
  ];
}

/// Work week start day options
class WorkWeekStartOptions {
  static const List<String> days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
}
