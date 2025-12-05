import 'package:flutter/material.dart';
import '../../models/account_manager.dart';
import '../../services/account_manager_service.dart';
import 'create_account_manager_screen.dart';
import '../account_manager/assigned_companies_screen.dart';

class AccountManagersListScreen extends StatefulWidget {
  const AccountManagersListScreen({Key? key}) : super(key: key);

  @override
  State<AccountManagersListScreen> createState() =>
      _AccountManagersListScreenState();
}

class _AccountManagersListScreenState extends State<AccountManagersListScreen> {
  final AccountManagerService _amService = AccountManagerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Managers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: StreamBuilder<List<AccountManager>>(
        stream: _amService.getAllAccountManagers(),
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final accountManagers = snapshot.data ?? [];

          if (accountManagers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Account Managers yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CreateAccountManagerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Account Manager'),
                  ),
                ],
              ),
            );
          }

          // Calculate totals
          int totalCustomers = 0;
          int activeCustomers = 0;
          int atCapacity = 0;

          for (var am in accountManagers) {
            totalCustomers += am.assignedCount;
            activeCustomers += am.metrics?.activeCustomers ?? 0;
            if (am.isAtCapacity) atCapacity++;
          }

          return Column(
            children: [
              // Summary Cards
              Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Account Managers',
                        accountManagers.length.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Customers',
                        totalCustomers.toString(),
                        Icons.business,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'At Capacity',
                        atCapacity.toString(),
                        Icons.warning,
                        atCapacity > 0 ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Account Managers List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: accountManagers.length,
                  itemBuilder: (context, index) {
                    return _buildAccountManagerCard(accountManagers[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateAccountManagerScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Account Manager'),
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
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
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountManagerCard(AccountManager am) {
    final capacity = am.capacityPercentage;
    final isAtCapacity = am.isAtCapacity;

    Color capacityColor;
    if (capacity >= 90) {
      capacityColor = Colors.red;
    } else if (capacity >= 75) {
      capacityColor = Colors.orange;
    } else {
      capacityColor = Colors.green;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAccountManagerOptions(context, am),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    backgroundImage:
                        am.photoURL != null ? NetworkImage(am.photoURL!) : null,
                    child: am.photoURL == null
                        ? Text(
                            am.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          am.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          am.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: am.status == 'active'
                                    ? Colors.green[100]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                am.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: am.status == 'active'
                                      ? Colors.green[800]
                                      : Colors.grey[800],
                                ),
                              ),
                            ),
                            if (isAtCapacity) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning,
                                        size: 12, color: Colors.red[800]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'AT CAPACITY',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Metrics Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricColumn(
                    'Assigned',
                    '${am.assignedCount}/${am.maxAssignedCompanies}',
                    Icons.business,
                    Colors.blue,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildMetricColumn(
                    'Active',
                    '${am.metrics?.activeCustomers ?? 0}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildMetricColumn(
                    'Trial',
                    '${am.metrics?.trialCustomers ?? 0}',
                    Icons.timer,
                    Colors.orange,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildMetricColumn(
                    'Paid',
                    '${am.metrics?.paidCustomers ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Capacity Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Capacity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${capacity.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: capacityColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: capacity / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(capacityColor),
                    minHeight: 6,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showAccountManagerOptions(BuildContext context, AccountManager am) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                am.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('View Assigned Companies'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AssignedCompaniesScreen(accountManagerId: am.id),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(am);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Increase Capacity'),
              onTap: () {
                Navigator.pop(context);
                _showIncreaseCapacityDialog(am);
              },
            ),
            ListTile(
              leading: Icon(
                am.status == 'active' ? Icons.pause_circle : Icons.play_circle,
                color: am.status == 'active' ? Colors.orange : Colors.green,
              ),
              title: Text(
                  am.status == 'active' ? 'Deactivate' : 'Reactivate'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  if (am.status == 'active') {
                    await _amService.deactivateAccountManager(am.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('${am.displayName} deactivated')),
                      );
                    }
                  } else {
                    await _amService.reactivateAccountManager(am.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('${am.displayName} reactivated')),
                      );
                    }
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
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account Manager', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteAccountManager(am);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccountManager(AccountManager am) async {
    // Check if AM has assigned companies
    if (am.assignedCount > 0) {
      final reassign = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Text(
            '${am.displayName} has ${am.assignedCount} assigned ${am.assignedCount == 1 ? 'company' : 'companies'}.\n\n'
            'You must reassign all companies to another Account Manager before deleting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account Manager'),
        content: Text(
          'Are you sure you want to PERMANENTLY DELETE "${am.displayName}"?\n\n'
          'WARNING: This action cannot be undone!\n\n'
          'This will:\n'
          '• Delete the account manager profile\n'
          '• Remove their user account\n'
          '• Delete all associated data',
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _amService.deleteAccountManager(am.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${am.displayName} deleted permanently'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account manager: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showIncreaseCapacityDialog(AccountManager am) async {
    final controller = TextEditingController(
      text: am.maxAssignedCompanies.toString(),
    );

    final newCapacity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Increase Capacity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: ${am.maxAssignedCompanies} customers'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Capacity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > am.maxAssignedCompanies) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newCapacity != null) {
      try {
        await _amService.updateAccountManager(am.id, {
          'maxAssignedCompanies': newCapacity,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Capacity updated to $newCapacity for ${am.displayName}'),
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

    controller.dispose();
  }

  void _showEditProfileDialog(AccountManager am) {
    final displayNameController = TextEditingController(text: am.displayName);
    final phoneController = TextEditingController(text: am.phoneNumber ?? '');
    final capacityController = TextEditingController(text: am.maxAssignedCompanies.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${am.displayName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: capacityController,
                decoration: const InputDecoration(
                  labelText: 'Max Assigned Companies',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _amService.updateAccountManager(am.id, {
                  'displayName': displayNameController.text.trim(),
                  'phoneNumber': phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  'maxAssignedCompanies': int.tryParse(capacityController.text) ?? am.maxAssignedCompanies,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

}
