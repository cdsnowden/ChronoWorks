import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../services/time_off_request_service.dart';
import '../../services/blocked_dates_service.dart';
import '../../services/pto_service.dart';

class RequestTimeOffScreen extends StatefulWidget {
  const RequestTimeOffScreen({Key? key}) : super(key: key);

  @override
  State<RequestTimeOffScreen> createState() => _RequestTimeOffScreenState();
}

class _RequestTimeOffScreenState extends State<RequestTimeOffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _timeOffService = TimeOffRequestService();
  final _blockedDatesService = BlockedDatesService();
  final _ptoService = PtoService();
  final _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedType = 'paid';
  bool _isLoading = false;
  String? _errorMessage;
  List<DateTime> _blockedDates = [];

  // PTO Eligibility (loaded from policy)
  bool _isPtoEligible = true;
  DateTime? _ptoEligibilityDate;
  int _daysUntilPtoEligible = 0;
  int _waitingPeriodMonths = 12;
  bool _eligibilityLoaded = false;

  // PTO Balance info
  double _availableHours = 0;
  double _availableDays = 0;
  bool _balanceLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBlockedDates();
    _loadPtoEligibility();
  }

  Future<void> _loadPtoEligibility() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    try {
      final eligibility = await _ptoService.checkPtoEligibility(
        employeeId: user.id,
        companyId: user.companyId,
      );

      if (mounted) {
        setState(() {
          _isPtoEligible = eligibility['isEligible'] as bool;
          _ptoEligibilityDate = eligibility['eligibilityDate'] as DateTime?;
          _daysUntilPtoEligible = eligibility['daysUntilEligible'] as int;
          _waitingPeriodMonths = eligibility['waitingPeriodMonths'] as int;
          _eligibilityLoaded = true;

          // Auto-select unpaid if not eligible
          if (!_isPtoEligible && _selectedType == 'paid') {
            _selectedType = 'unpaid';
          }
        });
      }

      // Load balance if eligible
      if (_isPtoEligible) {
        await _loadPtoBalance();
      }
    } catch (e) {
      // Default to eligible on error
      if (mounted) {
        setState(() {
          _isPtoEligible = true;
          _eligibilityLoaded = true;
        });
      }
    }
  }

  Future<void> _loadPtoBalance() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    try {
      final summary = await _ptoService.getEmployeePtoSummary(
        employeeId: user.id,
        companyId: user.companyId,
        year: DateTime.now().year,
      );

      if (mounted) {
        setState(() {
          _availableHours = summary['available'] as double;
          _availableDays = summary['availableDays'] as double;
          _balanceLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _balanceLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedDates() async {
    try {
      final authProvider = context.read<app_auth.AuthProvider>();
      final user = authProvider.currentUser;

      if (user != null && user.companyId.isNotEmpty) {
        final blocked = await _blockedDatesService.getBlockedDates(user.companyId);
        setState(() {
          _blockedDates = blocked.map((b) => b.date).toList();
        });
      }
    } catch (e) {
      // Silently fail - blocked dates are informational
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _startDate ?? now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      helpText: 'Select Start Date',
      selectableDayPredicate: (DateTime date) {
        // Disable weekends (optional - you can remove this if weekends can be requested)
        // if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        //   return false;
        // }

        // Check if date is blocked
        final normalizedDate = DateTime(date.year, date.month, date.day);
        return !_blockedDates.any((blocked) =>
            blocked.year == normalizedDate.year &&
            blocked.month == normalizedDate.month &&
            blocked.day == normalizedDate.day);
      },
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before the new start date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start date first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime(_startDate!.year + 1),
      helpText: 'Select End Date',
      selectableDayPredicate: (DateTime date) {
        // Disable weekends (optional - you can remove this if weekends can be requested)
        // if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        //   return false;
        // }

        // Check if date is blocked
        final normalizedDate = DateTime(date.year, date.month, date.day);
        return !_blockedDates.any((blocked) =>
            blocked.year == normalizedDate.year &&
            blocked.month == normalizedDate.month &&
            blocked.day == normalizedDate.day);
      },
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  int _calculateDays() {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  double _calculateHours() {
    if (_startDate == null || _endDate == null) return 0;
    return _ptoService.calculateRequestHours(
      startDate: _startDate!,
      endDate: _endDate!,
    );
  }

  bool _hasInsufficientBalance() {
    if (_selectedType != 'paid' || !_isPtoEligible || !_balanceLoaded) return false;
    final requestedHours = _calculateHours();
    return requestedHours > _availableHours;
  }

  Widget _buildRequestSummary(int days) {
    final hours = _calculateHours();
    final isPaid = _selectedType == 'paid';
    final insufficientBalance = _hasInsufficientBalance();

    return Column(
      children: [
        // Request summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: insufficientBalance ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: insufficientBalance ? Colors.red.shade300 : Colors.green.shade200,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    insufficientBalance ? Icons.warning : Icons.check_circle,
                    color: insufficientBalance ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$days ${days == 1 ? 'day' : 'days'} (${hours.toStringAsFixed(1)} hours)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: insufficientBalance ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),

              // PTO Balance info for paid requests
              if (isPaid && _isPtoEligible && _balanceLoaded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBalanceInfo(
                      'Available',
                      '${_availableDays.toStringAsFixed(1)}d',
                      Colors.teal,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.shade300,
                    ),
                    _buildBalanceInfo(
                      'Requesting',
                      '${(hours / 8).toStringAsFixed(1)}d',
                      insufficientBalance ? Colors.red : Colors.orange,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.shade300,
                    ),
                    _buildBalanceInfo(
                      'Remaining',
                      '${((_availableHours - hours) / 8).toStringAsFixed(1)}d',
                      insufficientBalance ? Colors.red : Colors.green,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Insufficient balance warning
        if (insufficientBalance) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You don\'t have enough PTO balance. You have ${_availableDays.toStringAsFixed(1)} days available but are requesting ${(hours / 8).toStringAsFixed(1)} days.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBalanceInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      setState(() {
        _errorMessage = 'Please select both start and end dates';
      });
      return;
    }

    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage = 'User not found. Please log in again.';
      });
      return;
    }

    // Check PTO eligibility (uses policy-based waiting period)
    if (_selectedType == 'paid' && !_isPtoEligible) {
      final eligibilityDateStr = _ptoEligibilityDate != null
          ? DateFormat('MMM dd, yyyy').format(_ptoEligibilityDate!)
          : 'your eligibility date';
      setState(() {
        _errorMessage = 'You are not eligible for Paid Time Off until $eligibilityDateStr. Please select Unpaid Leave instead.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if any dates in the range are blocked
      final blockedInRange = await _blockedDatesService.getBlockedDatesInRange(
        companyId: user.companyId,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (blockedInRange.isNotEmpty) {
        final dateFormat = DateFormat('MMM dd, yyyy');
        final blockedDatesStr = blockedInRange
            .map((date) => dateFormat.format(date))
            .join(', ');

        throw Exception(
            'The following dates are blocked and cannot be requested: $blockedDatesStr');
      }

      await _timeOffService.createRequest(
        employeeId: user.id,
        employeeName: user.fullName,
        startDate: _startDate!,
        endDate: _endDate!,
        type: _selectedType,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        companyId: user.companyId,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time off request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _calculateDays();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Time Off'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PTO Eligibility Notice
                if (_eligibilityLoaded && !_isPtoEligible)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.schedule, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PTO Eligibility',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your company requires $_waitingPeriodMonths month${_waitingPeriodMonths == 1 ? '' : 's'} of employment before PTO eligibility. '
                                '${_ptoEligibilityDate != null ? 'You will be eligible on ${DateFormat('MMM dd, yyyy').format(_ptoEligibilityDate!)}' : ''}'
                                '${_daysUntilPtoEligible > 0 ? ' ($_daysUntilPtoEligible days remaining)' : ''}. '
                                'You can still request unpaid leave.',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Submit your time off request. Your manager will review and respond.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Time off type selection
                const Text(
                  'Type of Time Off',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'paid',
                      enabled: _isPtoEligible,
                      child: Row(
                        children: [
                          const Text('Paid Time Off'),
                          if (!_isPtoEligible)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '(Not eligible)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'unpaid',
                      child: Text('Unpaid Leave'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Date selection
                const Text(
                  'Dates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _isLoading ? null : _selectStartDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Select start date',
                            style: TextStyle(
                              color: _startDate != null
                                  ? Colors.black87
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _isLoading ? null : _selectEndDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'Select end date',
                            style: TextStyle(
                              color: _endDate != null
                                  ? Colors.black87
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Days/Hours calculation with PTO balance
                if (days > 0)
                  _buildRequestSummary(days),

                const SizedBox(height: 24),

                // Reason (optional)
                const Text(
                  'Reason (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    hintText: 'Add any additional details...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Submit button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
