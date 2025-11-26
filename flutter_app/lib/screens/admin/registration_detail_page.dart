import 'package:flutter/material.dart';
import '../../models/registration_request.dart';
import '../../services/admin_service.dart';
import '../super_admin/assign_customers_screen.dart';

/// Detailed view of a single registration request
class RegistrationDetailPage extends StatefulWidget {
  final RegistrationRequest request;

  const RegistrationDetailPage({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<RegistrationDetailPage> createState() => _RegistrationDetailPageState();
}

class _RegistrationDetailPageState extends State<RegistrationDetailPage> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status banner
              _buildStatusBanner(),

              const SizedBox(height: 24),

              // Business Information section
              _buildSection(
                'Business Information',
                Icons.business,
                [
                  _buildDetailRow('Business Name', widget.request.businessName),
                  _buildDetailRow('Industry', widget.request.industry),
                  _buildDetailRow(
                    'Number of Employees',
                    '${widget.request.numberOfEmployees}',
                  ),
                  if (widget.request.website != null)
                    _buildDetailRow('Website', widget.request.website!),
                ],
              ),

              const SizedBox(height: 16),

              // Owner Information section
              _buildSection(
                'Owner Information',
                Icons.person,
                [
                  _buildDetailRow('Full Name', widget.request.ownerName),
                  _buildDetailRow('Email', widget.request.ownerEmail),
                  _buildDetailRow('Phone', widget.request.ownerPhone),
                  if (widget.request.jobTitle != null)
                    _buildDetailRow('Job Title', widget.request.jobTitle!),
                ],
              ),

              const SizedBox(height: 16),

              // Business Address section
              _buildSection(
                'Business Address',
                Icons.location_on,
                [
                  _buildDetailRow('Street', widget.request.address.street),
                  _buildDetailRow('City', widget.request.address.city),
                  _buildDetailRow('State', widget.request.address.state),
                  _buildDetailRow('ZIP Code', widget.request.address.zip),
                  _buildDetailRow('Timezone', widget.request.timezone),
                  _buildDetailRow(
                    'Full Address',
                    widget.request.address.toString(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Request Metadata section
              _buildSection(
                'Request Metadata',
                Icons.info,
                [
                  _buildDetailRow(
                    'Submitted',
                    _formatDateTime(widget.request.submittedAt),
                  ),
                  _buildDetailRow('Status', widget.request.status.toUpperCase()),
                  if (widget.request.approvedBy != null) ...[
                    _buildDetailRow('Approved By', widget.request.approvedBy!),
                    _buildDetailRow(
                      'Approved At',
                      _formatDateTime(widget.request.approvedAt),
                    ),
                  ],
                  if (widget.request.rejectedBy != null) ...[
                    _buildDetailRow('Rejected By', widget.request.rejectedBy!),
                    _buildDetailRow(
                      'Rejected At',
                      _formatDateTime(widget.request.rejectedAt),
                    ),
                    if (widget.request.rejectionReason != null)
                      _buildDetailRow(
                        'Rejection Reason',
                        widget.request.rejectionReason!,
                      ),
                  ],
                  if (widget.request.companyId != null)
                    _buildDetailRow('Company ID', widget.request.companyId!),
                ],
              ),

              const SizedBox(height: 24),

              // Action buttons
              if (widget.request.status == 'pending')
                _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the status banner at the top
  Widget _buildStatusBanner() {
    Color color;
    IconData icon;
    String message;

    switch (widget.request.status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        message = 'This registration is awaiting your approval';
        break;
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        message = 'This registration has been approved';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        message = 'This registration has been rejected';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        message = 'Unknown status';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a section with a title and content
  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Builds a detail row with label and value
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Formats a DateTime for display
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Builds action buttons for pending requests
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRejectDialog(),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text(
              'Reject',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showApproveDialog(),
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Shows approve confirmation dialog
  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Registration?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint('Create a company account'),
            _buildBulletPoint('Create owner user account'),
            _buildBulletPoint('Send welcome email with credentials'),
            _buildBulletPoint('Start 30-day full trial'),
            const SizedBox(height: 16),
            Text(
              'Company: ${widget.request.businessName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Owner: ${widget.request.ownerName}'),
            Text('Email: ${widget.request.ownerEmail}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _approveRequest();
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  /// Builds a bullet point for dialogs
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  /// Shows reject dialog with reason input
  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting: ${widget.request.businessName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Required)',
                hintText: 'Why is this registration being rejected?',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'The applicant will receive an email with this reason.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              await _rejectRequest(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  /// Approves the registration request
  Future<void> _approveRequest() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Approving registration...'),
              SizedBox(height: 8),
              Text(
                'This may take a moment',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      await _adminService.approveRegistration(widget.request.requestId!);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success dialog with option to assign account manager
      final shouldAssign = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 32),
              const SizedBox(width: 12),
              const Expanded(child: Text('Registration Approved!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.request.businessName} has been approved successfully.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Would you like to assign an Account Manager to this company now?',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Assign Now'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (shouldAssign == true) {
        // Navigate to assign customers screen (unassigned tab)
        Navigator.of(context).pop(); // Go back to list first
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AssignCustomersScreen(
              initialTab: 0, // Unassigned tab
            ),
          ),
        );
      } else {
        // Just go back to list
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.request.businessName} approved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to approve registration:\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Rejects the registration request
  Future<void> _rejectRequest(String reason) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Rejecting registration...'),
            ],
          ),
        ),
      );

      await _adminService.rejectRegistration(widget.request.requestId!, reason);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      Navigator.of(context).pop(); // Go back to list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.request.businessName} rejected'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to reject registration:\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
