import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_detail_screen.dart';

/// Screen showing all active members (customers with assigned Account Managers)
class ActiveMembersScreen extends StatefulWidget {
  const ActiveMembersScreen({Key? key}) : super(key: key);

  @override
  State<ActiveMembersScreen> createState() => _ActiveMembersScreenState();
}

class _ActiveMembersScreenState extends State<ActiveMembersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Members'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Customer List
          Expanded(
            child: _buildCustomerList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('companies')
          .where('assignedAccountManager', isNull: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No active members yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Assign customers to Account Managers to see them here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Filter companies based on search query
        var companies = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final businessName = (data['businessName'] ?? '').toLowerCase();
          final ownerName = (data['ownerName'] ?? '').toLowerCase();
          final ownerEmail = (data['ownerEmail'] ?? '').toLowerCase();
          final amName = data.containsKey('assignedAccountManager')
              ? (data['assignedAccountManager']['name'] ?? '').toLowerCase()
              : '';

          return businessName.contains(_searchQuery) ||
              ownerName.contains(_searchQuery) ||
              ownerEmail.contains(_searchQuery) ||
              amName.contains(_searchQuery);
        }).toList();

        // Sort companies by business name
        companies.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = (aData['businessName'] ?? '').toString().toLowerCase();
          final bName = (bData['businessName'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

        if (companies.isEmpty) {
          return const Center(
            child: Text(
              'No customers match your search',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: companies.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final doc = companies[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildCustomerCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildCustomerCard(String companyId, Map<String, dynamic> data) {
    final businessName = data['businessName'] ?? 'Unknown Business';
    final ownerName = data['ownerName'] ?? 'Unknown Owner';
    final ownerEmail = data['ownerEmail'] ?? '';
    final currentPlan = data['currentPlan'] ?? 'free';
    final status = data['status'] ?? 'active';

    // Get Account Manager info
    final amData = data['assignedAccountManager'] as Map<String, dynamic>?;
    final amName = amData?['name'] ?? 'Not Assigned';
    final amEmail = amData?['email'] ?? '';

    // Get creation date
    final createdAt = data['createdAt'] as Timestamp?;
    final createdDate = createdAt?.toDate();
    final formattedDate = createdDate != null
        ? '${createdDate.month}/${createdDate.day}/${createdDate.year}'
        : 'N/A';

    // Determine status color
    Color statusColor = Colors.green;
    if (status == 'trial') {
      statusColor = Colors.orange;
    } else if (status == 'inactive' || status == 'suspended') {
      statusColor = Colors.red;
    }

    // Determine plan color
    Color planColor = Colors.grey;
    if (currentPlan == 'pro' || currentPlan == 'premium') {
      planColor = Colors.blue;
    } else if (currentPlan == 'trial') {
      planColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Navigate to customer detail screen
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business Name and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      businessName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
              const SizedBox(height: 8),

              // Owner Information
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    ownerName,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (ownerEmail.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ownerEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Account Manager Information
              Row(
                children: [
                  const Icon(Icons.support_agent, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'AM: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      amName,
                      style: const TextStyle(fontSize: 14, color: Colors.blue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Plan and Join Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Plan Badge
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

                  // Join Date
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Joined: $formattedDate',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
