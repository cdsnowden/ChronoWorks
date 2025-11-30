import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/super_admin_service.dart';

class PlatformReportsScreen extends StatefulWidget {
  const PlatformReportsScreen({super.key});

  @override
  State<PlatformReportsScreen> createState() => _PlatformReportsScreenState();
}

class _PlatformReportsScreenState extends State<PlatformReportsScreen> {
  final SuperAdminService _service = SuperAdminService();

  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<CompanyInfo> _companies = [];

  // Calculated metrics
  double _mrr = 0;
  double _arr = 0;
  int _activeCompanies = 0;
  int _trialCompanies = 0;
  int _archivedCompanies = 0;
  int _paidCompanies = 0;
  Map<String, int> _planDistribution = {};
  Map<String, double> _revenueByPlan = {};
  List<_MonthlyGrowth> _growthData = [];

  // Plan pricing (monthly)
  static const Map<String, double> _planPricing = {
    'free': 0,
    'trial': 0,
    'starter': 29,
    'bronze': 49,
    'silver': 99,
    'gold': 199,
    'platinum': 399,
    'diamond': 799,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _service.getSystemStats(),
        _service.getAllCompanies(),
      ]);

      _stats = results[0] as Map<String, dynamic>;
      _companies = results[1] as List<CompanyInfo>;

      _calculateMetrics();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _calculateMetrics() {
    // Reset
    _mrr = 0;
    _activeCompanies = 0;
    _trialCompanies = 0;
    _archivedCompanies = 0;
    _paidCompanies = 0;
    _planDistribution = {};
    _revenueByPlan = {};

    // Group companies by creation month for growth chart
    final monthlyData = <String, int>{};

    for (final company in _companies) {
      final plan = company.currentPlan.toLowerCase();
      final status = company.status.toLowerCase();

      // Count by status
      if (status == 'active') {
        _activeCompanies++;
      } else if (status == 'trial') {
        _trialCompanies++;
      } else if (status == 'archived') {
        _archivedCompanies++;
      }

      // Plan distribution (exclude archived)
      if (status != 'archived') {
        _planDistribution[plan] = (_planDistribution[plan] ?? 0) + 1;

        // Calculate MRR
        final price = _planPricing[plan] ?? 0;
        if (price > 0) {
          _paidCompanies++;
          _mrr += price;
          _revenueByPlan[plan] = (_revenueByPlan[plan] ?? 0) + price;
        }
      }

      // Growth data (last 6 months)
      final monthKey = DateFormat('yyyy-MM').format(company.createdAt);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
    }

    _arr = _mrr * 12;

    // Build growth chart data (last 6 months)
    final now = DateTime.now();
    _growthData = [];
    int cumulativeTotal = 0;

    // Get all months in order
    final sortedMonths = monthlyData.keys.toList()..sort();

    // Calculate cumulative up to 6 months ago
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
    for (final month in sortedMonths) {
      final monthDate = DateTime.parse('$month-01');
      if (monthDate.isBefore(sixMonthsAgo)) {
        cumulativeTotal += monthlyData[month]!;
      }
    }

    // Build last 6 months data
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(month);
      final newCompanies = monthlyData[monthKey] ?? 0;
      cumulativeTotal += newCompanies;

      _growthData.add(_MonthlyGrowth(
        month: month,
        newCompanies: newCompanies,
        totalCompanies: cumulativeTotal,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue Metrics
                  _buildRevenueSection(),
                  const SizedBox(height: 24),

                  // Company Status Overview
                  _buildCompanyStatusSection(),
                  const SizedBox(height: 24),

                  // Subscription Distribution
                  _buildSubscriptionSection(),
                  const SizedBox(height: 24),

                  // Revenue by Plan
                  _buildRevenueByPlanSection(),
                  const SizedBox(height: 24),

                  // Growth Trend
                  _buildGrowthSection(),
                  const SizedBox(height: 24),

                  // Churn Analysis
                  _buildChurnSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildRevenueSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green),
                const SizedBox(width: 8),
                Text('Revenue Metrics', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildRevenueCard('MRR', _mrr, Colors.green, 'Monthly Recurring Revenue')),
                const SizedBox(width: 16),
                Expanded(child: _buildRevenueCard('ARR', _arr, Colors.blue, 'Annual Recurring Revenue')),
                const SizedBox(width: 16),
                Expanded(child: _buildRevenueCard('ARPU', _paidCompanies > 0 ? _mrr / _paidCompanies : 0, Colors.purple, 'Avg Revenue Per User')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard('Paid Customers', _paidCompanies, Colors.teal)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(String label, double value, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Card(
        elevation: 2,
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                '\$${_formatNumber(value)}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, int value, Color color) {
    return Card(
      elevation: 2,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyStatusSection() {
    final total = _activeCompanies + _trialCompanies + _archivedCompanies;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Company Status Overview', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text('Total: $total', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatusCard('Active', _activeCompanies, Colors.green, total)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusCard('Trial', _trialCompanies, Colors.blue, total)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusCard('Archived', _archivedCompanies, Colors.grey, total)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusCard('Total Users', _stats?['totalUsers'] ?? 0, Colors.purple, 0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, int value, Color color, int total) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.circle, color: color, size: 16),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
            if (total > 0) ...[
              const SizedBox(height: 4),
              Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    if (_planDistribution.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No subscription data'))));
    }

    final colors = {
      'free': Colors.grey,
      'trial': Colors.blue,
      'starter': Colors.lightBlue,
      'bronze': Colors.brown,
      'silver': Colors.blueGrey,
      'gold': Colors.amber,
      'platinum': Colors.purple,
      'diamond': Colors.cyan,
    };

    final entries = _planDistribution.entries.toList()
      ..sort((a, b) => (_planPricing[a.key] ?? 0).compareTo(_planPricing[b.key] ?? 0));

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Subscription Distribution', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Pie Chart
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: entries.map((entry) {
                          final percentage = (entry.value / total * 100);
                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            title: '${percentage.toStringAsFixed(0)}%',
                            color: colors[entry.key] ?? Colors.grey,
                            radius: 60,
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[entry.key], borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Text(_formatPlanName(entry.key), style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueByPlanSection() {
    if (_revenueByPlan.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = {
      'starter': Colors.lightBlue,
      'bronze': Colors.brown,
      'silver': Colors.blueGrey,
      'gold': Colors.amber,
      'platinum': Colors.purple,
      'diamond': Colors.cyan,
    };

    final entries = _revenueByPlan.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.green),
                const SizedBox(width: 8),
                Text('Revenue by Plan (MRR)', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: entries.isNotEmpty ? entries.first.value * 1.2 : 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = entries[groupIndex];
                        return BarTooltipItem(
                          '${_formatPlanName(entry.key)}\n\$${entry.value.toStringAsFixed(0)}/mo',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= entries.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_formatPlanName(entries[value.toInt()].key), style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text('\$${value.toInt()}', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((mapEntry) {
                    final index = mapEntry.key;
                    final entry = mapEntry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          width: 30,
                          color: colors[entry.key] ?? Colors.grey,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthSection() {
    if (_growthData.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No growth data'))));
    }

    final maxTotal = _growthData.map((d) => d.totalCompanies).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Company Growth (Last 6 Months)', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _growthData.length) return const SizedBox();
                          final data = _growthData[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(DateFormat('MMM').format(data.month), style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxTotal * 1.2,
                  lineBarsData: [
                    // Total companies line
                    LineChartBarData(
                      spots: _growthData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.totalCompanies.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final data = _growthData[spot.x.toInt()];
                          return LineTooltipItem(
                            '${DateFormat('MMM yyyy').format(data.month)}\nTotal: ${data.totalCompanies}\nNew: +${data.newCompanies}',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Monthly new signups bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _growthData.map((data) {
                return Column(
                  children: [
                    Text('+${data.newCompanies}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                    Text(DateFormat('MMM').format(data.month), style: const TextStyle(fontSize: 10)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChurnSection() {
    final total = _activeCompanies + _trialCompanies + _archivedCompanies;
    final churnRate = total > 0 ? (_archivedCompanies / total * 100) : 0.0;
    final conversionRate = (_activeCompanies + _trialCompanies) > 0
        ? (_paidCompanies / (_activeCompanies + _trialCompanies) * 100)
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Health Metrics', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildHealthMetric('Churn Rate', churnRate, '%', churnRate > 10 ? Colors.red : Colors.green, inverted: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildHealthMetric('Paid Conversion', conversionRate, '%', conversionRate > 20 ? Colors.green : Colors.orange)),
                const SizedBox(width: 16),
                Expanded(child: _buildHealthMetric('Trial Users', _trialCompanies.toDouble(), '', Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _buildHealthMetric('Free Users', (_planDistribution['free'] ?? 0).toDouble(), '', Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            // Churn Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Customer Retention', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('${(100 - churnRate).toStringAsFixed(1)}%', style: TextStyle(color: churnRate < 10 ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ((100 - churnRate) / 100).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: Colors.red.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(churnRate < 10 ? Colors.green : Colors.orange),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetric(String label, double value, String suffix, Color color, {bool inverted = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            suffix.isNotEmpty ? '${value.toStringAsFixed(1)}$suffix' : value.toInt().toString(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatPlanName(String plan) {
    return plan.substring(0, 1).toUpperCase() + plan.substring(1);
  }
}

class _MonthlyGrowth {
  final DateTime month;
  final int newCompanies;
  final int totalCompanies;

  _MonthlyGrowth({
    required this.month,
    required this.newCompanies,
    required this.totalCompanies,
  });
}
