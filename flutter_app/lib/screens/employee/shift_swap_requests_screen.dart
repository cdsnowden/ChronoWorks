import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/shift_swap_request_model.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../services/shift_swap_request_service.dart';
import '../../services/schedule_service.dart';
import '../../services/auth_provider.dart';

class ShiftSwapRequestsScreen extends StatefulWidget {
  const ShiftSwapRequestsScreen({Key? key}) : super(key: key);

  @override
  State<ShiftSwapRequestsScreen> createState() =>
      _ShiftSwapRequestsScreenState();
}

class _ShiftSwapRequestsScreenState extends State<ShiftSwapRequestsScreen> {
  final ShiftSwapRequestService _service = ShiftSwapRequestService();
  final ScheduleService _scheduleService = ScheduleService();
  String _selectedTab = 'my_requests'; // 'my_requests', 'open_requests'

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shift Swaps')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Swaps & Coverage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateRequestDialog(context, user),
            tooltip: 'New Request',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabSelector(),
          Expanded(
            child: _selectedTab == 'my_requests'
                ? _buildMyRequests(user)
                : _buildOpenRequests(user),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => _selectedTab = 'my_requests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTab == 'my_requests'
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
                foregroundColor:
                    _selectedTab == 'my_requests' ? Colors.white : Colors.black,
              ),
              child: const Text('My Requests'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => _selectedTab = 'open_requests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTab == 'open_requests'
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
                foregroundColor: _selectedTab == 'open_requests'
                    ? Colors.white
                    : Colors.black,
              ),
              child: const Text('Available Coverage'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequests(UserModel user) {
    return StreamBuilder<List<ShiftSwapRequestModel>>(
      stream: _service.getEmployeeRequests(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No shift swap requests yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a request to swap or find coverage for a shift',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Group by status
        final pending =
            requests.where((r) => r.status == 'pending').toList();
        final approved =
            requests.where((r) => r.status == 'approved').toList();
        final others = requests
            .where((r) => r.status != 'pending' && r.status != 'approved')
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCards(pending.length, approved.length, others.length),
            const SizedBox(height: 16),
            if (pending.isNotEmpty) ...[
              const Text(
                'Pending',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...pending.map((r) => _buildRequestCard(r, user)),
            ],
            if (approved.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Approved',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...approved.map((r) => _buildRequestCard(r, user)),
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Other',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...others.map((r) => _buildRequestCard(r, user)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOpenRequests(UserModel user) {
    return StreamBuilder<List<ShiftSwapRequestModel>>(
      stream: _service.getOpenCoverageRequests(user.companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];
        // Filter out the user's own requests
        final filteredRequests =
            requests.where((r) => r.requesterId != user.id).toList();

        if (filteredRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No open coverage requests',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check back later for shifts that need coverage',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredRequests.length,
          itemBuilder: (context, index) {
            return _buildOpenRequestCard(filteredRequests[index]);
          },
        );
      },
    );
  }

  Widget _buildSummaryCards(int pending, int approved, int other) {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.orange.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '$pending',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Pending'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.green.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '$approved',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Approved'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.grey.shade200,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '$other',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Other'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(ShiftSwapRequestModel request, UserModel user) {
    Color statusColor;
    switch (request.status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'denied':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          request.isSwap ? Icons.swap_horiz : Icons.person_search,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(request.requestTypeLabel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(request.formattedOriginalShift),
            if (request.targetEmployeeName != null)
              Text('With: ${request.targetEmployeeName}'),
            if (request.isSwap && request.replacementShiftDate != null)
              Text('For: ${request.formattedReplacementShift}'),
            if (request.reason != null && request.reason!.isNotEmpty)
              Text('Reason: ${request.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Chip(
          label: Text(request.statusLabel),
          backgroundColor: statusColor.withOpacity(0.2),
          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
        onTap: () => _showRequestDetails(request, user),
      ),
    );
  }

  Widget _buildOpenRequestCard(ShiftSwapRequestModel request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.person_search,
          color: Theme.of(context).primaryColor,
        ),
        title: Text('${request.requesterName} needs coverage'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(request.formattedOriginalShift),
            if (request.reason != null && request.reason!.isNotEmpty)
              Text('Reason: ${request.reason}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => _showOpenRequestDetails(request),
      ),
    );
  }

  void _showCreateRequestDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => _CreateRequestDialog(
        userId: user.id,
        userName: user.fullName ?? 'Unknown',
        companyId: user.companyId,
      ),
    );
  }

  void _showRequestDetails(ShiftSwapRequestModel request, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.requestTypeLabel),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', request.statusLabel),
              const Divider(),
              _buildDetailRow('Original Shift', request.formattedOriginalShift),
              if (request.targetEmployeeName != null)
                _buildDetailRow('Target Employee', request.targetEmployeeName!),
              if (request.isSwap && request.replacementShiftDate != null)
                _buildDetailRow(
                    'Replacement Shift', request.formattedReplacementShift),
              if (request.reason != null && request.reason!.isNotEmpty)
                _buildDetailRow('Reason', request.reason!),
              const Divider(),
              _buildDetailRow('Created', request.createdAt.toString().split('.')[0]),
              if (request.reviewedAt != null) ...[
                _buildDetailRow('Reviewed', request.reviewedAt.toString().split('.')[0]),
                if (request.reviewerName != null)
                  _buildDetailRow('Reviewed By', request.reviewerName!),
                if (request.reviewNotes != null && request.reviewNotes!.isNotEmpty)
                  _buildDetailRow('Notes', request.reviewNotes!),
              ],
            ],
          ),
        ),
        actions: [
          if (request.isPending)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cancel Request'),
                    content: const Text(
                        'Are you sure you want to cancel this request?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  try {
                    await _service.cancelRequest(request.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Request cancelled successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Cancel Request'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOpenRequestDetails(ShiftSwapRequestModel request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coverage Request'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Requested By', request.requesterName),
              _buildDetailRow('Shift Date/Time', request.formattedOriginalShift),
              if (request.reason != null && request.reason!.isNotEmpty)
                _buildDetailRow('Reason', request.reason!),
              const SizedBox(height: 16),
              const Text(
                'Note: This request needs manager approval after you accept.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Interested'),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real app, you'd create a new request accepting this coverage
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Please contact your manager to accept this coverage request'),
                ),
              );
            },
            child: const Text('Interested'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Dialog for creating a new shift swap/coverage request
class _CreateRequestDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String companyId;

  const _CreateRequestDialog({
    required this.userId,
    required this.userName,
    required this.companyId,
  });

  @override
  State<_CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<_CreateRequestDialog> {
  final ShiftSwapRequestService _service = ShiftSwapRequestService();
  final ScheduleService _scheduleService = ScheduleService();
  final _formKey = GlobalKey<FormState>();

  String _requestType = 'coverage'; // 'coverage' or 'swap'
  ShiftModel? _selectedShift;
  ShiftModel? _replacementShift;
  UserModel? _targetEmployee;
  String _reason = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Shift Request'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request Type:'),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Coverage'),
                      value: 'coverage',
                      groupValue: _requestType,
                      onChanged: (value) {
                        setState(() {
                          _requestType = value!;
                          _replacementShift = null;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Swap'),
                      value: 'swap',
                      groupValue: _requestType,
                      onChanged: (value) {
                        setState(() => _requestType = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildShiftSelector(),
              if (_requestType == 'swap') _buildReplacementShiftSelector(),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => _reason = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildShiftSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select your shift to swap/cover:'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _selectShift(context, isReplacement: false),
          icon: const Icon(Icons.calendar_today),
          label: Text(_selectedShift != null
              ? '${_selectedShift!.formattedDate} ${_selectedShift!.formattedTimeRange}'
              : 'Choose Shift'),
        ),
      ],
    );
  }

  Widget _buildReplacementShiftSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Select shift you want in exchange:'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _selectShift(context, isReplacement: true),
          icon: const Icon(Icons.calendar_today),
          label: Text(_replacementShift != null
              ? '${_replacementShift!.formattedDate} ${_replacementShift!.formattedTimeRange}'
              : 'Choose Replacement Shift'),
        ),
      ],
    );
  }

  Future<void> _selectShift(BuildContext context,
      {required bool isReplacement}) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch upcoming shifts for the user
      final shifts = await _scheduleService.getUpcomingShifts(widget.userId);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading indicator

      if (shifts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No upcoming shifts found. Shifts must be published to appear here.'),
          ),
        );
        return;
      }

      // Show shift selection dialog
      final selectedShift = await showDialog<ShiftModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isReplacement ? 'Select Replacement Shift' : 'Select Your Shift'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shifts.length,
              itemBuilder: (context, index) {
                final shift = shifts[index];
                return ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(shift.formattedDate),
                  subtitle: Text(shift.formattedTimeRange),
                  onTap: () => Navigator.pop(context, shift),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedShift != null) {
        setState(() {
          if (isReplacement) {
            _replacementShift = selectedShift;
          } else {
            _selectedShift = selectedShift;
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading shifts: $e')),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shift')),
      );
      return;
    }

    if (_requestType == 'swap' && _replacementShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a replacement shift for swap')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_requestType == 'coverage') {
        await _service.createCoverageRequest(
          requesterId: widget.userId,
          requesterName: widget.userName,
          originalShift: _selectedShift!,
          targetEmployeeId: _targetEmployee?.id,
          targetEmployeeName: _targetEmployee?.fullName,
          reason: _reason.isEmpty ? null : _reason,
          companyId: widget.companyId,
        );
      } else {
        if (_targetEmployee == null || _replacementShift == null) {
          throw Exception('Target employee and replacement shift required for swap');
        }

        await _service.createSwapRequest(
          requesterId: widget.userId,
          requesterName: widget.userName,
          originalShift: _selectedShift!,
          targetEmployeeId: _targetEmployee!.id,
          targetEmployeeName: _targetEmployee!.fullName ?? '',
          replacementShift: _replacementShift!,
          reason: _reason.isEmpty ? null : _reason,
          companyId: widget.companyId,
        );
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
