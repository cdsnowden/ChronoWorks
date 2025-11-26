import 'package:flutter/material.dart';
import '../../services/overtime_risk_service.dart';

class OvertimeRiskDashboard extends StatefulWidget {
  const OvertimeRiskDashboard({super.key});

  @override
  State<OvertimeRiskDashboard> createState() => _OvertimeRiskDashboardState();
}

class _OvertimeRiskDashboardState extends State<OvertimeRiskDashboard> {
  final OvertimeRiskService _riskService = OvertimeRiskService();

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow.shade700;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.error_outline;
      case 'medium':
        return Icons.info_outline;
      case 'low':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime Risk Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              FutureBuilder<Map<String, int>>(
                future: _riskService.getRiskCounts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final counts = snapshot.data ?? {};
                  final totalRisk = (counts['critical'] ?? 0) +
                      (counts['high'] ?? 0) +
                      (counts['medium'] ?? 0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overtime Risk Overview',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.80,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _SummaryCard(
                            title: 'Total At-Risk',
                            count: totalRisk,
                            color: Colors.purple,
                            icon: Icons.groups,
                          ),
                          _SummaryCard(
                            title: 'Critical',
                            count: counts['critical'] ?? 0,
                            color: Colors.red,
                            icon: Icons.warning_amber_rounded,
                          ),
                          _SummaryCard(
                            title: 'High',
                            count: counts['high'] ?? 0,
                            color: Colors.orange,
                            icon: Icons.error_outline,
                          ),
                          _SummaryCard(
                            title: 'Medium',
                            count: counts['medium'] ?? 0,
                            color: Colors.yellow.shade700,
                            icon: Icons.info_outline,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // At-Risk Employees List
              Text(
                'At-Risk Employees',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<OvertimeRiskData>>(
                stream: _riskService.getOvertimeRisks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final risks = snapshot.data ?? [];

                  if (risks.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Overtime Risks',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All employees are within safe working hours',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Sort by risk level (critical first)
                  risks.sort((a, b) {
                    const priority = {
                      'critical': 0,
                      'high': 1,
                      'medium': 2,
                      'low': 3,
                    };
                    return (priority[a.riskLevel] ?? 99)
                        .compareTo(priority[b.riskLevel] ?? 99);
                  });

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: risks.length,
                    itemBuilder: (context, index) {
                      final risk = risks[index];
                      final riskColor = _getRiskColor(risk.riskLevel);
                      final riskIcon = _getRiskIcon(risk.riskLevel);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: riskColor.withOpacity(0.2),
                            child: Icon(riskIcon, color: riskColor),
                          ),
                          title: Text(
                            risk.employeeName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: riskColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      risk.riskLevel.toUpperCase(),
                                      style: TextStyle(
                                        color: riskColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Projected: ${risk.projectedHours.toStringAsFixed(1)}h'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Potential overtime: ${risk.overtimeHours.toStringAsFixed(1)}h',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: () {
                              // TODO: Navigate to employee details
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
