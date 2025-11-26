import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/time_off_request_model.dart';
import '../../services/time_off_request_service.dart';
import '../../services/auth_provider.dart' as app_auth;

class TimeOffApprovalScreen extends StatefulWidget {
  const TimeOffApprovalScreen({Key? key}) : super(key: key);

  @override
  _TimeOffApprovalScreenState createState() => _TimeOffApprovalScreenState();
}

class _TimeOffApprovalScreenState extends State<TimeOffApprovalScreen> {
  final TimeOffRequestService _service = TimeOffRequestService();
  String _filterStatus = 'pending'; // pending, approved, denied, all
  String _sortBy = 'date'; // date, employee, type
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final companyId = authProvider.currentUser?.companyId ?? '';
    final userId = authProvider.currentUser?.id ?? '';
    final userName = authProvider.currentUser?.fullName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time-Off Requests'),
        backgroundColor: Colors.teal,
        actions: [
          // Statistics icon
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _showStatistics(context, companyId),
            tooltip: 'View Statistics',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter and Search Section
          _buildFilterSection(),

          // Requests List
          Expanded(
            child: _buildRequestsList(companyId, userId, userName),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by employee name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),

          // Filter chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Pending', 'pending', Colors.orange),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', 'approved', Colors.green),
                      const SizedBox(width: 8),
                      _buildFilterChip('Denied', 'denied', Colors.red),
                      const SizedBox(width: 8),
                      _buildFilterChip('All', 'all', Colors.blue),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort by',
                onSelected: (value) {
                  setState(() {
                    _sortBy = value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'date',
                    child: Text('Sort by Date'),
                  ),
                  const PopupMenuItem(
                    value: 'employee',
                    child: Text('Sort by Employee'),
                  ),
                  const PopupMenuItem(
                    value: 'type',
                    child: Text('Sort by Type'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRequestsList(String companyId, String userId, String userName) {
    return StreamBuilder<List<TimeOffRequestModel>>(
      stream: _filterStatus == 'pending'
          ? _service.getPendingRequests(companyId)
          : _service.getAllCompanyRequests(companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        var requests = snapshot.data!;

        // Apply filters
        if (_filterStatus != 'all') {
          requests = requests.where((r) => r.status == _filterStatus).toList();
        }

        // Apply search
        if (_searchQuery.isNotEmpty) {
          requests = requests
              .where((r) => r.employeeName.toLowerCase().contains(_searchQuery))
              .toList();
        }

        // Apply sorting
        requests = _sortRequests(requests);

        if (requests.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _buildRequestCard(
              requests[index],
              companyId,
              userId,
              userName,
            );
          },
        );
      },
    );
  }

  List<TimeOffRequestModel> _sortRequests(List<TimeOffRequestModel> requests) {
    switch (_sortBy) {
      case 'employee':
        requests.sort((a, b) => a.employeeName.compareTo(b.employeeName));
        break;
      case 'type':
        requests.sort((a, b) => a.type.compareTo(b.type));
        break;
      case 'date':
      default:
        requests.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
    }
    return requests;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No requests found',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Time-off requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    TimeOffRequestModel request,
    String companyId,
    String userId,
    String userName,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'denied':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showRequestDetails(request, companyId, userId, userName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with employee name and status
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    child: Text(
                      request.employeeName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.employeeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          request.typeLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          request.statusLabel,
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
              const Divider(),
              const SizedBox(height: 8),

              // Date range
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    request.formattedDateRange,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${request.daysRequested} ${request.daysRequested == 1 ? 'day' : 'days'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Reason (if provided)
              if (request.reason != null && request.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.reason!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Review info (if reviewed)
              if (request.reviewedBy != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Reviewed by ${request.reviewerName ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // Action buttons for pending requests
              if (request.isPending) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _handleDenyRequest(
                        request,
                        companyId,
                        userId,
                        userName,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Deny'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _handleApproveRequest(
                        request,
                        companyId,
                        userId,
                        userName,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestDetails(
    TimeOffRequestModel request,
    String companyId,
    String userId,
    String userName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${request.employeeName}\'s Request'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', request.typeLabel),
              const SizedBox(height: 12),
              _buildDetailRow('Date Range', request.formattedDateRange),
              const SizedBox(height: 12),
              _buildDetailRow('Duration', '${request.daysRequested} days'),
              const SizedBox(height: 12),
              _buildDetailRow('Status', request.statusLabel),
              if (request.reason != null && request.reason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Reason', request.reason!),
              ],
              if (request.reviewedBy != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Reviewed By',
                  request.reviewerName ?? 'Unknown',
                ),
                if (request.reviewedAt != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Reviewed At',
                    _formatDateTime(request.reviewedAt!),
                  ),
                ],
                if (request.reviewNotes != null &&
                    request.reviewNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Review Notes', request.reviewNotes!),
                ],
              ],
              const SizedBox(height: 12),
              _buildDetailRow(
                'Created',
                _formatDateTime(request.createdAt),
              ),
            ],
          ),
        ),
        actions: [
          if (request.isPending) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleDenyRequest(request, companyId, userId, userName);
              },
              child: const Text('Deny'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleApproveRequest(request, companyId, userId, userName);
              },
              child: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // UPDATED: Check for conflicts and show them in the approval dialog
  Future<void> _handleApproveRequest(
    TimeOffRequestModel request,
    String companyId,
    String userId,
    String userName,
  ) async {
    final notesController = TextEditingController();

    // NEW: Check for conflicting time-off from other employees
    List<TimeOffRequestModel>? conflicts;
    try {
      conflicts = await _service.getConflictingRequests(
        companyId: companyId,
        excludeEmployeeId: request.employeeId,
        startDate: request.startDate,
        endDate: request.endDate,
      );
    } catch (e) {
      print('Error checking conflicts: $e');
      conflicts = [];
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approve ${request.employeeName}\'s time-off request for ${request.formattedDateRange}?',
              ),

              // NEW: Show conflict warning if other employees have time off
              if (conflicts != null && conflicts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scheduling Conflict',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${conflicts.length} other employee${conflicts.length == 1 ? '' : 's'} ${conflicts.length == 1 ? 'has' : 'have'} time off during this period:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...conflicts.take(3).map((conflict) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${conflict.employeeName} (${conflict.formattedDateRange})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                      if (conflicts.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Text(
                            'And ${conflicts.length - 3} more...',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any notes about this approval...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.approveRequest(
        requestId: request.id,
        reviewerId: userId,
        reviewerName: userName,
        reviewNotes: notesController.text.isEmpty ? null : notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDenyRequest(
    TimeOffRequestModel request,
    String companyId,
    String userId,
    String userName,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deny ${request.employeeName}\'s time-off request for ${request.formattedDateRange}?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'Please provide a reason for denial...',
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
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for denial'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.denyRequest(
        requestId: request.id,
        reviewerId: userId,
        reviewerName: userName,
        reviewNotes: reasonController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request denied'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deny request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showStatistics(BuildContext context, String companyId) async {
    try {
      final stats = await _service.getCompanyStatistics(companyId);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Time-Off Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                'Total Requests',
                stats['total']?.toString() ?? '0',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Pending',
                stats['pending']?.toString() ?? '0',
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Approved',
                stats['approved']?.toString() ?? '0',
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Denied',
                stats['denied']?.toString() ?? '0',
                Colors.red,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
