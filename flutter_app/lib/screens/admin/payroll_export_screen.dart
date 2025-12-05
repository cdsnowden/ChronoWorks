import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../models/employee_payroll_summary.dart';
import '../../models/pay_period_model.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../services/payroll_export_service.dart';
// Conditional import for platform-specific file download
import '../../utils/file_download_mobile.dart'
    if (dart.library.html) '../../utils/file_download_web.dart';

class PayrollExportScreen extends StatefulWidget {
  const PayrollExportScreen({Key? key}) : super(key: key);

  @override
  State<PayrollExportScreen> createState() => _PayrollExportScreenState();
}

class _PayrollExportScreenState extends State<PayrollExportScreen> {
  final _payrollService = PayrollExportService();

  DateTime? _periodStart;
  DateTime? _periodEnd;
  String _periodType = 'biweekly';
  bool _isLoading = false;
  List<EmployeePayrollSummary>? _payrollData;
  final _adpCoCodeController = TextEditingController();
  Map<String, double>? _totals;

  @override
  void initState() {
    super.initState();
    _setCurrentPayPeriod();
  }

  void _setCurrentPayPeriod() {
    final currentPeriod = PayPeriodModel.getCurrentPayPeriod(_periodType);
    setState(() {
      _periodStart = currentPeriod.startDate;
      _periodEnd = currentPeriod.endDate;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _periodStart != null && _periodEnd != null
          ? DateTimeRange(start: _periodStart!, end: _periodEnd!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _periodStart = picked.start;
        _periodEnd = picked.end;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_periodStart == null || _periodEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pay period'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() {
      _isLoading = true;
      _payrollData = null;
      _totals = null;
    });

    try {
      final data = await _payrollService.generatePayrollReport(
        companyId: user.companyId,
        periodStart: _periodStart!,
        periodEnd: _periodEnd!,
      );

      final totals = _payrollService.calculateTotals(data);

      setState(() {
        _payrollData = data;
        _totals = totals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadCSV() {
    if (_payrollData == null || _payrollData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payroll data to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final csv = _payrollService.generateCSV(_payrollData!);
      final filename = 'payroll_${DateFormat('yyyy-MM-dd').format(_periodStart!)}_to_${DateFormat('yyyy-MM-dd').format(_periodEnd!)}.csv';

      // Use platform-specific download function
      downloadFile(csv, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $filename'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showADPExportDialog() {
    if (_periodStart == null || _periodEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pay period first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export for ADP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your ADP Company Code (3 characters):',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _adpCoCodeController,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'ADP Co Code',
                hintText: 'e.g., ABC',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Only employees with an ADP File # will be included. '
              'You can add ADP File # in employee settings.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadADPExport();
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadADPExport() async {
    final adpCoCode = _adpCoCodeController.text.trim().toUpperCase();
    if (adpCoCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an ADP Company Code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    try {
      // Check for employees missing ADP File Number
      final missingADP = await _payrollService.getEmployeesMissingADPNumber(user.companyId);
      
      if (missingADP.isNotEmpty) {
        // Show warning but continue
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${missingADP.length} employee(s) missing ADP File # will be skipped'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final csv = await _payrollService.generateADPExport(
        companyId: user.companyId,
        adpCoCode: adpCoCode,
        periodStart: _periodStart!,
        periodEnd: _periodEnd!,
      );

      // Generate ADP filename format: PRcccEPI.csv where ccc is company code
      final filename = 'PR${adpCoCode.padRight(3).substring(0, 3)}EPI.csv';

      downloadFile(csv, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $filename for ADP import'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Widget _buildSummaryCard(String title, String value, {Color? color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Export'),
        actions: [
          if (_payrollData != null && _payrollData!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadCSV,
              tooltip: 'Download CSV',
            ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _periodType,
                        decoration: const InputDecoration(
                          labelText: 'Pay Period Type',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _periodType = value;
                            });
                            _setCurrentPayPeriod();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _selectDateRange,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Pay Period',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.date_range),
                          ),
                          child: Text(
                            _periodStart != null && _periodEnd != null
                                ? '${DateFormat('MMM dd').format(_periodStart!)} - ${DateFormat('MMM dd, yyyy').format(_periodEnd!)}'
                                : 'Select period',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateReport,
                      icon: const Icon(Icons.calculate),
                      label: const Text('Generate Report'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Summary Cards
          if (_totals != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Employees',
                      _totals!['totalEmployees']!.toInt().toString(),
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Hours',
                      _totals!['totalHours']!.toStringAsFixed(1),
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      'Regular Pay',
                      '\$${_totals!['totalRegularPay']!.toStringAsFixed(2)}',
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      'Overtime Pay',
                      '\$${_totals!['totalOvertimePay']!.toStringAsFixed(2)}',
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      'Gross Pay',
                      '\$${_totals!['totalGrossPay']!.toStringAsFixed(2)}',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

          // Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payrollData == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Select a pay period and generate report',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : _payrollData!.isEmpty
                        ? const Center(child: Text('No payroll data for selected period'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Employee')),
                                  DataColumn(label: Text('Rate'), numeric: true),
                                  DataColumn(label: Text('Reg Hrs'), numeric: true),
                                  DataColumn(label: Text('OT Hrs'), numeric: true),
                                  DataColumn(label: Text('Total Hrs'), numeric: true),
                                  DataColumn(label: Text('PTO Days'), numeric: true),
                                  DataColumn(label: Text('Reg Pay'), numeric: true),
                                  DataColumn(label: Text('OT Pay'), numeric: true),
                                  DataColumn(label: Text('PTO Pay'), numeric: true),
                                  DataColumn(label: Text('Gross Pay'), numeric: true),
                                ],
                                rows: _payrollData!.map((summary) {
                                  return DataRow(cells: [
                                    DataCell(Text(summary.employeeName)),
                                    DataCell(Text('\$${summary.hourlyRate.toStringAsFixed(2)}')),
                                    DataCell(Text(summary.regularHours.toStringAsFixed(2))),
                                    DataCell(Text(summary.overtimeHours.toStringAsFixed(2))),
                                    DataCell(Text(summary.totalHours.toStringAsFixed(2))),
                                    DataCell(Text(summary.paidTimeOffDays.toString())),
                                    DataCell(Text('\$${summary.regularPay.toStringAsFixed(2)}')),
                                    DataCell(Text('\$${summary.overtimePay.toStringAsFixed(2)}')),
                                    DataCell(Text('\$${summary.paidTimeOffPay.toStringAsFixed(2)}')),
                                    DataCell(
                                      Text(
                                        '\$${summary.grossPay.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: _payrollData != null && _payrollData!.isNotEmpty
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'csv',
                  onPressed: _downloadCSV,
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  heroTag: 'adp',
                  onPressed: _showADPExportDialog,
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.business),
                  label: const Text('Export for ADP'),
                ),
              ],
            )
          : null,
    );
  }
}
