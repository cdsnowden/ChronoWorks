class EmployeePayrollSummary {
  final String employeeId;
  final String employeeName;
  final String employeeEmail;
  final double hourlyRate;
  final String employmentType;

  // Hours breakdown
  final double regularHours;
  final double overtimeHours;
  final double totalHours;

  // Time off
  final int paidTimeOffDays;
  final int unpaidTimeOffDays;
  final double paidTimeOffHours;

  // Calculations
  final double regularPay;
  final double overtimePay;
  final double paidTimeOffPay;
  final double grossPay;

  // Metadata
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalShifts;

  EmployeePayrollSummary({
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    required this.hourlyRate,
    required this.employmentType,
    required this.regularHours,
    required this.overtimeHours,
    required this.totalHours,
    required this.paidTimeOffDays,
    required this.unpaidTimeOffDays,
    required this.paidTimeOffHours,
    required this.regularPay,
    required this.overtimePay,
    required this.paidTimeOffPay,
    required this.grossPay,
    required this.periodStart,
    required this.periodEnd,
    required this.totalShifts,
  });

  // Convert to CSV row
  List<String> toCsvRow() {
    return [
      employeeId,
      employeeName,
      employeeEmail,
      hourlyRate.toStringAsFixed(2),
      employmentType,
      regularHours.toStringAsFixed(2),
      overtimeHours.toStringAsFixed(2),
      totalHours.toStringAsFixed(2),
      paidTimeOffDays.toString(),
      unpaidTimeOffDays.toString(),
      paidTimeOffHours.toStringAsFixed(2),
      regularPay.toStringAsFixed(2),
      overtimePay.toStringAsFixed(2),
      paidTimeOffPay.toStringAsFixed(2),
      grossPay.toStringAsFixed(2),
      periodStart.toIso8601String().split('T')[0],
      periodEnd.toIso8601String().split('T')[0],
      totalShifts.toString(),
    ];
  }

  // CSV header
  static List<String> get csvHeaders => [
        'Employee ID',
        'Employee Name',
        'Email',
        'Hourly Rate',
        'Employment Type',
        'Regular Hours',
        'Overtime Hours',
        'Total Hours',
        'Paid Time Off Days',
        'Unpaid Time Off Days',
        'Paid Time Off Hours',
        'Regular Pay',
        'Overtime Pay',
        'PTO Pay',
        'Gross Pay',
        'Period Start',
        'Period End',
        'Total Shifts',
      ];

  // Convert to Map for JSON/Firestore
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeEmail': employeeEmail,
      'hourlyRate': hourlyRate,
      'employmentType': employmentType,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'totalHours': totalHours,
      'paidTimeOffDays': paidTimeOffDays,
      'unpaidTimeOffDays': unpaidTimeOffDays,
      'paidTimeOffHours': paidTimeOffHours,
      'regularPay': regularPay,
      'overtimePay': overtimePay,
      'paidTimeOffPay': paidTimeOffPay,
      'grossPay': grossPay,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'totalShifts': totalShifts,
    };
  }

  @override
  String toString() {
    return 'EmployeePayrollSummary($employeeName: \$${grossPay.toStringAsFixed(2)}, ${totalHours.toStringAsFixed(2)} hrs)';
  }
}
