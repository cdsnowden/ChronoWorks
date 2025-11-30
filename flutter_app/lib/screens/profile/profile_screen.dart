import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../services/employee_service.dart';
import '../../services/pto_service.dart';
import '../../routes.dart';
import '../../widgets/pto_balance_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final PtoService _ptoService = PtoService();
  bool _isEditing = false;
  bool _isLoading = false;

  // PTO Eligibility
  bool _isPtoEligible = false;
  DateTime? _ptoEligibilityDate;
  int _daysUntilPtoEligible = 0;
  int _waitingPeriodMonths = 12;
  bool _eligibilityLoaded = false;

  // Edit controllers
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPtoEligibility();
  }

  Future<void> _loadPtoEligibility() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    try {
      final eligibility = await _ptoService.checkPtoEligibility(
        employeeId: user.id,
        companyId: user.companyId,
      );

      if (mounted) {
        setState(() {
          _isPtoEligible = eligibility['isEligible'] as bool;
          _ptoEligibilityDate = eligibility['eligibilityDate'] as DateTime?;
          _daysUntilPtoEligible = eligibility['daysUntilEligible'] as int;
          _waitingPeriodMonths = eligibility['waitingPeriodMonths'] as int;
          _eligibilityLoaded = true;
        });
      }
    } catch (e) {
      // Fall back to showing the balance card if there's an error
      if (mounted) {
        setState(() {
          _isPtoEligible = true;
          _eligibilityLoaded = true;
        });
      }
    }
  }

  void _loadUserData() {
    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      _phoneController.text = user.phoneNumber ?? '';
      _addressController.text = user.address ?? '';
      _selectedDateOfBirth = user.dateOfBirth;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select Your Date of Birth',
    );

    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final updatedUser = user.copyWith(
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        updatedAt: DateTime.now(),
      );

      await _employeeService.updateEmployee(updatedUser);
      await authProvider.refreshUser();

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  void _cancelEditing() {
    _loadUserData();
    setState(() => _isEditing = false);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<app_auth.AuthProvider>().signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(user),
            const SizedBox(height: 24),

            // Personal Information
            _buildSectionCard(
              title: 'Personal Information',
              icon: Icons.person,
              children: [
                _buildInfoRow('Full Name', user.fullName, editable: false),
                _buildInfoRow('Email', user.email, editable: false),
                _buildEditableRow(
                  'Phone',
                  _phoneController,
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                _buildEditableRow(
                  'Address',
                  _addressController,
                  Icons.home,
                  maxLines: 2,
                ),
                _buildDateRow(),
              ],
            ),
            const SizedBox(height: 16),

            // Employment Information
            _buildSectionCard(
              title: 'Employment Information',
              icon: Icons.work,
              children: [
                _buildInfoRow('Role', _formatRole(user.role), editable: false),
                _buildInfoRow('Employment Type', _formatEmploymentType(user.employmentType), editable: false),
                _buildInfoRow('Hourly Rate', '\$${user.hourlyRate.toStringAsFixed(2)}/hr', editable: false),
                _buildInfoRow('Status', user.isActive ? 'Active' : 'Inactive', editable: false),
                if (user.isKeyholder)
                  _buildInfoRow('Keyholder', 'Yes', editable: false),
                _buildInfoRow(
                  'Hire Date',
                  user.hireDate != null
                      ? DateFormat('MMM d, yyyy').format(user.hireDate!)
                      : '${DateFormat('MMM d, yyyy').format(user.createdAt)} (account created)',
                  editable: false,
                ),
                _buildInfoRow('Member Since', DateFormat('MMM d, yyyy').format(user.createdAt), editable: false),
              ],
            ),
            const SizedBox(height: 16),

            // PTO Balance
            if (!_eligibilityLoaded)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_isPtoEligible)
              PtoBalanceCard(
                employeeId: user.id,
                companyId: user.companyId,
                compact: false,
              )
            else
              _buildSectionCard(
                title: 'Time Off Eligibility',
                icon: Icons.beach_access,
                children: [
                  _buildInfoRow(
                    'PTO Status',
                    'Not Yet Eligible',
                    editable: false,
                    valueColor: Colors.orange,
                  ),
                  _buildInfoRow(
                    'Waiting Period',
                    _waitingPeriodMonths == 0
                        ? 'None'
                        : '$_waitingPeriodMonths month${_waitingPeriodMonths == 1 ? '' : 's'}',
                    editable: false,
                  ),
                  if (_ptoEligibilityDate != null)
                    _buildInfoRow(
                      'Eligible On',
                      DateFormat('MMM d, yyyy').format(_ptoEligibilityDate!),
                      editable: false,
                    ),
                  if (_daysUntilPtoEligible > 0)
                    _buildInfoRow(
                      'Days Until Eligible',
                      '$_daysUntilPtoEligible days',
                      editable: false,
                    ),
                ],
              ),
            const SizedBox(height: 16),

            // Actions
            if (_isEditing)
              _buildEditActions()
            else
              _buildActionButtons(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: _getRoleColor(user.role),
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Text(
                      user.firstName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user.role).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getRoleColor(user.role)),
                    ),
                    child: Text(
                      _formatRole(user.role),
                      style: TextStyle(
                        color: _getRoleColor(user.role),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool editable = true, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    if (!_isEditing) {
      return _buildInfoRow(label, controller.text.isEmpty ? 'Not set' : controller.text);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDateRow() {
    final dateStr = _selectedDateOfBirth != null
        ? DateFormat('MMMM d, yyyy').format(_selectedDateOfBirth!)
        : 'Not set';

    if (!_isEditing) {
      return _buildInfoRow('Date of Birth', dateStr);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: _selectDateOfBirth,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Date of Birth',
            prefixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder(),
          ),
          child: Text(dateStr),
        ),
      ),
    );
  }

  Widget _buildEditActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _cancelEditing,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Change Password
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.changePassword);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Face Registration (for employees)
        Card(
          child: ListTile(
            leading: const Icon(Icons.face),
            title: const Text('Face Registration'),
            subtitle: const Text('For clock-in verification'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.faceRegistration);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Sign Out
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: _signOut,
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'manager':
        return Colors.orange;
      case 'employee':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'employee':
        return 'Employee';
      default:
        return role;
    }
  }

  String _formatEmploymentType(String type) {
    switch (type.toLowerCase()) {
      case 'full-time':
        return 'Full-Time';
      case 'part-time':
        return 'Part-Time';
      case 'contractor':
        return 'Contractor';
      default:
        return type;
    }
  }
}
