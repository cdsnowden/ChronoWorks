import 'package:cloud_firestore/cloud_firestore.dart';

class OvertimeRiskData {
  final String employeeId;
  final String employeeName;
  final String riskLevel;
  final double projectedHours;
  final double overtimeHours;
  final DateTime date;

  OvertimeRiskData({
    required this.employeeId,
    required this.employeeName,
    required this.riskLevel,
    required this.projectedHours,
    required this.overtimeHours,
    required this.date,
  });

  factory OvertimeRiskData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OvertimeRiskData(
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? 'Unknown',
      riskLevel: data['riskLevel'] ?? 'unknown',
      projectedHours: (data['projectedHours'] ?? 0).toDouble(),
      overtimeHours: (data['overtimeHours'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class OvertimeRiskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all current overtime risk notifications for the current week
  Stream<List<OvertimeRiskData>> getOvertimeRisks() {
    final now = DateTime.now();
    // Get start of current week (Sunday) at midnight
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday % 7, 0, 0, 0, 0);

    return _firestore
        .collection('overtimeRiskNotifications')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OvertimeRiskData.fromFirestore(doc))
          .toList();
    });
  }

  // Get risk count by level for the current week
  Future<Map<String, int>> getRiskCounts() async {
    final now = DateTime.now();
    // Get start of current week (Sunday) at midnight
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday % 7, 0, 0, 0, 0);

    final snapshot = await _firestore
        .collection('overtimeRiskNotifications')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    final counts = {
      'critical': 0,
      'high': 0,
      'medium': 0,
      'low': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final riskLevel = data['riskLevel'] as String? ?? 'unknown';
      if (counts.containsKey(riskLevel)) {
        counts[riskLevel] = (counts[riskLevel] ?? 0) + 1;
      }
    }

    return counts;
  }

  // Get employee details for overtime risks
  Future<Map<String, dynamic>> getEmployeeDetails(String employeeId) async {
    final doc = await _firestore.collection('users').doc(employeeId).get();
    if (doc.exists) {
      return doc.data() ?? {};
    }
    return {};
  }
}
