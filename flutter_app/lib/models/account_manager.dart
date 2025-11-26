import 'package:cloud_firestore/cloud_firestore.dart';

class AccountManager {
  final String id;
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final String? photoURL;
  final String role;
  final List<String> permissions;
  final List<String> assignedCompanies;
  final int maxAssignedCompanies;
  final AccountManagerMetrics? metrics;
  final String status;
  final DateTime? hireDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  AccountManager({
    required this.id,
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.role,
    required this.permissions,
    required this.assignedCompanies,
    required this.maxAssignedCompanies,
    this.metrics,
    required this.status,
    this.hireDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory AccountManager.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AccountManager(
      id: doc.id,
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'],
      photoURL: data['photoURL'],
      role: data['role'] ?? 'account_manager',
      permissions: List<String>.from(data['permissions'] ?? []),
      assignedCompanies: List<String>.from(data['assignedCompanies'] ?? []),
      maxAssignedCompanies: data['maxAssignedCompanies'] ?? 100,
      metrics: data['metrics'] != null
          ? AccountManagerMetrics.fromMap(data['metrics'])
          : null,
      status: data['status'] ?? 'active',
      hireDate: data['hireDate']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'role': role,
      'permissions': permissions,
      'assignedCompanies': assignedCompanies,
      'maxAssignedCompanies': maxAssignedCompanies,
      'metrics': metrics?.toMap(),
      'status': status,
      'hireDate': hireDate != null ? Timestamp.fromDate(hireDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'createdBy': createdBy,
    };
  }

  // Helper getters
  int get assignedCount => assignedCompanies.length;
  bool get isAtCapacity => assignedCount >= maxAssignedCompanies;
  double get capacityPercentage => (assignedCount / maxAssignedCompanies) * 100;
}

class AccountManagerMetrics {
  final int totalAssignedCustomers;
  final int activeCustomers;
  final int trialCustomers;
  final int paidCustomers;
  final double averageResponseTime;
  final double customerSatisfactionScore;
  final double monthlyUpsellRevenue;

  AccountManagerMetrics({
    required this.totalAssignedCustomers,
    required this.activeCustomers,
    required this.trialCustomers,
    required this.paidCustomers,
    required this.averageResponseTime,
    required this.customerSatisfactionScore,
    required this.monthlyUpsellRevenue,
  });

  factory AccountManagerMetrics.fromMap(Map<String, dynamic> map) {
    return AccountManagerMetrics(
      totalAssignedCustomers: map['totalAssignedCustomers'] ?? 0,
      activeCustomers: map['activeCustomers'] ?? 0,
      trialCustomers: map['trialCustomers'] ?? 0,
      paidCustomers: map['paidCustomers'] ?? 0,
      averageResponseTime: (map['averageResponseTime'] ?? 0).toDouble(),
      customerSatisfactionScore:
          (map['customerSatisfactionScore'] ?? 0).toDouble(),
      monthlyUpsellRevenue: (map['monthlyUpsellRevenue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAssignedCustomers': totalAssignedCustomers,
      'activeCustomers': activeCustomers,
      'trialCustomers': trialCustomers,
      'paidCustomers': paidCustomers,
      'averageResponseTime': averageResponseTime,
      'customerSatisfactionScore': customerSatisfactionScore,
      'monthlyUpsellRevenue': monthlyUpsellRevenue,
    };
  }
}
