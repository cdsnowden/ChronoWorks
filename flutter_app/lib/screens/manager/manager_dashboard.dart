import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../routes.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
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
                  'Welcome back, ${user?.firstName ?? 'Manager'}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manager Dashboard',
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
                        icon: Icons.alarm,
                        title: 'Clock In/Out',
                        subtitle: 'Track your time',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.clock);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.people,
                        title: 'My Team',
                        subtitle: 'View team members',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.employeeList);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.calendar_today,
                        title: 'Schedules',
                        subtitle: 'Manage team schedules',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.scheduleManagement);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.access_time,
                        title: 'Time Tracking',
                        subtitle: 'View team time',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.adminTimeTracking);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.beach_access,
                        title: 'Time-Off Requests',
                        subtitle: 'Approve team requests',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.managerTimeOffApprovals);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.account_balance_wallet,
                        title: 'Team PTO',
                        subtitle: 'View team balances',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.managerTeamPto);
                        },
                      ),
                      _DashboardCard(
                        icon: Icons.assessment,
                        title: 'Reports',
                        subtitle: 'View reports',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.managerTeamReports);
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
