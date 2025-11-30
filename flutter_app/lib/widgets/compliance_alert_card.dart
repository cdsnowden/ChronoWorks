import 'package:flutter/material.dart';
import 'dart:async';
import '../models/compliance_rule_model.dart';
import '../models/time_entry_model.dart';
import '../services/compliance_service.dart';

/// Widget that displays real-time compliance alerts for an active shift
class ComplianceAlertCard extends StatefulWidget {
  final String employeeId;
  final String companyId;
  final DateTime? clockInTime;
  final List<TimeEntryModel>? breaks;
  final bool compact;

  const ComplianceAlertCard({
    super.key,
    required this.employeeId,
    required this.companyId,
    this.clockInTime,
    this.breaks,
    this.compact = false,
  });

  @override
  State<ComplianceAlertCard> createState() => _ComplianceAlertCardState();
}

class _ComplianceAlertCardState extends State<ComplianceAlertCard> {
  final ComplianceService _complianceService = ComplianceService();
  Timer? _checkTimer;
  ComplianceCheckResult? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.clockInTime != null) {
      _checkCompliance();
      // Check every minute
      _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _checkCompliance();
      });
    }
  }

  @override
  void didUpdateWidget(ComplianceAlertCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clockInTime != oldWidget.clockInTime) {
      if (widget.clockInTime != null) {
        _checkCompliance();
        _checkTimer?.cancel();
        _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          _checkCompliance();
        });
      } else {
        _checkTimer?.cancel();
        setState(() {
          _result = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCompliance() async {
    if (widget.clockInTime == null) return;

    try {
      final result = await _complianceService.checkActiveShift(
        employeeId: widget.employeeId,
        companyId: widget.companyId,
        clockInTime: widget.clockInTime!,
        breaks: widget.breaks,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if not clocked in
    if (widget.clockInTime == null) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_result == null || (_result!.warnings.isEmpty && _result!.issues.isEmpty)) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompactCard();
    }

    return _buildFullCard();
  }

  Widget _buildCompactCard() {
    final hasViolations = _result!.issues.any((i) => i.severity == ComplianceSeverity.violation);
    final primaryColor = hasViolations ? Colors.red : Colors.orange;

    return Card(
      color: primaryColor.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              hasViolations ? Icons.error : Icons.warning,
              color: primaryColor.shade700,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasViolations ? 'Compliance Alert' : 'Reminder',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getTopAlertMessage(),
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_result!.warnings.isNotEmpty || _result!.issues.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_result!.warnings.length + _result!.issues.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor.shade800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _result!.hasViolations
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  _result!.hasViolations ? Icons.gpp_bad : Icons.shield,
                  color: _result!.hasViolations
                      ? Colors.red.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Compliance Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _result!.hasViolations
                        ? Colors.red.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _checkCompliance,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Violations
          if (_result!.issues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._result!.issues.map((issue) => _buildAlertItem(
                    icon: _getSeverityIcon(issue.severity),
                    color: _getSeverityColor(issue.severity),
                    title: issue.ruleName,
                    message: issue.message,
                    action: issue.suggestedAction,
                  )),
                ],
              ),
            ),

          // Warnings
          if (_result!.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_result!.issues.isNotEmpty)
                    const Divider(),
                  ..._result!.warnings.map((warning) => _buildWarningItem(warning)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    String? action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(ComplianceWarning warning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(
              _getCategoryIcon(warning.category),
              color: Colors.amber.shade800,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  if (warning.minutesUntilViolation > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${warning.minutesUntilViolation} min remaining',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTopAlertMessage() {
    if (_result!.issues.isNotEmpty) {
      return _result!.issues.first.message;
    }
    if (_result!.warnings.isNotEmpty) {
      return _result!.warnings.first.message;
    }
    return '';
  }

  IconData _getSeverityIcon(ComplianceSeverity severity) {
    switch (severity) {
      case ComplianceSeverity.critical:
        return Icons.dangerous;
      case ComplianceSeverity.violation:
        return Icons.error;
      case ComplianceSeverity.warning:
        return Icons.warning;
      case ComplianceSeverity.info:
        return Icons.info;
    }
  }

  Color _getSeverityColor(ComplianceSeverity severity) {
    switch (severity) {
      case ComplianceSeverity.critical:
        return Colors.red.shade900;
      case ComplianceSeverity.violation:
        return Colors.red;
      case ComplianceSeverity.warning:
        return Colors.orange;
      case ComplianceSeverity.info:
        return Colors.blue;
    }
  }

  IconData _getCategoryIcon(ComplianceCategory category) {
    switch (category) {
      case ComplianceCategory.mealBreak:
        return Icons.restaurant;
      case ComplianceCategory.restBreak:
        return Icons.coffee;
      case ComplianceCategory.dailyOvertime:
      case ComplianceCategory.weeklyOvertime:
        return Icons.access_time;
      case ComplianceCategory.doubleTime:
        return Icons.timer;
      case ComplianceCategory.minorHours:
      case ComplianceCategory.minorTiming:
        return Icons.child_care;
      case ComplianceCategory.predictiveScheduling:
        return Icons.calendar_today;
      case ComplianceCategory.splitShift:
        return Icons.call_split;
      case ComplianceCategory.consecutiveDays:
        return Icons.date_range;
    }
  }
}

/// A simple banner-style compliance warning for dashboards
class ComplianceBanner extends StatelessWidget {
  final String message;
  final ComplianceSeverity severity;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const ComplianceBanner({
    super.key,
    required this.message,
    required this.severity,
    this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(_getIcon(), color: color.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color.shade900),
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }

  MaterialColor _getColor() {
    switch (severity) {
      case ComplianceSeverity.critical:
      case ComplianceSeverity.violation:
        return Colors.red;
      case ComplianceSeverity.warning:
        return Colors.orange;
      case ComplianceSeverity.info:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (severity) {
      case ComplianceSeverity.critical:
        return Icons.dangerous;
      case ComplianceSeverity.violation:
        return Icons.error;
      case ComplianceSeverity.warning:
        return Icons.warning;
      case ComplianceSeverity.info:
        return Icons.info;
    }
  }
}
