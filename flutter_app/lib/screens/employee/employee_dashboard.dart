import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_provider.dart' as app_auth;
import '../../routes.dart';
import '../../widgets/overtime_risk_warning_card.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await context.read<app_auth.AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                }
              }
            },
          ),
        ],
      ),
      body: Consumer<app_auth.AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                Text(
                  'Welcome, ${user?.fullName ?? 'Employee'}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to track your time?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 24),

                // Overtime Risk Warning Card
                Builder(
                  builder: (context) {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    print('DEBUG: Employee Dashboard - FirebaseAuth.currentUser = ${currentUser?.uid ?? "NULL"}');

                    if (currentUser != null) {
                      print('DEBUG: Rendering OvertimeRiskWarningCard for employee: ${currentUser.uid}');
                      return OvertimeRiskWarningCard(
                        employeeId: currentUser.uid,
                      );
                    } else {
                      print('DEBUG: Not rendering OvertimeRiskWarningCard - currentUser is null');
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.red.shade200,
                        child: const Text(
                          '⚠️ DEBUG: currentUser is NULL - cannot show overtime card',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Quick Actions Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDashboardCard(
                      context: context,
                      title: 'Time Clock',
                      subtitle: 'Clock in/out',
                      icon: Icons.access_time,
                      color: Colors.green,
                      route: AppRoutes.clock,
                    ),
                    _buildDashboardCard(
                      context: context,
                      title: 'Time Entries',
                      subtitle: 'View history',
                      icon: Icons.history,
                      color: Colors.blue,
                      route: AppRoutes.myTimeEntries,
                    ),
                    _buildDashboardCard(
                      context: context,
                      title: 'My Schedule',
                      subtitle: 'View shifts',
                      icon: Icons.calendar_today,
                      color: Colors.orange,
                      route: AppRoutes.mySchedule,
                    ),
                    _buildDashboardCard(
                      context: context,
                      title: 'Profile',
                      subtitle: 'Settings',
                      icon: Icons.person,
                      color: Colors.purple,
                      route: AppRoutes.profile,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
