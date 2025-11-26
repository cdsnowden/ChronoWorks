import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/employee_service.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../routes.dart';
import '../../utils/constants.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _filterRole = 'all';
  bool _showActiveOnly = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.addEmployee);
            },
            tooltip: 'Add Employee',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Filters Row
                Row(
                  children: [
                    // Role Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterRole,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Role',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Roles')),
                          DropdownMenuItem(value: 'admin', child: Text('Admins')),
                          DropdownMenuItem(
                              value: 'manager', child: Text('Managers')),
                          DropdownMenuItem(
                              value: 'employee', child: Text('Employees')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterRole = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Active Filter
                    Expanded(
                      child: FilterChip(
                        label: const Text('Active Only'),
                        selected: _showActiveOnly,
                        onSelected: (value) {
                          setState(() {
                            _showActiveOnly = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Employee List
          Expanded(
            child: Consumer<app_auth.AuthProvider>(
              builder: (context, authProvider, child) {
                final currentUser = authProvider.currentUser;
                if (currentUser == null) {
                  return const Center(child: Text('Not logged in'));
                }

                return StreamBuilder<List<UserModel>>(
                  stream: _employeeService.getEmployeesByCompanyStream(currentUser.companyId),
                  builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter employees
                var employees = snapshot.data!;

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  employees = employees.where((emp) {
                    final fullName = emp.fullName.toLowerCase();
                    final email = emp.email.toLowerCase();
                    return fullName.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                  }).toList();
                }

                // Apply role filter
                if (_filterRole != 'all') {
                  employees =
                      employees.where((emp) => emp.role == _filterRole).toList();
                }

                // Apply active filter
                if (_showActiveOnly) {
                  employees = employees.where((emp) => emp.isActive).toList();
                }

                if (employees.isEmpty) {
                  return _buildNoResultsState();
                }

                return ListView.builder(
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    return _buildEmployeeCard(employees[index]);
                  },
                );
              },
            );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.addEmployee);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Employee'),
      ),
    );
  }

  Widget _buildEmployeeCard(UserModel employee) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(employee.role),
          child: Text(
            employee.firstName[0].toUpperCase() +
                employee.lastName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          employee.fullName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: employee.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employee.email),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildBadge(
                  _getRoleLabel(employee.role),
                  _getRoleColor(employee.role),
                ),
                const SizedBox(width: 8),
                _buildBadge(
                  employee.employmentType == EmploymentTypes.fullTime
                      ? 'Full-Time'
                      : 'Part-Time',
                  Colors.blue,
                ),
                if (employee.isKeyholder) ...[
                  const SizedBox(width: 8),
                  _buildBadge('Keyholder', Colors.purple),
                ],
                if (!employee.isActive) ...[
                  const SizedBox(width: 8),
                  _buildBadge('Inactive', Colors.grey),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, employee),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: employee.isActive ? 'deactivate' : 'reactivate',
              child: Row(
                children: [
                  Icon(employee.isActive ? Icons.block : Icons.check_circle),
                  const SizedBox(width: 8),
                  Text(employee.isActive ? 'Deactivate' : 'Reactivate'),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to employee details
          Navigator.of(context).pushNamed(
            AppRoutes.editEmployee,
            arguments: employee,
          );
        },
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Employees Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Click the + button to add your first employee'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.addEmployee);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Employee'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Results Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Try adjusting your search or filters'),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case UserRoles.admin:
        return Colors.red;
      case UserRoles.manager:
        return Colors.orange;
      case UserRoles.employee:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case UserRoles.admin:
        return 'Admin';
      case UserRoles.manager:
        return 'Manager';
      case UserRoles.employee:
        return 'Employee';
      default:
        return role;
    }
  }

  void _handleMenuAction(String action, UserModel employee) async {
    switch (action) {
      case 'view':
      case 'edit':
        Navigator.of(context).pushNamed(
          AppRoutes.editEmployee,
          arguments: employee,
        );
        break;

      case 'deactivate':
        final confirmed = await _showConfirmDialog(
          'Deactivate Employee',
          'Are you sure you want to deactivate ${employee.fullName}? They will no longer be able to log in.',
        );

        if (confirmed == true && mounted) {
          try {
            await _employeeService.deactivateEmployee(employee.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${employee.fullName} has been deactivated')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        }
        break;

      case 'reactivate':
        try {
          await _employeeService.reactivateEmployee(employee.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${employee.fullName} has been reactivated')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
        break;
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
