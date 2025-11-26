import 'package:flutter/material.dart';
import '../services/actual_overtime_service.dart';

/// Card widget that displays overtime risk warning for employees
class OvertimeRiskWarningCard extends StatefulWidget {
  final String employeeId;

  const OvertimeRiskWarningCard({
    super.key,
    required this.employeeId,
  });

  @override
  State<OvertimeRiskWarningCard> createState() => _OvertimeRiskWarningCardState();
}

class _OvertimeRiskWarningCardState extends State<OvertimeRiskWarningCard> {
  final ActualOvertimeService _overtimeService = ActualOvertimeService();
  OvertimeRiskAnalysis? _analysis;
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG: OvertimeRiskWarningCard initState called for employee: ${widget.employeeId}');
    _loadOvertimeRisk();
  }

  Future<void> _loadOvertimeRisk() async {
    try {
      print('DEBUG: Starting analyzeOvertimeRisk for employee: ${widget.employeeId}');
      final analysis = await _overtimeService.analyzeOvertimeRisk(
        employeeId: widget.employeeId,
        date: DateTime.now(),
      );

      print('DEBUG: Analysis completed successfully');
      print('DEBUG: Risk Level: ${analysis.riskLevel}');
      print('DEBUG: Projected Hours: ${analysis.projectedTotalHours}');
      print('DEBUG: Overtime Hours: ${analysis.overtimeHours}');

      if (mounted) {
        setState(() {
          _analysis = analysis;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('DEBUG: ERROR loading overtime risk: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getRiskColor(OvertimeRiskLevel level) {
    switch (level) {
      case OvertimeRiskLevel.critical:
        return Colors.red;
      case OvertimeRiskLevel.high:
        return Colors.orange;
      case OvertimeRiskLevel.medium:
        return Colors.blue;
      case OvertimeRiskLevel.low:
        return Colors.green;
    }
  }

  IconData _getRiskIcon(OvertimeRiskLevel level) {
    switch (level) {
      case OvertimeRiskLevel.critical:
        return Icons.error;
      case OvertimeRiskLevel.high:
        return Icons.warning;
      case OvertimeRiskLevel.medium:
        return Icons.info;
      case OvertimeRiskLevel.low:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    // TEMPORARY DEBUG: Always show something
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('DEBUG: Loading overtime data...'),
        ),
      );
    }

    if (_analysis == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.red.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('DEBUG: No overtime analysis data loaded. Check console for errors.'),
        ),
      );
    }

    // Hide card for LOW risk level
    if (_analysis!.riskLevel == OvertimeRiskLevel.low) {
      return const SizedBox.shrink();
    }

    final analysis = _analysis!;
    final riskColor = _getRiskColor(analysis.riskLevel);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: riskColor, width: 2),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getRiskIcon(analysis.riskLevel),
                    color: riskColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overtime Warning',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                        Text(
                          analysis.riskLevelText,
                          style: TextStyle(
                            fontSize: 14,
                            color: riskColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: riskColor,
                  ),
                ],
              ),
            ),
          ),

          // Quick Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'Projected',
                  '${analysis.projectedTotalHours.toStringAsFixed(1)}h',
                  riskColor,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                _buildStatColumn(
                  'Overtime',
                  '${analysis.overtimeHours.toStringAsFixed(1)}h',
                  analysis.overtimeHours > 0 ? Colors.red : Colors.green,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                _buildStatColumn(
                  'Issues',
                  '${analysis.violations.length}',
                  analysis.violations.isNotEmpty ? Colors.orange : Colors.green,
                ),
              ],
            ),
          ),

          // Expanded Details
          if (_isExpanded) ...[
            const Divider(height: 1),

            // Hours Breakdown
            _buildSection(
              'Hours Breakdown',
              Column(
                children: [
                  _buildDetailRow('Worked This Week', '${analysis.actualHoursWorked.toStringAsFixed(1)}h'),
                  _buildDetailRow('Current Shift', '${analysis.currentShiftProjectedHours.toStringAsFixed(1)}h'),
                  _buildDetailRow('Remaining Scheduled', '${analysis.remainingScheduledHours.toStringAsFixed(1)}h'),
                  const Divider(),
                  _buildDetailRow(
                    'Total Projected',
                    '${analysis.projectedTotalHours.toStringAsFixed(1)}h',
                    isBold: true,
                    valueColor: riskColor,
                  ),
                ],
              ),
            ),

            // Violations
            if (analysis.violations.isNotEmpty) ...[
              const Divider(),
              _buildSection(
                'Time Tracking Issues (${analysis.violations.length})',
                Column(
                  children: analysis.violations.map((violation) {
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getViolationIcon(violation.type),
                        color: Colors.orange,
                        size: 20,
                      ),
                      title: Text(
                        violation.description,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Remediation Strategies
            if (analysis.remediationStrategies.isNotEmpty) ...[
              const Divider(),
              _buildSection(
                'What You Can Do',
                Column(
                  children: analysis.remediationStrategies.asMap().entries.map((entry) {
                    final index = entry.key;
                    final strategy = entry.value;
                    return _buildStrategyCard(index + 1, strategy, riskColor);
                  }).toList(),
                ),
              ),
            ],

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadOvertimeRisk,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: riskColor,
                        side: BorderSide(color: riskColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to detailed view or schedule screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Check your schedule to make adjustments'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('View Schedule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: riskColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyCard(int priority, RemediationStrategy strategy, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: primaryColor,
                child: Text(
                  '$priority',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strategy.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Save ${strategy.potentialHoursSaved.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strategy.details,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          // Show swap candidates if available
          if (strategy.swapCandidates != null && strategy.swapCandidates!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Potential swap partners:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...strategy.swapCandidates!.take(3).map((candidate) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${candidate.candidateName} (${candidate.candidateCurrentHours.toStringAsFixed(1)}h this week)',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getViolationIcon(ViolationType type) {
    switch (type) {
      case ViolationType.earlyClockIn:
        return Icons.login;
      case ViolationType.lateClockOut:
        return Icons.logout;
      case ViolationType.shortBreak:
        return Icons.free_breakfast;
    }
  }
}
