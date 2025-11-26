import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/overtime_request_model.dart';
import '../../services/overtime_request_service.dart';
import '../../services/auth_provider.dart';

class OvertimeApprovalQueueScreen extends StatefulWidget {
  const OvertimeApprovalQueueScreen({super.key});

  @override
  State<OvertimeApprovalQueueScreen> createState() => _OvertimeApprovalQueueScreenState();
}

class _OvertimeApprovalQueueScreenState extends State<OvertimeApprovalQueueScreen> {
  final OvertimeRequestService _overtimeService = OvertimeRequestService();
  String _statusFilter = 'pending'; // pending, approved, rejected, all

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime Approvals'),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                const Text('Status:'),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'pending',
                        label: Text('Pending'),
                        icon: Icon(Icons.pending_actions),
                      ),
                      ButtonSegment(
                        value: 'approved',
                        label: Text('Approved'),
                        icon: Icon(Icons.check_circle),
                      ),
                      ButtonSegment(
                        value: 'rejected',
                        label: Text('Rejected'),
                        icon: Icon(Icons.cancel),
                      ),
                      ButtonSegment(
                        value: 'all',
                        label: Text('All'),
                        icon: Icon(Icons.list),
                      ),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _statusFilter = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Overtime Requests List
          Expanded(
            child: StreamBuilder<List<OvertimeRequestModel>>(
              stream: _statusFilter == 'pending'
                  ? _overtimeService.getPendingOvertimeRequests()
                  : _overtimeService.getAllOvertimeRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                List<OvertimeRequestModel> requests = snapshot.data ?? [];

                // Apply status filter for non-pending streams
                if (_statusFilter != 'pending' && _statusFilter != 'all') {
                  requests = requests.where((r) => r.status == _statusFilter).toList();
                }

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusFilter == 'pending'
                              ? 'No pending overtime requests'
                              : 'No ${_statusFilter} requests',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    return _OvertimeRequestCard(
                      request: requests[index],
                      onApprove: () => _handleApprove(requests[index]),
                      onReject: () => _handleReject(requests[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(OvertimeRequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Overtime'),
        content: Text(
          'Approve overtime shift for ${request.employeeName}?\n\n'
          'This will approve ${request.overtimeHours.toStringAsFixed(1)} hours '
          'of overtime for the week of ${DateFormat('MMM d').format(request.weekStartDate)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final adminId = authProvider.currentUser?.id;

        if (adminId == null) {
          throw Exception('Admin user not found');
        }

        await _overtimeService.approveOvertimeRequest(
          overtimeRequestId: request.id,
          adminId: adminId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Overtime approved for ${request.employeeName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error approving overtime: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReject(OvertimeRequestModel request) async {
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Overtime'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject overtime shift for ${request.employeeName}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection (optional)',
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final adminId = authProvider.currentUser?.id;

        if (adminId == null) {
          throw Exception('Admin user not found');
        }

        await _overtimeService.rejectOvertimeRequest(
          overtimeRequestId: request.id,
          adminId: adminId,
          rejectionReason: reasonController.text.isNotEmpty
              ? reasonController.text
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Overtime rejected for ${request.employeeName}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting overtime: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    reasonController.dispose();
  }
}

class _OvertimeRequestCard extends StatelessWidget {
  final OvertimeRequestModel request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _OvertimeRequestCard({
    required this.request,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    Color statusColor;
    IconData statusIcon;
    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Employee name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.employeeName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        request.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Manager info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Manager: ${request.managerName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Shift date and time
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(request.shiftStartTime),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${timeFormat.format(request.shiftStartTime)} - ${timeFormat.format(request.shiftEndTime)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hours breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _HoursRow(
                    label: 'Shift Hours',
                    value: request.shiftHours.toStringAsFixed(1),
                  ),
                  const Divider(height: 16),
                  _HoursRow(
                    label: 'Weekly Hours (before)',
                    value: request.weeklyHoursBeforeShift.toStringAsFixed(1),
                  ),
                  const Divider(height: 16),
                  _HoursRow(
                    label: 'Projected Weekly Total',
                    value: request.projectedWeeklyHours.toStringAsFixed(1),
                    bold: true,
                  ),
                  const Divider(height: 16),
                  _HoursRow(
                    label: 'Overtime Hours',
                    value: request.overtimeHours.toStringAsFixed(1),
                    valueColor: Colors.red,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Week range
            Text(
              'Week: ${DateFormat('MMM d').format(request.weekStartDate)} - ${DateFormat('MMM d, y').format(request.weekEndDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            // SMS notification status
            if (request.smsNotificationSent) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.message,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SMS notification sent',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ],

            // Rejection reason if rejected
            if (request.isRejected && request.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: ${request.rejectionReason}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Approval info if approved
            if (request.isApproved && request.approvedBy != null) ...[
              const SizedBox(height: 8),
              Text(
                'Approved by: ${request.approvedBy}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
              ),
              if (request.approvedAt != null)
                Text(
                  'on ${DateFormat('MMM d, y h:mm a').format(request.approvedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                ),
            ],

            // Action buttons (only for pending requests)
            if (request.isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _HoursRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '$value hrs',
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
