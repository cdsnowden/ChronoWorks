import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/shift_swap_request_model.dart';
import '../../services/shift_swap_request_service.dart';
import '../../services/auth_provider.dart';

class ShiftSwapApprovalScreen extends StatefulWidget {
  const ShiftSwapApprovalScreen({Key? key}) : super(key: key);

  @override
  State<ShiftSwapApprovalScreen> createState() =>
      _ShiftSwapApprovalScreenState();
}

class _ShiftSwapApprovalScreenState extends State<ShiftSwapApprovalScreen> {
  final ShiftSwapRequestService _service = ShiftSwapRequestService();
  String _filterStatus = 'pending'; // pending, approved, denied, all
  String _filterType = 'all'; // all, swap, coverage
  String _searchQuery = '';
  String _sortBy = 'date'; // date, employee, type

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shift Swap Approvals')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Swap Approvals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showStatistics(user.companyId),
            tooltip: 'Statistics',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSearchBar(),
          Expanded(child: _buildRequestsList(user)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter by Status:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('Pending', 'pending'),
              _buildFilterChip('Approved', 'approved'),
              _buildFilterChip('Denied', 'denied'),
              _buildFilterChip('All', 'all'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Filter by Type:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildTypeFilterChip('All', 'all'),
              _buildTypeFilterChip('Swaps', 'swap'),
              _buildTypeFilterChip('Coverage', 'coverage'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
    );
  }

  Widget _buildTypeFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterType = value);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by employee name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
              const PopupMenuItem(
                  value: 'employee', child: Text('Sort by Employee')),
              const PopupMenuItem(value: 'type', child: Text('Sort by Type')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(user) {
    return StreamBuilder<List<ShiftSwapRequestModel>>(
      stream: _filterStatus == 'all'
          ? _service.getAllCompanyRequests(user.companyId)
          : _filterStatus == 'pending'
              ? _service.getPendingRequests(user.companyId)
              : _service.getAllCompanyRequests(user.companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var requests = snapshot.data ?? [];

        // Apply filters
        if (_filterStatus != 'all' && _filterStatus != 'pending') {
          requests = requests.where((r) => r.status == _filterStatus).toList();
        }

        if (_filterType != 'all') {
          requests =
              requests.where((r) => r.requestType == _filterType).toList();
        }

        if (_searchQuery.isNotEmpty) {
          requests = requests
              .where((r) =>
                  r.requesterName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  (r.targetEmployeeName?.toLowerCase() ?? '')
                      .contains(_searchQuery.toLowerCase()))
              .toList();
        }

        // Apply sorting
        switch (_sortBy) {
          case 'employee':
            requests.sort((a, b) => a.requesterName.compareTo(b.requesterName));
            break;
          case 'type':
            requests.sort((a, b) => a.requestType.compareTo(b.requestType));
            break;
          case 'date':
          default:
            requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No requests found',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _buildRequestCard(requests[index], user);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(ShiftSwapRequestModel request, user) {
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  request.isSwap ? Icons.swap_horiz : Icons.person_search,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.requestTypeLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(request.statusLabel),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Employee', request.requesterName),
            _buildDetailRow('Original Shift', request.formattedOriginalShift),
            if (request.targetEmployeeName != null)
              _buildDetailRow(
                  request.isSwap ? 'Swap With' : 'Coverage By',
                  request.targetEmployeeName!),
            if (request.isSwap && request.replacementShiftDate != null)
              _buildDetailRow(
                  'Replacement Shift', request.formattedReplacementShift),
            if (request.reason != null && request.reason!.isNotEmpty)
              _buildDetailRow('Reason', request.reason!),
            _buildDetailRow('Created',
                request.createdAt.toString().split('.')[0].substring(0, 16)),
            if (request.isPending) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDenyRequest(request, user),
                      icon: const Icon(Icons.close),
                      label: const Text('Deny'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleApproveRequest(request, user),
                      icon: const Icon(Icons.check),
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
            if (!request.isPending && request.reviewedAt != null) ...[
              const Divider(height: 24),
              _buildDetailRow('Reviewed',
                  request.reviewedAt.toString().split('.')[0].substring(0, 16)),
              if (request.reviewerName != null)
                _buildDetailRow('Reviewed By', request.reviewerName!),
              if (request.reviewNotes != null && request.reviewNotes!.isNotEmpty)
                _buildDetailRow('Notes', request.reviewNotes!),
            ],
          ],
        ),
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
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApproveRequest(
      ShiftSwapRequestModel request, user) async {
    final notesController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approve ${request.requestTypeLabel.toLowerCase()} request from ${request.requesterName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _service.approveRequest(
          requestId: request.id,
          reviewerId: user.uid,
          reviewerName: user.displayName ?? 'Unknown',
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
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleDenyRequest(
      ShiftSwapRequestModel request, user) async {
    final notesController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deny ${request.requestTypeLabel.toLowerCase()} request from ${request.requesterName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Reason for denial',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _service.denyRequest(
          requestId: request.id,
          reviewerId: user.uid,
          reviewerName: user.displayName ?? 'Unknown',
          reviewNotes: notesController.text.isEmpty ? null : notesController.text,
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
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showStatistics(String companyId) async {
    try {
      final stats = await _service.getCompanyStatistics(companyId);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shift Swap Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Total Requests', stats['total'].toString()),
              const Divider(),
              _buildStatRow('Pending', stats['pending'].toString(),
                  color: Colors.orange),
              _buildStatRow('Approved', stats['approved'].toString(),
                  color: Colors.green),
              _buildStatRow('Denied', stats['denied'].toString(),
                  color: Colors.red),
              _buildStatRow('Cancelled', stats['cancelled'].toString(),
                  color: Colors.grey),
              const Divider(),
              _buildStatRow('Swap Requests', stats['swaps'].toString()),
              _buildStatRow('Coverage Requests', stats['coverage'].toString()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading statistics: $e')),
      );
    }
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
