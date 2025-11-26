import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/super_admin_service.dart';
import '../../services/account_manager_service.dart';
import '../../models/account_manager.dart';

/// Screen showing detailed information about a customer/company
class CustomerDetailScreen extends StatefulWidget {
  final String companyId;
  final Map<String, dynamic> companyData;

  const CustomerDetailScreen({
    Key? key,
    required this.companyId,
    required this.companyData,
  }) : super(key: key);

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SuperAdminService _superAdminService = SuperAdminService();
  final AccountManagerService _amService = AccountManagerService();
  bool _isDeleting = false;

  Future<void> _deleteCompany(Map<String, dynamic> companyData) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text(
          'Are you sure you want to delete "${companyData['businessName']}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _superAdminService.deleteCompany(widget.companyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${companyData['businessName']} has been deleted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting company: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.companyData['businessName'] ?? 'Customer Details'),
        backgroundColor: Colors.green,
        actions: [
          if (!_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteCompany(widget.companyData),
              tooltip: 'Delete Company',
            ),
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('companies')
            .doc(widget.companyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Company not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBusinessInfoSection(data),
                  const SizedBox(height: 24),
                  _buildOwnerInfoSection(data),
                  const SizedBox(height: 24),
                  _buildAccountManagerSection(data),
                  const SizedBox(height: 24),
                  _buildSubscriptionSection(data),
                  const SizedBox(height: 24),
                  _buildActivitySection(data),
                  const SizedBox(height: 24),
                  _buildAdditionalInfoSection(data),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusinessInfoSection(Map<String, dynamic> data) {
    final businessName = data['businessName'] ?? 'Unknown Business';
    final phoneNumber = data['phoneNumber'] ?? 'N/A';

    // Handle address which might be an object
    String address;
    if (data['address'] is Map) {
      final addr = data['address'] as Map;
      final street = addr['street'] ?? '';
      final city = addr['city'] ?? '';
      final state = addr['state'] ?? '';
      final zip = addr['zip'] ?? '';
      address = '$street, $city, $state $zip'.trim();
      if (address.isEmpty || address == ', ,') {
        address = 'N/A';
      }
    } else {
      address = data['address']?.toString() ?? 'N/A';
    }

    final status = data['status'] ?? 'active';

    Color statusColor = Colors.green;
    if (status == 'trial') {
      statusColor = Colors.orange;
    } else if (status == 'inactive' || status == 'suspended') {
      statusColor = Colors.red;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.business, 'Business Name', businessName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Phone Number', phoneNumber),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Address', address),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerInfoSection(Map<String, dynamic> data) {
    final ownerName = data['ownerName'] ?? 'Unknown Owner';
    final ownerEmail = data['ownerEmail'] ?? 'N/A';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Owner Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Owner Name', ownerName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email, 'Email', ownerEmail),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountManagerSection(Map<String, dynamic> data) {
    final amData = data['assignedAccountManager'] as Map<String, dynamic>?;

    if (amData == null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Account Manager',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAssignAccountManagerDialog(null),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Assign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'No Account Manager Assigned',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final amName = amData['name'] ?? 'Unknown';
    final amEmail = amData['email'] ?? 'N/A';
    final amId = amData['id'] ?? '';
    final assignedAt = amData['assignedAt'] as Timestamp?;
    final assignedDate = assignedAt?.toDate();
    final formattedAssignedDate = assignedDate != null
        ? '${assignedDate.month}/${assignedDate.day}/${assignedDate.year}'
        : 'N/A';

    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.support_agent, color: Colors.blue, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      'Account Manager',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAssignAccountManagerDialog(amData),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Change'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Name', amName, color: Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email, 'Email', amEmail, color: Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Assigned Date',
              formattedAssignedDate,
              color: Colors.blue,
            ),
            if (amId.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.badge, 'AM ID', amId, color: Colors.blue),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection(Map<String, dynamic> data) {
    final currentPlan = data['currentPlan'] ?? 'free';
    final subscriptionPlan = data['subscriptionPlan'] ?? 'N/A';
    final maxEmployees = data['maxEmployees']?.toString() ?? 'Unlimited';

    // Get subscription start/end dates if they exist
    final subscriptionStart = data['subscriptionStartDate'] as Timestamp?;
    final subscriptionEnd = data['subscriptionEndDate'] as Timestamp?;

    final startDate = subscriptionStart?.toDate();
    final endDate = subscriptionEnd?.toDate();

    final formattedStartDate = startDate != null
        ? '${startDate.month}/${startDate.day}/${startDate.year}'
        : 'N/A';
    final formattedEndDate = endDate != null
        ? '${endDate.month}/${endDate.day}/${endDate.year}'
        : 'N/A';

    // Get custom pricing if exists
    final customPricing = data['customPricing'] as Map<String, dynamic>?;
    final hasCustomPricing = customPricing?['enabled'] == true;

    Color planColor = Colors.grey;
    if (currentPlan == 'pro' || currentPlan == 'premium') {
      planColor = Colors.blue;
    } else if (currentPlan == 'trial') {
      planColor = Colors.orange;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subscription',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showCustomPricingDialog(data),
                      icon: Icon(
                        hasCustomPricing ? Icons.edit : Icons.attach_money,
                        size: 18,
                      ),
                      label: Text(
                        hasCustomPricing ? 'Edit Pricing' : 'Set Custom',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCustomPricing ? Colors.orange : Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: planColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: planColor),
                      ),
                      child: Text(
                        currentPlan.toUpperCase(),
                        style: TextStyle(
                          color: planColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.star, 'Current Plan', currentPlan),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.description, 'Subscription Plan', subscriptionPlan),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.people, 'Max Employees', maxEmployees),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Start Date', formattedStartDate),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'End Date', formattedEndDate),
            if (hasCustomPricing) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Custom Pricing Active',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monthly: \$${customPricing?['monthlyPrice']?.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Yearly: \$${customPricing?['yearlyPrice']?.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (customPricing?['notes'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Notes: ${customPricing?['notes']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomPricingDialog(Map<String, dynamic> companyData) async {
    final customPricing = companyData['customPricing'] as Map<String, dynamic>?;
    final currentMonthly = customPricing?['monthlyPrice']?.toString() ?? '';
    final currentYearly = customPricing?['yearlyPrice']?.toString() ?? '';
    final currentNotes = customPricing?['notes']?.toString() ?? '';

    final monthlyController = TextEditingController(text: currentMonthly);
    final yearlyController = TextEditingController(text: currentYearly);
    final notesController = TextEditingController(text: currentNotes);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Custom Pricing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Override standard plan pricing for this customer:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: monthlyController,
                decoration: const InputDecoration(
                  labelText: 'Monthly Price (\$)',
                  hintText: '99.99',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearlyController,
                decoration: const InputDecoration(
                  labelText: 'Yearly Price (\$)',
                  hintText: '999.99',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Reason for custom pricing',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          if (customPricing?['enabled'] == true)
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) {
      // Remove custom pricing
      await _removeCustomPricing();
    } else if (result == true) {
      // Save custom pricing
      await _saveCustomPricing(
        monthlyController.text,
        yearlyController.text,
        notesController.text,
      );
    }
  }

  Future<void> _saveCustomPricing(
    String monthly,
    String yearly,
    String notes,
  ) async {
    try {
      final monthlyPrice = double.tryParse(monthly);
      final yearlyPrice = double.tryParse(yearly);

      if (monthlyPrice == null || yearlyPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid prices'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _firestore.collection('companies').doc(widget.companyId).update({
        'customPricing': {
          'enabled': true,
          'monthlyPrice': monthlyPrice,
          'yearlyPrice': yearlyPrice,
          'notes': notes.trim(),
          'appliedBy': FirebaseAuth.instance.currentUser?.uid,
          'appliedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom pricing saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving custom pricing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeCustomPricing() async {
    try {
      await _firestore.collection('companies').doc(widget.companyId).update({
        'customPricing': {
          'enabled': false,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom pricing removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing custom pricing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildActivitySection(Map<String, dynamic> data) {
    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;

    final createdDate = createdAt?.toDate();
    final updatedDate = updatedAt?.toDate();

    final formattedCreatedDate = createdDate != null
        ? '${createdDate.month}/${createdDate.day}/${createdDate.year} at ${createdDate.hour}:${createdDate.minute.toString().padLeft(2, '0')}'
        : 'N/A';
    final formattedUpdatedDate = updatedDate != null
        ? '${updatedDate.month}/${updatedDate.day}/${updatedDate.year} at ${updatedDate.hour}:${updatedDate.minute.toString().padLeft(2, '0')}'
        : 'N/A';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Created At', formattedCreatedDate),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.update, 'Last Updated', formattedUpdatedDate),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection(Map<String, dynamic> data) {
    final companyId = widget.companyId;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fingerprint, 'Company ID', companyId),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.verified_user,
              'Verification Status',
              data['verificationStatus'] ?? 'Not Verified',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? color}) {
    final textColor = color ?? Colors.black87;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: textColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAssignAccountManagerDialog(Map<String, dynamic>? currentAM) async {
    // Get available account managers
    final availableAMs = await _amService.getAccountManagersWithCapacity();

    if (!mounted) return;

    final businessName = widget.companyData['businessName'] ?? 'this company';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentAM == null ? 'Assign Account Manager' : 'Change Account Manager'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentAM == null
                    ? 'Select an Account Manager for $businessName:'
                    : 'Current: ${currentAM['name']}\n\nSelect new Account Manager:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (availableAMs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No Account Managers available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableAMs.length,
                    itemBuilder: (context, index) {
                      final am = availableAMs[index];
                      final capacity = am.capacityPercentage;
                      Color capacityColor;
                      if (capacity >= 90) {
                        capacityColor = Colors.red;
                      } else if (capacity >= 75) {
                        capacityColor = Colors.orange;
                      } else {
                        capacityColor = Colors.green;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            am.displayName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(am.displayName),
                        subtitle: Text(
                          '${am.assignedCount}/${am.maxAssignedCompanies} customers (${capacity.toStringAsFixed(0)}%)',
                          style: TextStyle(color: capacityColor),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _assignAccountManager(am, currentAM);
                        },
                      );
                    },
                  ),
                ),
              if (currentAM != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.remove_circle, color: Colors.red),
                  title: const Text(
                    'Unassign Account Manager',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _unassignAccountManager(currentAM);
                  },
                ),
              ],
            ],
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
  }

  Future<void> _assignAccountManager(
    AccountManager am,
    Map<String, dynamic>? currentAM,
  ) async {
    try {
      if (currentAM != null) {
        // Reassign
        await _amService.reassignCompany(
          companyId: widget.companyId,
          newAccountManagerId: am.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Account Manager changed to ${am.displayName}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // New assignment
        await _amService.assignCompanyToManager(
          accountManagerId: am.id,
          companyId: widget.companyId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${widget.companyData['businessName']} assigned to ${am.displayName}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unassignAccountManager(Map<String, dynamic> currentAM) async {
    try {
      await _amService.unassignCompanyFromManager(
        accountManagerId: currentAM['id'],
        companyId: widget.companyId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account Manager unassigned from ${widget.companyData['businessName']}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
