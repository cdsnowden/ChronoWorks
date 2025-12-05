import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../routes.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          // Profile Icon
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
          ),
          // Logout Button
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
                await context.read<AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                }
              }
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Message
                Text(
                  'Welcome back, \${user?.firstName ?? "Admin"}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Administrator Dashboard',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),

                // Dashboard Cards
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _DashboardCard(
                        icon: Icons.people,
                        title: 'Employees',
                        subtitle: 'Manage employees',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.employeeList);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.calendar_today,
                        title: 'Schedules',
                        subtitle: 'View & manage schedules',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.scheduleManagement);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.access_time,
                        title: 'Time Tracking',
                        subtitle: 'View time tracking',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.adminTimeTracking);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.warning_amber,
                        title: 'Overtime Risk',
                        subtitle: 'Monitor overtime risks',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.overtimeRiskDashboard);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.attach_money,
                        title: 'Payroll',
                        subtitle: 'Process payroll',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.payrollExport);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.insights,
                        title: 'Analytics',
                        subtitle: 'View reports & trends',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.adminAnalytics);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.beach_access,
                        title: 'PTO Policy',
                        subtitle: 'Manage time off rules',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.ptoPolicySettings);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.account_balance_wallet,
                        title: 'PTO Balances',
                        subtitle: 'View & adjust balances',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.ptoBalanceManagement);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.settings,
                        title: 'Settings',
                        subtitle: 'Compliance & settings',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.complianceSettings);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
