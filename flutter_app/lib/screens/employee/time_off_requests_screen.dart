import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/time_off_request_model.dart';
import '../../services/auth_provider.dart';
import '../../services/time_off_request_service.dart';

class TimeOffRequestsScreen extends StatefulWidget {
  const TimeOffRequestsScreen({super.key});

  @override
  State<TimeOffRequestsScreen> createState() => _TimeOffRequestsScreenState();
}

class _TimeOffRequestsScreenState extends State<TimeOffRequestsScreen> {
  final TimeOffRequestService _service = TimeOffRequestService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Off Requests'),
      ),
      body: StreamBuilder<List<TimeOffRequestModel>>(
        stream: _service.getEmployeeRequests(currentUser.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final requests = snapshot.data ?? [];

          return Column(
            children: [
              _buildSummaryCard(requests),
              const Divider(height: 1),
              Expanded(
                child: requests.isEmpty
                    ? _buildEmptyState()
                    : _buildRequestsList(requests, currentUser.id, currentUser.fullName, currentUser.companyId),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRequestDialog(currentUser.id, currentUser.fullName, currentUser.companyId),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
    );
  }

  Widget _buildSummaryCard(List<TimeOffRequestModel> requests) {
    final pending = requests.where((r) => r.isPending).length;
    final approved = requests.where((r) => r.isApproved).length;
    final denied = requests.where((r) => r.isDenied).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('Pending', pending, Colors.orange),
          _buildStat('Approved', approved, Colors.green),
          _buildStat('Denied', denied, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
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
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.beach_access,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No time-off requests yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to request time off',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(List<TimeOffRequestModel> requests, String userId, String userName, String companyId) {
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, userId, userName, companyId);
      },
    );
  }

  Widget _buildRequestCard(TimeOffRequestModel request, String userId, String userName, String companyId) {
    Color statusColor;
    Icon statusIcon;

    switch (request.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = const Icon(Icons.schedule, color: Colors.orange);
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = const Icon(Icons.check_circle, color: Colors.green);
        break;
      case 'denied':
        statusColor = Colors.red;
        statusIcon = const Icon(Icons.cancel, color: Colors.red);
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = const Icon(Icons.help_outline, color: Colors.grey);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showRequestDetails(request, userId, userName, companyId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  statusIcon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.typeLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      request.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    request.formattedDateRange,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '(${request.daysRequested} ${request.daysRequested == 1 ? "day" : "days"})',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (request.reason != null && request.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.reason!,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (request.reviewedBy != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Reviewed by ${request.reviewerName}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (request.reviewNotes != null && request.reviewNotes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    request.reviewNotes!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestDetails(TimeOffRequestModel request, String userId, String userName, String companyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.typeLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Status', request.statusLabel),
              _buildDetailRow('Dates', request.formattedDateRange),
              _buildDetailRow('Duration', '${request.daysRequested} ${request.daysRequested == 1 ? "day" : "days"}'),
              if (request.reason != null && request.reason!.isNotEmpty)
                _buildDetailRow('Reason', request.reason!),
              if (request.reviewedBy != null) ...[
                const Divider(height: 24),
                _buildDetailRow('Reviewed By', request.reviewerName ?? 'Unknown'),
                _buildDetailRow(
                  'Reviewed On',
                  request.reviewedAt != null
                      ? DateFormat('MMM d, yyyy h:mm a').format(request.reviewedAt!)
                      : 'Unknown',
                ),
                if (request.reviewNotes != null && request.reviewNotes!.isNotEmpty)
                  _buildDetailRow('Notes', request.reviewNotes!),
              ],
              const Divider(height: 24),
              _buildDetailRow(
                'Requested On',
                DateFormat('MMM d, yyyy h:mm a').format(request.createdAt),
              ),
            ],
          ),
        ),
        actions: [
          if (request.isPending) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditRequestDialog(request, userId, userName, companyId);
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cancel Request'),
                    content: const Text('Are you sure you want to cancel this request?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Yes, Cancel'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  try {
                    await _service.cancelRequest(request.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Request cancelled')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showNewRequestDialog(String userId, String userName, String companyId) {
    _showRequestDialog(null, userId, userName, companyId);
  }

  void _showEditRequestDialog(TimeOffRequestModel request, String userId, String userName, String companyId) {
    _showRequestDialog(request, userId, userName, companyId);
  }

  void _showRequestDialog(TimeOffRequestModel? existingRequest, String userId, String userName, String companyId) {
    showDialog(
      context: context,
      builder: (context) => _TimeOffRequestDialog(
        service: _service,
        userId: userId,
        userName: userName,
        companyId: companyId,
        existingRequest: existingRequest,
      ),
    );
  }
}

class _TimeOffRequestDialog extends StatefulWidget {
  final TimeOffRequestService service;
  final String userId;
  final String userName;
  final String companyId;
  final TimeOffRequestModel? existingRequest;

  const _TimeOffRequestDialog({
    required this.service,
    required this.userId,
    required this.userName,
    required this.companyId,
    this.existingRequest,
  });

  @override
  State<_TimeOffRequestDialog> createState() => _TimeOffRequestDialogState();
}

class _TimeOffRequestDialogState extends State<_TimeOffRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _startDate;
  late DateTime _endDate;
  late String _type;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existingRequest?.startDate ?? DateTime.now();
    _endDate = widget.existingRequest?.endDate ?? DateTime.now();
    _type = widget.existingRequest?.type ?? 'vacation';
    _reasonController.text = widget.existingRequest?.reason ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingRequest == null ? 'New Time Off Request' : 'Edit Request'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'vacation', child: Text('Vacation')),
                  DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
                  DropdownMenuItem(value: 'personal', child: Text('Personal Day')),
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Leave')),
                ],
                onChanged: (value) {
                  setState(() {
                    _type = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Start Date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(_startDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate;
                      }
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('End Date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(_endDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: ${_endDate.difference(_startDate).inDays + 1} days',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Provide a brief reason for your request',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRequest,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existingRequest == null ? 'Submit' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.existingRequest == null) {
        // Create new request
        await widget.service.createRequest(
          employeeId: widget.userId,
          employeeName: widget.userName,
          startDate: _startDate,
          endDate: _endDate,
          type: _type,
          reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
          companyId: widget.companyId,
        );
      } else {
        // Update existing request
        await widget.service.updateRequest(
          requestId: widget.existingRequest!.id,
          startDate: _startDate,
          endDate: _endDate,
          type: _type,
          reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
        );
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingRequest == null
                  ? 'Request submitted successfully'
                  : 'Request updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
