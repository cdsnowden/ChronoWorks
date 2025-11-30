import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/employee_service.dart';
import '../../services/time_entry_service.dart';
import '../../services/pto_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final TimeEntryService _timeEntryService = TimeEntryService();
  final PtoService _ptoService = PtoService();

  bool _isLoading = true;
  String _selectedPeriod = 'last_4_weeks';

  // Analytics data
  List<_WeeklyData> _weeklyData = [];
  Map<String, double> _laborCostByRole = {};
  double _totalRegularHours = 0;
  double _totalOvertimeHours = 0;
  double _totalLaborCost = 0;
  double _averageHoursPerEmployee = 0;

  int _activeEmployees = 0;
  double _overtimePercentage = 0;

  // PTO Analytics data
  double _totalPtoAvailable = 0;
  double _totalPtoUsed = 0;
  double _totalPtoPending = 0;
  int _ptoEligibleEmployees = 0;
  double _averagePtoUsage = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all employees
      final employees = await _employeeService.getAllEmployees(currentUser.companyId);
      final activeEmployees = employees.where((e) => e.isActive).toList();

      // Calculate date ranges based on selected period
      final now = DateTime.now();
      final weeksToAnalyze = _selectedPeriod == 'last_4_weeks' ? 4 :
                            _selectedPeriod == 'last_8_weeks' ? 8 : 12;

      // Generate weekly data
      final weeklyData = <_WeeklyData>[];
      final laborByRole = <String, double>{};
      double totalRegular = 0;
      double totalOvertime = 0;
      double totalCost = 0;
      final employeesWithHours = <String>{};

      for (int week = weeksToAnalyze - 1; week >= 0; week--) {
        final weekEnd = now.subtract(Duration(days: now.weekday % 7 + (week * 7)));
        final weekStart = weekEnd.subtract(const Duration(days: 6));
        final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final weekEndDate = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);

        double weekRegularHours = 0;
        double weekOvertimeHours = 0;
        double weekLaborCost = 0;

        for (final employee in activeEmployees) {
          final entries = await _timeEntryService.getTimeEntriesInRange(
            userId: employee.id,
            startDate: weekStartDate,
            endDate: weekEndDate,
          );

          double employeeHours = 0;
          for (final entry in entries) {
            employeeHours += entry.totalHours;
          }

          if (employeeHours > 0) {
            employeesWithHours.add(employee.id);
          }

          // Calculate regular vs overtime (40 hour threshold)
          final regularHours = employeeHours.clamp(0.0, 40.0);
          final overtimeHours = employeeHours > 40 ? employeeHours - 40 : 0.0;

          weekRegularHours += regularHours;
          weekOvertimeHours += overtimeHours;

          // Calculate cost
          final regularCost = regularHours * employee.hourlyRate;
          final overtimeCost = overtimeHours * employee.hourlyRate * 1.5;
          final employeeCost = regularCost + overtimeCost;
          weekLaborCost += employeeCost;

          // Track by role
          final role = employee.role;
          laborByRole[role] = (laborByRole[role] ?? 0) + employeeCost;
        }

        weeklyData.add(_WeeklyData(
          weekStart: weekStartDate,
          regularHours: weekRegularHours,
          overtimeHours: weekOvertimeHours,
          laborCost: weekLaborCost,
        ));

        totalRegular += weekRegularHours;
        totalOvertime += weekOvertimeHours;
        totalCost += weekLaborCost;
      }

      final totalHours = totalRegular + totalOvertime;
      final avgHoursPerEmployee = employeesWithHours.isNotEmpty
          ? totalHours / employeesWithHours.length
          : 0.0;
      final otPercentage = totalHours > 0 ? (totalOvertime / totalHours * 100) : 0.0;

      // Load PTO analytics
      double ptoAvailable = 0;
      double ptoUsed = 0;
      double ptoPending = 0;
      int ptoEligible = 0;

      final currentYear = DateTime.now().year;
      final balances = await _ptoService.getAllBalancesForCompany(
        currentUser.companyId,
        currentYear,
      );

      for (final balance in balances) {
        ptoAvailable += balance.availableHours;
        ptoUsed += balance.usedHours;
        ptoPending += balance.pendingHours;
        if (balance.totalEarnedHours > 0) {
          ptoEligible++;
        }
      }

      final avgPtoUsage = ptoEligible > 0
          ? (ptoUsed / (ptoAvailable + ptoUsed) * 100)
          : 0.0;

      setState(() {
        _weeklyData = weeklyData;
        _laborCostByRole = laborByRole;
        _totalRegularHours = totalRegular;
        _totalOvertimeHours = totalOvertime;
        _totalLaborCost = totalCost;
        _averageHoursPerEmployee = avgHoursPerEmployee;

        _activeEmployees = employeesWithHours.length;
        _overtimePercentage = otPercentage;

        _totalPtoAvailable = ptoAvailable;
        _totalPtoUsed = ptoUsed;
        _totalPtoPending = ptoPending;
        _ptoEligibleEmployees = ptoEligible;
        _averagePtoUsage = avgPtoUsage;

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
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
                  // Period Selector
                  _buildPeriodSelector(),
                  const SizedBox(height: 20),

                  // Key Metrics Cards
                  _buildKeyMetrics(),
                  const SizedBox(height: 24),

                  // Weekly Hours Chart
                  _buildSectionHeader('Weekly Hours Trend', Icons.bar_chart),
                  const SizedBox(height: 12),
                  _buildWeeklyHoursChart(),
                  const SizedBox(height: 24),

                  // Labor Cost Chart
                  _buildSectionHeader('Labor Cost Trend', Icons.attach_money),
                  const SizedBox(height: 12),
                  _buildLaborCostChart(),
                  const SizedBox(height: 24),

                  // Labor by Role
                  _buildSectionHeader('Labor Cost by Role', Icons.pie_chart),
                  const SizedBox(height: 12),
                  _buildLaborByRoleChart(),
                  const SizedBox(height: 24),

                  // Overtime Analysis
                  _buildSectionHeader('Overtime Analysis', Icons.timer),
                  const SizedBox(height: 12),
                  _buildOvertimeAnalysis(),
                  const SizedBox(height: 24),

                  // PTO Analytics
                  _buildSectionHeader('PTO Overview ${DateTime.now().year}', Icons.beach_access),
                  const SizedBox(height: 12),
                  _buildPtoAnalytics(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: Colors.blue),
            const SizedBox(width: 12),
            const Text('Analysis Period:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'last_4_weeks', label: Text('4 Weeks')),
                  ButtonSegment(value: 'last_8_weeks', label: Text('8 Weeks')),
                  ButtonSegment(value: 'last_12_weeks', label: Text('12 Weeks')),
                ],
                selected: {_selectedPeriod},
                onSelectionChanged: (selection) {
                  setState(() => _selectedPeriod = selection.first);
                  _loadAnalytics();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('Total Hours', _totalRegularHours + _totalOvertimeHours, 'hrs', Icons.access_time, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Labor Cost', _totalLaborCost, '\$', Icons.attach_money, Colors.green, isPrefix: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Overtime', _overtimePercentage, '%', Icons.timer, _overtimePercentage > 15 ? Colors.orange : Colors.teal)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Active Staff', _activeEmployees.toDouble(), '', Icons.people, Colors.purple, isInteger: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Avg Hrs/Employee', _averageHoursPerEmployee, 'hrs', Icons.person, Colors.indigo)),
      ],
    );
  }

  Widget _buildMetricCard(String label, double value, String suffix, IconData icon, Color color, {bool isPrefix = false, bool isInteger = false}) {
    String displayValue;
    if (isInteger) {
      displayValue = value.toInt().toString();
    } else if (value >= 1000) {
      displayValue = '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      displayValue = value.toStringAsFixed(1);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              isPrefix ? '$suffix$displayValue' : '$displayValue$suffix',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWeeklyHoursChart() {
    if (_weeklyData.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No data available'))));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _weeklyData.map((d) => d.regularHours + d.overtimeHours).reduce((a, b) => a > b ? a : b) * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final data = _weeklyData[groupIndex];
                    return BarTooltipItem(
                      '${DateFormat('MMM d').format(data.weekStart)}\n'
                      'Regular: ${data.regularHours.toStringAsFixed(1)}h\n'
                      'Overtime: ${data.overtimeHours.toStringAsFixed(1)}h',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= _weeklyData.length) return const SizedBox();
                      final data = _weeklyData[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(DateFormat('M/d').format(data.weekStart), style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _weeklyData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data.regularHours + data.overtimeHours,
                      width: 20,
                      rodStackItems: [
                        BarChartRodStackItem(0, data.regularHours, Colors.blue),
                        BarChartRodStackItem(data.regularHours, data.regularHours + data.overtimeHours, Colors.orange),
                      ],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaborCostChart() {
    if (_weeklyData.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No data available'))));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _totalLaborCost / _weeklyData.length / 2,
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= _weeklyData.length) return const SizedBox();
                      final data = _weeklyData[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(DateFormat('M/d').format(data.weekStart), style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      if (value >= 1000) {
                        return Text('\$${(value / 1000).toStringAsFixed(1)}K', style: const TextStyle(fontSize: 10));
                      }
                      return Text('\$${value.toInt()}', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _weeklyData.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.laborCost);
                  }).toList(),
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final data = _weeklyData[spot.x.toInt()];
                      return LineTooltipItem(
                        '${DateFormat('MMM d').format(data.weekStart)}\n\$${data.laborCost.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaborByRoleChart() {
    if (_laborCostByRole.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No data available'))));
    }

    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    final entries = _laborCostByRole.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
                    sections: entries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final roleEntry = entry.value;
                      final percentage = (_totalLaborCost > 0)
                          ? (roleEntry.value / _totalLaborCost * 100)
                          : 0.0;
                      return PieChartSectionData(
                        value: roleEntry.value,
                        title: '${percentage.toStringAsFixed(0)}%',
                        color: colors[index % colors.length],
                        radius: 60,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                children: entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final roleEntry = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, color: colors[index % colors.length]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatRoleName(roleEntry.key), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              Text('\$${roleEntry.value.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildOvertimeMetric('Regular Hours', _totalRegularHours, Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOvertimeMetric('Overtime Hours', _totalOvertimeHours, Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOvertimeMetric('OT Cost Premium', _totalOvertimeHours * 0.5 * (_totalLaborCost / (_totalRegularHours + _totalOvertimeHours + 0.001)), Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Overtime Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overtime Ratio', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('${_overtimePercentage.toStringAsFixed(1)}%', style: TextStyle(color: _overtimePercentage > 15 ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_overtimePercentage / 100).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_overtimePercentage > 15 ? Colors.orange : Colors.green),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _overtimePercentage > 15
                      ? 'Overtime is above recommended 15% threshold'
                      : 'Overtime is within healthy range',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeMetric(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value >= 1000 ? '\$${(value / 1000).toStringAsFixed(1)}K' : value.toStringAsFixed(1),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPtoAnalytics() {
    final totalPtoDays = (_totalPtoAvailable + _totalPtoUsed + _totalPtoPending) / 8;
    final availableDays = _totalPtoAvailable / 8;
    final usedDays = _totalPtoUsed / 8;
    final pendingDays = _totalPtoPending / 8;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // PTO Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildPtoMetric('Eligible Employees', _ptoEligibleEmployees.toDouble(), Colors.teal, isCount: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPtoMetric('Available', availableDays, Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPtoMetric('Used', usedDays, Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPtoMetric('Pending', pendingDays, Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Usage Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Company PTO Usage', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      '${_averagePtoUsage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _averagePtoUsage > 80 ? Colors.red : Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_averagePtoUsage / 100).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _averagePtoUsage > 80 ? Colors.orange : Colors.teal,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPtoLegendItem('Available', Colors.green),
                    const SizedBox(width: 16),
                    _buildPtoLegendItem('Used', Colors.orange),
                    const SizedBox(width: 16),
                    _buildPtoLegendItem('Pending', Colors.purple),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Summary text
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total: ${totalPtoDays.toStringAsFixed(0)} days allocated across $_ptoEligibleEmployees eligible employees '
                    '(avg ${_ptoEligibleEmployees > 0 ? (totalPtoDays / _ptoEligibleEmployees).toStringAsFixed(1) : 0} days/employee)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPtoMetric(String label, double value, Color color, {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            isCount ? value.toInt().toString() : '${value.toStringAsFixed(1)}d',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPtoLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'admin': return 'Admins';
      case 'manager': return 'Managers';
      case 'employee': return 'Employees';
      default: return role.substring(0, 1).toUpperCase() + role.substring(1);
    }
  }
}

class _WeeklyData {
  final DateTime weekStart;
  final double regularHours;
  final double overtimeHours;
  final double laborCost;

  _WeeklyData({
    required this.weekStart,
    required this.regularHours,
    required this.overtimeHours,
    required this.laborCost,
  });
}
