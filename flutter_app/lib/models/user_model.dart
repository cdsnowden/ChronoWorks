import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // 'admin', 'manager', 'employee'
  final String companyId; // Multi-tenant company ID
  final String? phoneNumber;
  final String? address; // Employee's home address
  final DateTime? dateOfBirth; // Employee's date of birth
  final DateTime? hireDate; // Employee's start/hire date for PTO calculations
  final String? ptoPolicyId; // Optional specific PTO policy (null = use company default)
  final String? profileImageUrl;
  final String? faceImageUrl; // For facial recognition
  final String employmentType; // 'full-time', 'part-time'
  final double hourlyRate;
  final bool isActive;
  final bool isKeyholder; // Whether employee has key access
  final bool? requiresPasswordChange; // Force password change on first login
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Manager-specific field
  final String? managerId; // For employees - references their manager

  // Location for geofencing
  final Map<String, double>? workLocation; // {lat: 0.0, lng: 0.0}

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.companyId,
    this.phoneNumber,
    this.address,
    this.dateOfBirth,
    this.hireDate,
    this.ptoPolicyId,
    this.profileImageUrl,
    this.faceImageUrl,
    required this.employmentType,
    required this.hourlyRate,
    this.isActive = true,
    this.isKeyholder = false,
    this.requiresPasswordChange,
    required this.createdAt,
    this.updatedAt,
    this.managerId,
    this.workLocation,
  });

  // Full name getter
  String get fullName => '$firstName $lastName';

  // Check if user is admin
  bool get isAdmin => role == 'admin';

  // Check if user is manager
  bool get isManager => role == 'manager';

  // Check if user is employee
  bool get isEmployee => role == 'employee';

  // Check if profile is complete (all required fields filled)
  bool get isProfileComplete {
    // Only employees need to complete their profile
    if (role != 'employee') return true;

    // Check if all required fields are filled
    return phoneNumber != null &&
           phoneNumber!.isNotEmpty &&
           address != null &&
           address!.isNotEmpty &&
           dateOfBirth != null;
  }

  // Effective start date for PTO calculations (uses hireDate if set, otherwise createdAt)
  DateTime get effectiveStartDate => hireDate ?? createdAt;

  // Calculate years of service based on effective start date
  int get yearsOfService {
    final now = DateTime.now();
    int years = now.year - effectiveStartDate.year;
    // Adjust if anniversary hasn't occurred yet this year
    if (now.month < effectiveStartDate.month ||
        (now.month == effectiveStartDate.month && now.day < effectiveStartDate.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  // Check if employee is eligible for PTO (based on waiting period - default 1 year)
  bool get isPtoEligible {
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    return effectiveStartDate.isBefore(oneYearAgo) || effectiveStartDate.isAtSameMomentAs(oneYearAgo);
  }

  // Get the date when employee becomes eligible for PTO
  DateTime get ptoEligibilityDate {
    return effectiveStartDate.add(const Duration(days: 365));
  }

  // Get days until PTO eligibility (0 if already eligible)
  int get daysUntilPtoEligible {
    if (isPtoEligible) return 0;
    return ptoEligibilityDate.difference(DateTime.now()).inDays;
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'companyId': companyId,
      'phoneNumber': phoneNumber,
      'address': address,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'hireDate': hireDate != null ? Timestamp.fromDate(hireDate!) : null,
      'ptoPolicyId': ptoPolicyId,
      'profileImageUrl': profileImageUrl,
      'faceImageUrl': faceImageUrl,
      'employmentType': employmentType,
      'hourlyRate': hourlyRate,
      'isActive': isActive,
      'isKeyholder': isKeyholder,
      'requiresPasswordChange': requiresPasswordChange,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'managerId': managerId,
      'workLocation': workLocation,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      role: map['role'] ?? 'employee',
      companyId: map['companyId'] ?? '',
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      hireDate: map['hireDate'] != null
          ? (map['hireDate'] as Timestamp).toDate()
          : null,
      ptoPolicyId: map['ptoPolicyId'],
      dateOfBirth: map['dateOfBirth'] != null
          ? (map['dateOfBirth'] as Timestamp).toDate()
          : null,
      profileImageUrl: map['profileImageUrl'],
      faceImageUrl: map['faceImageUrl'],
      employmentType: map['employmentType'] ?? 'full-time',
      hourlyRate: (map['hourlyRate'] ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
      isKeyholder: map['isKeyholder'] ?? false,
      requiresPasswordChange: map['requiresPasswordChange'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      managerId: map['managerId'],
      workLocation: map['workLocation'] != null
          ? Map<String, double>.from(map['workLocation'])
          : null,
    );
  }

  // Create from Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  // Copy with method for updates
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? role,
    String? companyId,
    String? phoneNumber,
    String? address,
    DateTime? dateOfBirth,
    DateTime? hireDate,
    String? ptoPolicyId,
    String? profileImageUrl,
    String? faceImageUrl,
    String? employmentType,
    double? hourlyRate,
    bool? isActive,
    bool? isKeyholder,
    bool? requiresPasswordChange,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? managerId,
    Map<String, double>? workLocation,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      hireDate: hireDate ?? this.hireDate,
      ptoPolicyId: ptoPolicyId ?? this.ptoPolicyId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      faceImageUrl: faceImageUrl ?? this.faceImageUrl,
      employmentType: employmentType ?? this.employmentType,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      isActive: isActive ?? this.isActive,
      isKeyholder: isKeyholder ?? this.isKeyholder,
      requiresPasswordChange: requiresPasswordChange ?? this.requiresPasswordChange,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      managerId: managerId ?? this.managerId,
      workLocation: workLocation ?? this.workLocation,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $fullName, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
