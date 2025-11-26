import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/account_manager.dart';
import '../../services/account_manager_service.dart';
import 'customer_detail_screen.dart';

class AssignCustomersScreen extends StatefulWidget {
  final int initialTab;
  final bool showTabs;

  const AssignCustomersScreen({
    Key? key,
    this.initialTab = 0,
    this.showTabs = true,
  }) : super(key: key);

  @override
  State<AssignCustomersScreen> createState() => _AssignCustomersScreenState();
}

class _AssignCustomersScreenState extends State<AssignCustomersScreen>
    with SingleTickerProviderStateMixin {
  final AccountManagerService _amService = AccountManagerService();
  late TabController _tabController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.initialTab == 0
        ? 'Assign Customers'
        : widget.initialTab == 2
            ? 'Active Members'
            : 'All Companies';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: widget.showTabs
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue[700],
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    indicator: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.blue[700]!,
                          width: 3,
                        ),
                      ),
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.warning_amber, size: 20),
                        text: 'Unassigned',
                      ),
                      Tab(
                        icon: Icon(Icons.business, size: 20),
                        text: 'All Companies',
                      ),
                      Tab(
                        icon: Icon(Icons.people, size: 20),
                        text: 'By Manager',
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search companies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Tabs Content
          Expanded(
            child: widget.showTabs
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUnassignedCompanies(),
                      _buildAllCompanies(),
                      _buildByAccountManager(),
                    ],
                  )
                : widget.initialTab == 0
                    ? _buildUnassignedCompanies()
                    : widget.initialTab == 2
                        ? _buildByAccountManager()
                        : _buildAllCompanies(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedCompanies() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .where('status', whereIn: ['active', 'trial'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Filter unassigned companies
        final companies = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hasAccountManager = data.containsKey('assignedAccountManager');
          final businessName =
              (data['businessName'] ?? '').toString().toLowerCase();
          final matchesSearch =
              _searchQuery.isEmpty || businessName.contains(_searchQuery);
          return !hasAccountManager && matchesSearch;
        }).toList() ??
            [];

        if (companies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'All companies are assigned!'
                      : 'No matching unassigned companies',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final doc = companies[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildCompanyCard(doc.id, data, null);
          },
        );
      },
    );
  }

  Widget _buildAllCompanies() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .orderBy('businessName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Filter by search
        final companies = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final businessName =
              (data['businessName'] ?? '').toString().toLowerCase();
          return _searchQuery.isEmpty || businessName.contains(_searchQuery);
        }).toList() ??
            [];

        if (companies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No companies found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final doc = companies[index];
            final data = doc.data() as Map<String, dynamic>;
            final assignedAM = data['assignedAccountManager'] as Map?;
            return _buildCompanyCard(doc.id, data, assignedAM);
          },
        );
      },
    );
  }

  Widget _buildCompanyCard(
    String companyId,
    Map<String, dynamic> data,
    Map? assignedAM,
  ) {
    final businessName = data['businessName'] ?? 'Unknown Company';
    final status = data['status'] ?? 'unknown';
    final subscriptionPlan = data['subscriptionPlan'] ?? 'unknown';

    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'trial':
        statusColor = Colors.orange;
        break;
      case 'inactive':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerDetailScreen(
                      companyId: companyId,
                      companyData: data,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              subscriptionPlan.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
              if (assignedAM != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _showAssignOptions(companyId, businessName, assignedAM),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assigned to ${assignedAM['name']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          'CHANGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _showAssignOptions(companyId, businessName, null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Not assigned to Account Manager',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          'ASSIGN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }

  Future<void> _showAssignOptions(
    String companyId,
    String companyName,
    Map? currentAM,
  ) async {
    // Get available Account Managers
    final availableAMs = await _amService.getAccountManagersWithCapacity();

    if (!mounted) return;

    // Build menu items
    final List<PopupMenuEntry<dynamic>> menuItems = [];

    // Add unassign option if currently assigned
    if (currentAM != null) {
      menuItems.add(
        PopupMenuItem<String>(
          value: 'unassign',
          child: Row(
            children: [
              const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Text(
                'Unassign from ${currentAM['name']}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
      menuItems.add(const PopupMenuDivider());
    }

    // Add assign/reassign options
    if (availableAMs.isNotEmpty) {
      menuItems.add(
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            currentAM != null ? 'Reassign to:' : 'Assign to:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
      );

      for (final am in availableAMs) {
        final capacity = am.capacityPercentage;
        Color capacityColor;
        if (capacity >= 90) {
          capacityColor = Colors.red;
        } else if (capacity >= 75) {
          capacityColor = Colors.orange;
        } else {
          capacityColor = Colors.green;
        }

        menuItems.add(
          PopupMenuItem<AccountManager>(
            value: am,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 16,
                  child: Text(
                    am.displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        am.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${am.assignedCount}/${am.maxAssignedCompanies} (${capacity.toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 11, color: capacityColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      menuItems.add(
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.warning, size: 16, color: Colors.orange[300]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'All Account Managers at capacity',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show menu
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button!.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<dynamic>(
      context: context,
      position: position,
      items: menuItems,
    );

    if (selected == null) return; // User cancelled

    try {
      if (selected == 'unassign') {
        // Unassign
        await _amService.unassignCompanyFromManager(
          accountManagerId: currentAM!['id'],
          companyId: companyId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$companyName unassigned')),
          );
        }
      } else if (selected is AccountManager) {
        // Assign or reassign
        if (currentAM != null) {
          // Reassign
          await _amService.reassignCompany(
            companyId: companyId,
            newAccountManagerId: selected.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('$companyName reassigned to ${selected.displayName}'),
              ),
            );
          }
        } else {
          // New assignment
          await _amService.assignCompanyToManager(
            accountManagerId: selected.id,
            companyId: companyId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('$companyName assigned to ${selected.displayName}'),
              ),
            );
          }
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

  Widget _buildByAccountManager() {
    return StreamBuilder<List<AccountManager>>(
      stream: _amService.getAccountManagersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final accountManagers = snapshot.data ?? [];

        if (accountManagers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Account Managers',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accountManagers.length,
          itemBuilder: (context, index) {
            final am = accountManagers[index];
            return _buildAccountManagerCard(am);
          },
        );
      },
    );
  }

  Widget _buildAccountManagerCard(AccountManager am) {
    final capacity = am.capacityPercentage;
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
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            am.displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          am.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${am.assignedCount}/${am.maxAssignedCompanies} customers (${capacity.toStringAsFixed(0)}%)',
          style: TextStyle(color: capacityColor),
        ),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('companies')
                .where('assignedAccountManager.id', isEqualTo: am.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final companies = snapshot.data?.docs ?? [];

              if (companies.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No assigned customers',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              return Column(
                children: companies.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final assignedAM = data['assignedAccountManager'] as Map?;
                  return _buildCompanyCard(doc.id, data, assignedAM);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
