import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/compliance_rule_model.dart';
import '../../services/compliance_service.dart';
import '../../services/auth_provider.dart';

class ComplianceSettingsScreen extends StatefulWidget {
  const ComplianceSettingsScreen({super.key});

  @override
  State<ComplianceSettingsScreen> createState() => _ComplianceSettingsScreenState();
}

class _ComplianceSettingsScreenState extends State<ComplianceSettingsScreen>
    with SingleTickerProviderStateMixin {
  final ComplianceService _complianceService = ComplianceService();
  late TabController _tabController;

  CompanyComplianceSettings? _settings;
  List<ComplianceRule> _applicableRules = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId ?? '';

    if (companyId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Load or create settings
      final settings = await _complianceService.getOrCreateSettings(companyId);

      // Load applicable rules for company's jurisdiction
      final rules = await _complianceService.getRulesForJurisdiction(
        state: settings.primaryState,
        city: settings.primaryCity,
      );

      setState(() {
        _settings = settings;
        _applicableRules = rules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    setState(() => _isSaving = true);

    try {
      await _complianceService.saveCompanySettings(_settings!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compliance settings saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _initializeRules() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initialize Compliance Rules'),
        content: const Text(
          'This will load default federal and state labor law rules into the system. '
          'This only needs to be done once. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Initialize'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _complianceService.initializeDefaultRules();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compliance rules initialized successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing rules: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _initializeRules,
            tooltip: 'Initialize Default Rules',
          ),
          if (_settings != null)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
            Tab(icon: Icon(Icons.gavel), text: 'Rules'),
            Tab(icon: Icon(Icons.history), text: 'Audit Log'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSettingsTab(),
                _buildRulesTab(),
                _buildAuditLogTab(),
              ],
            ),
    );
  }

  Widget _buildSettingsTab() {
    if (_settings == null) {
      return const Center(child: Text('No settings available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jurisdiction Settings
          _buildSectionCard(
            title: 'Jurisdiction',
            icon: Icons.location_on,
            children: [
              DropdownButtonFormField<String>(
                value: _settings!.primaryState,
                decoration: const InputDecoration(
                  labelText: 'Primary State',
                  border: OutlineInputBorder(),
                ),
                items: _getStateItems(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _settings = _settings!.copyWith(primaryState: value);
                    });
                    _loadData(); // Reload rules for new state
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _settings!.primaryCity ?? '',
                decoration: const InputDecoration(
                  labelText: 'City (Optional)',
                  hintText: 'e.g., Seattle, New York City',
                  border: OutlineInputBorder(),
                  helperText: 'Some cities have additional labor laws',
                ),
                onChanged: (value) {
                  _settings = _settings!.copyWith(
                    primaryCity: value.isEmpty ? null : value,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Break Enforcement
          _buildSectionCard(
            title: 'Break Enforcement',
            icon: Icons.restaurant,
            children: [
              SwitchListTile(
                title: const Text('Auto-Enforce Breaks'),
                subtitle: const Text('Automatically start breaks when required'),
                value: _settings!.autoEnforceBreaks,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings!.copyWith(autoEnforceBreaks: value);
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Require Break Acknowledgment'),
                subtitle: const Text('Employees must confirm break reminders'),
                value: _settings!.requireBreakAcknowledgment,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings!.copyWith(requireBreakAcknowledgment: value);
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Allow Meal Break Waivers'),
                subtitle: const Text('Employees can waive meal breaks (where legal)'),
                value: _settings!.allowMealBreakWaivers,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings!.copyWith(allowMealBreakWaivers: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overtime Settings
          _buildSectionCard(
            title: 'Overtime',
            icon: Icons.access_time,
            children: [
              TextFormField(
                initialValue: _settings!.overtimeWarningMinutes.toString(),
                decoration: const InputDecoration(
                  labelText: 'Overtime Warning (minutes before)',
                  border: OutlineInputBorder(),
                  helperText: 'When to warn employees about approaching overtime',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final minutes = int.tryParse(value) ?? 60;
                  _settings = _settings!.copyWith(overtimeWarningMinutes: minutes);
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Require Overtime Approval'),
                subtitle: const Text('Manager must approve before overtime begins'),
                value: _settings!.requireOvertimeApproval,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings!.copyWith(requireOvertimeApproval: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Minor Compliance
          _buildSectionCard(
            title: 'Minor Employees',
            icon: Icons.child_care,
            children: [
              SwitchListTile(
                title: const Text('Track Minor Compliance'),
                subtitle: const Text('Enforce work hour restrictions for minors'),
                value: _settings!.trackMinorCompliance,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings!.copyWith(trackMinorCompliance: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scheduling Compliance
          _buildSectionCard(
            title: 'Scheduling',
            icon: Icons.calendar_today,
            children: [
              SwitchListTile(
                title: const Text('Predictive Scheduling'),
                subtitle: const Text('Enforce advance schedule notice requirements'),
                value: _settings!.enablePredictiveScheduling,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings!.copyWith(enablePredictiveScheduling: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTab() {
    if (_applicableRules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No compliance rules loaded'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _initializeRules,
              icon: const Icon(Icons.download),
              label: const Text('Initialize Default Rules'),
            ),
          ],
        ),
      );
    }

    // Group rules by category
    final groupedRules = <ComplianceCategory, List<ComplianceRule>>{};
    for (final rule in _applicableRules) {
      groupedRules.putIfAbsent(rule.category, () => []).add(rule);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Showing ${_applicableRules.length} rules for ${_settings?.primaryState ?? 'your state'}',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Rules by category
        ...groupedRules.entries.map((entry) => _buildRuleCategorySection(
          category: entry.key,
          rules: entry.value,
        )),
      ],
    );
  }

  Widget _buildRuleCategorySection({
    required ComplianceCategory category,
    required List<ComplianceRule> rules,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_getCategoryIcon(category), size: 20),
              const SizedBox(width: 8),
              Text(
                _getCategoryName(category),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...rules.map((rule) => _buildRuleCard(rule)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRuleCard(ComplianceRule rule) {
    final isDisabled = _settings?.disabledRuleIds.contains(rule.id) ?? false;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDisabled ? Colors.grey.shade200 : Colors.teal.shade100,
          child: Icon(
            _getCategoryIcon(rule.category),
            color: isDisabled ? Colors.grey : Colors.teal.shade700,
            size: 20,
          ),
        ),
        title: Text(
          rule.name,
          style: TextStyle(
            decoration: isDisabled ? TextDecoration.lineThrough : null,
            color: isDisabled ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule.summary,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                _buildRuleChip(rule.jurisdiction.toUpperCase()),
                if (rule.state != null) _buildRuleChip(rule.state!),
                if (rule.city != null) _buildRuleChip(rule.city!),
              ],
            ),
          ],
        ),
        trailing: Switch(
          value: !isDisabled,
          onChanged: (enabled) {
            setState(() {
              final currentDisabled = List<String>.from(_settings!.disabledRuleIds);
              if (enabled) {
                currentDisabled.remove(rule.id);
              } else {
                currentDisabled.add(rule.id);
              }
              _settings = _settings!.copyWith(disabledRuleIds: currentDisabled);
            });
          },
        ),
        isThreeLine: true,
        onTap: () => _showRuleDetails(rule),
      ),
    );
  }

  Widget _buildRuleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
      ),
    );
  }

  void _showRuleDetails(ComplianceRule rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(rule.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(rule.description, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 24),
              _buildDetailRow('Category', _getCategoryName(rule.category)),
              _buildDetailRow('Jurisdiction', '${rule.jurisdiction} ${rule.state ?? ''} ${rule.city ?? ''}'.trim()),
              _buildDetailRow('Summary', rule.summary),
              if (rule.legalReference != null)
                _buildDetailRow('Legal Reference', rule.legalReference!),
              _buildDetailRow('Enforcement', rule.enforcementAction.name),
              if (rule.isWaivable)
                _buildDetailRow('Waivable', rule.waiverRequirements ?? 'Yes'),
              _buildDetailRow('Effective Date', rule.effectiveDate.toString().split(' ')[0]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildAuditLogTab() {
    return FutureBuilder<List<ComplianceEvent>>(
      future: _loadAuditLog(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                const SizedBox(height: 16),
                const Text('No compliance events'),
                Text(
                  'All employees are compliant',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventCard(event);
          },
        );
      },
    );
  }

  Future<List<ComplianceEvent>> _loadAuditLog() async {
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId ?? '';

    if (companyId.isEmpty) return [];

    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));

    return _complianceService.getComplianceEvents(
      companyId: companyId,
      startDate: startDate,
      endDate: now,
    );
  }

  Widget _buildEventCard(ComplianceEvent event) {
    final color = _getSeverityColor(event.severity);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            _getSeverityIcon(event.severity),
            color: color,
            size: 20,
          ),
        ),
        title: Text(event.employeeName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.ruleName, style: const TextStyle(fontSize: 12)),
            Text(
              event.description,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(event.timestamp),
              style: const TextStyle(fontSize: 11),
            ),
            if (event.isResolved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Resolved',
                  style: TextStyle(fontSize: 10, color: Colors.green.shade800),
                ),
              ),
          ],
        ),
        isThreeLine: true,
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
                  style: const TextStyle(
                    fontSize: 18,
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

  List<DropdownMenuItem<String>> _getStateItems() {
    const states = [
      'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
      'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
      'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
      'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
      'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
    ];

    return states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList();
  }

  IconData _getCategoryIcon(ComplianceCategory category) {
    switch (category) {
      case ComplianceCategory.mealBreak:
        return Icons.restaurant;
      case ComplianceCategory.restBreak:
        return Icons.coffee;
      case ComplianceCategory.dailyOvertime:
      case ComplianceCategory.weeklyOvertime:
        return Icons.access_time;
      case ComplianceCategory.doubleTime:
        return Icons.timer;
      case ComplianceCategory.minorHours:
      case ComplianceCategory.minorTiming:
        return Icons.child_care;
      case ComplianceCategory.predictiveScheduling:
        return Icons.calendar_today;
      case ComplianceCategory.splitShift:
        return Icons.call_split;
      case ComplianceCategory.consecutiveDays:
        return Icons.date_range;
    }
  }

  String _getCategoryName(ComplianceCategory category) {
    switch (category) {
      case ComplianceCategory.mealBreak:
        return 'Meal Breaks';
      case ComplianceCategory.restBreak:
        return 'Rest Breaks';
      case ComplianceCategory.dailyOvertime:
        return 'Daily Overtime';
      case ComplianceCategory.weeklyOvertime:
        return 'Weekly Overtime';
      case ComplianceCategory.doubleTime:
        return 'Double Time';
      case ComplianceCategory.minorHours:
        return 'Minor Work Hours';
      case ComplianceCategory.minorTiming:
        return 'Minor Work Timing';
      case ComplianceCategory.predictiveScheduling:
        return 'Predictive Scheduling';
      case ComplianceCategory.splitShift:
        return 'Split Shift';
      case ComplianceCategory.consecutiveDays:
        return 'Consecutive Days';
    }
  }

  Color _getSeverityColor(ComplianceSeverity severity) {
    switch (severity) {
      case ComplianceSeverity.critical:
        return Colors.red.shade900;
      case ComplianceSeverity.violation:
        return Colors.red;
      case ComplianceSeverity.warning:
        return Colors.orange;
      case ComplianceSeverity.info:
        return Colors.blue;
    }
  }

  IconData _getSeverityIcon(ComplianceSeverity severity) {
    switch (severity) {
      case ComplianceSeverity.critical:
        return Icons.dangerous;
      case ComplianceSeverity.violation:
        return Icons.error;
      case ComplianceSeverity.warning:
        return Icons.warning;
      case ComplianceSeverity.info:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
