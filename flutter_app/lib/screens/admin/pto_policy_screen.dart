import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pto_policy_model.dart';
import '../../services/auth_provider.dart';
import '../../services/pto_service.dart';

class PtoPolicyScreen extends StatefulWidget {
  const PtoPolicyScreen({super.key});

  @override
  State<PtoPolicyScreen> createState() => _PtoPolicyScreenState();
}

class _PtoPolicyScreenState extends State<PtoPolicyScreen> {
  final PtoService _ptoService = PtoService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final companyId = authProvider.currentUser?.companyId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PTO Policy Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPolicyDialog(context, companyId),
            tooltip: 'Add Policy',
          ),
        ],
      ),
      body: StreamBuilder<List<PtoPolicyModel>>(
        stream: _ptoService.getPoliciesForCompany(companyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _initializePolicy(companyId),
                    child: const Text('Create Default Policy'),
                  ),
                ],
              ),
            );
          }

          final policies = snapshot.data ?? [];

          if (policies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.policy_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No PTO policies configured',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _initializePolicy(companyId),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Default Policy'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
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
                            'PTO policies define how employees earn and use paid time off. '
                            'The default policy applies to all employees unless they have a specific policy assigned.',
                            style: TextStyle(color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Policies List
                ...policies.map((policy) => _buildPolicyCard(context, policy, companyId)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, PtoPolicyModel policy, String companyId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(
          policy.isDefault ? Icons.star : Icons.policy,
          color: policy.isDefault ? Colors.amber : Colors.grey,
        ),
        title: Row(
          children: [
            Expanded(child: Text(policy.name)),
            if (policy.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Default',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (!policy.isActive)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(_getAccrualMethodText(policy.accrualMethod)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Settings Overview
                _buildSettingRow('Hours per Day', '${policy.hoursPerDay.toStringAsFixed(1)} hours'),
                _buildSettingRow('Hours per Week', '${policy.hoursPerWeek.toStringAsFixed(1)} hours'),
                _buildSettingRow('Waiting Period', _formatWaitingPeriod(policy.waitingPeriodMonths)),
                if (policy.maxAccrualHours != null)
                  _buildSettingRow('Max Accrual', '${policy.maxAccrualHours!.toStringAsFixed(0)} hours'),
                if (policy.maxCarryoverHours != null)
                  _buildSettingRow('Max Carryover', '${policy.maxCarryoverHours!.toStringAsFixed(0)} hours'),

                const Divider(height: 32),

                // Tiers
                Text(
                  'PTO Tiers by Years of Service',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...policy.tiers.map((tier) => _buildTierRow(tier, policy.hoursPerDay)),

                const Divider(height: 32),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!policy.isDefault)
                      TextButton.icon(
                        onPressed: () => _setAsDefault(companyId, policy.id),
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Set as Default'),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showPolicyDialog(context, companyId, policy: policy),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    if (!policy.isDefault)
                      TextButton.icon(
                        onPressed: () => _deletePolicy(policy),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTierRow(PtoTier tier, double hoursPerDay) {
    final days = tier.annualHours / hoursPerDay;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${tier.minYears}${tier.maxYears != null ? '-${tier.maxYears! - 1}' : '+'} years',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tier.annualHours.toStringAsFixed(0)} hours',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '(${days.toStringAsFixed(1)} days)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getAccrualMethodText(AccrualMethod method) {
    switch (method) {
      case AccrualMethod.annual:
        return 'Annual (lump sum at year start)';
      case AccrualMethod.perPayPeriod:
        return 'Per Pay Period accrual';
      case AccrualMethod.hoursWorked:
        return 'Based on hours worked';
    }
  }

  String _formatWaitingPeriod(int months) {
    if (months == 0) return 'None (immediate)';
    if (months == 12) return '1 year';
    if (months == 24) return '2 years';
    if (months < 12) return '$months month${months == 1 ? '' : 's'}';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) return '$years year${years == 1 ? '' : 's'}';
    return '$years year${years == 1 ? '' : 's'}, $remainingMonths month${remainingMonths == 1 ? '' : 's'}';
  }

  Future<void> _initializePolicy(String companyId) async {
    setState(() => _isLoading = true);
    try {
      await _ptoService.initializeCompanyPolicy(companyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default policy created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setAsDefault(String companyId, String policyId) async {
    try {
      await _ptoService.setDefaultPolicy(companyId, policyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default policy updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deletePolicy(PtoPolicyModel policy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Policy'),
        content: Text('Are you sure you want to delete "${policy.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _ptoService.deletePolicy(policy.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Policy deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showPolicyDialog(BuildContext context, String companyId, {PtoPolicyModel? policy}) {
    showDialog(
      context: context,
      builder: (context) => _PolicyEditDialog(
        companyId: companyId,
        policy: policy,
        onSave: (newPolicy) async {
          try {
            if (policy != null) {
              await _ptoService.updatePolicy(newPolicy);
            } else {
              await _ptoService.createPolicy(newPolicy);
            }
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(policy != null ? 'Policy updated' : 'Policy created')),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },
      ),
    );
  }
}

class _PolicyEditDialog extends StatefulWidget {
  final String companyId;
  final PtoPolicyModel? policy;
  final Future<void> Function(PtoPolicyModel) onSave;

  const _PolicyEditDialog({
    required this.companyId,
    this.policy,
    required this.onSave,
  });

  @override
  State<_PolicyEditDialog> createState() => _PolicyEditDialogState();
}

class _PolicyEditDialogState extends State<_PolicyEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hoursPerDayController = TextEditingController();
  final _hoursPerWeekController = TextEditingController();
  final _waitingPeriodController = TextEditingController();
  final _maxAccrualController = TextEditingController();
  final _maxCarryoverController = TextEditingController();

  AccrualMethod _accrualMethod = AccrualMethod.annual;
  bool _isActive = true;
  List<PtoTier> _tiers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.policy != null) {
      final p = widget.policy!;
      _nameController.text = p.name;
      _hoursPerDayController.text = p.hoursPerDay.toString();
      _hoursPerWeekController.text = p.hoursPerWeek.toString();
      _waitingPeriodController.text = p.waitingPeriodMonths.toString();
      _maxAccrualController.text = p.maxAccrualHours?.toString() ?? '';
      _maxCarryoverController.text = p.maxCarryoverHours?.toString() ?? '';
      _accrualMethod = p.accrualMethod;
      _isActive = p.isActive;
      _tiers = List.from(p.tiers);
    } else {
      _nameController.text = 'Standard PTO Policy';
      _hoursPerDayController.text = '8';
      _hoursPerWeekController.text = '40';
      _waitingPeriodController.text = '12';
      _maxAccrualController.text = '240';
      _maxCarryoverController.text = '40';
      // Default tiers
      _tiers = [
        PtoTier(minYears: 0, maxYears: 1, annualHours: 0, label: 'First Year'),
        PtoTier(minYears: 1, maxYears: 2, annualHours: 40, label: '1 Year'),
        PtoTier(minYears: 2, maxYears: 5, annualHours: 80, label: '2-4 Years'),
        PtoTier(minYears: 5, maxYears: 10, annualHours: 120, label: '5-9 Years'),
        PtoTier(minYears: 10, maxYears: null, annualHours: 160, label: '10+ Years'),
      ];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hoursPerDayController.dispose();
    _hoursPerWeekController.dispose();
    _waitingPeriodController.dispose();
    _maxAccrualController.dispose();
    _maxCarryoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.policy != null ? 'Edit Policy' : 'Create Policy'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Policy Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Policy Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Accrual Method
                  DropdownButtonFormField<AccrualMethod>(
                    value: _accrualMethod,
                    decoration: const InputDecoration(
                      labelText: 'Accrual Method',
                      border: OutlineInputBorder(),
                    ),
                    items: AccrualMethod.values.map((method) {
                      String label;
                      switch (method) {
                        case AccrualMethod.annual:
                          label = 'Annual (lump sum)';
                          break;
                        case AccrualMethod.perPayPeriod:
                          label = 'Per Pay Period';
                          break;
                        case AccrualMethod.hoursWorked:
                          label = 'Based on Hours Worked';
                          break;
                      }
                      return DropdownMenuItem(value: method, child: Text(label));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _accrualMethod = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Hours Settings
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _hoursPerDayController,
                          decoration: const InputDecoration(
                            labelText: 'Hours/Day',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _hoursPerWeekController,
                          decoration: const InputDecoration(
                            labelText: 'Hours/Week',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Waiting Period
                  DropdownButtonFormField<int>(
                    value: int.tryParse(_waitingPeriodController.text) ?? 12,
                    decoration: const InputDecoration(
                      labelText: 'Waiting Period Before PTO Eligible',
                      helperText: 'How long employees must wait before taking PTO',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Immediate (no waiting period)'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('3 months (90 days)'),
                      ),
                      DropdownMenuItem(
                        value: 6,
                        child: Text('6 months'),
                      ),
                      DropdownMenuItem(
                        value: 12,
                        child: Text('1 year (12 months)'),
                      ),
                      DropdownMenuItem(
                        value: 18,
                        child: Text('18 months'),
                      ),
                      DropdownMenuItem(
                        value: 24,
                        child: Text('2 years (24 months)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _waitingPeriodController.text = value.toString();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.amber.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Employees cannot request PTO until this time has passed from their hire date.',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Max Accrual and Carryover
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _maxAccrualController,
                          decoration: const InputDecoration(
                            labelText: 'Max Accrual (hours)',
                            helperText: 'Leave empty for no limit',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxCarryoverController,
                          decoration: const InputDecoration(
                            labelText: 'Max Carryover (hours)',
                            helperText: 'Leave empty for no limit',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Active Toggle
                  SwitchListTile(
                    title: const Text('Policy Active'),
                    subtitle: const Text('Inactive policies cannot be assigned'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),

                  const Divider(height: 32),

                  // Tiers Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PTO Tiers',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: _addTier,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Tier'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._tiers.asMap().entries.map((entry) =>
                    _buildTierEditor(entry.key, entry.value)
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierEditor(int index, PtoTier tier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: tier.label,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  isDense: true,
                ),
                onChanged: (value) {
                  _tiers[index] = PtoTier(
                    minYears: tier.minYears,
                    maxYears: tier.maxYears,
                    annualHours: tier.annualHours,
                    label: value,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: tier.minYears.toString(),
                decoration: const InputDecoration(
                  labelText: 'Min Yrs',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _tiers[index] = PtoTier(
                    minYears: int.tryParse(value) ?? 0,
                    maxYears: tier.maxYears,
                    annualHours: tier.annualHours,
                    label: tier.label,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: tier.maxYears?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Max Yrs',
                  isDense: true,
                  hintText: 'null',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _tiers[index] = PtoTier(
                    minYears: tier.minYears,
                    maxYears: value.isEmpty ? null : int.tryParse(value),
                    annualHours: tier.annualHours,
                    label: tier.label,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: tier.annualHours.toString(),
                decoration: const InputDecoration(
                  labelText: 'Hours',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _tiers[index] = PtoTier(
                    minYears: tier.minYears,
                    maxYears: tier.maxYears,
                    annualHours: double.tryParse(value) ?? 0,
                    label: tier.label,
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _tiers.length > 1 ? () => _removeTier(index) : null,
            ),
          ],
        ),
      ),
    );
  }

  void _addTier() {
    setState(() {
      final lastTier = _tiers.isNotEmpty ? _tiers.last : null;
      _tiers.add(PtoTier(
        minYears: lastTier?.maxYears ?? _tiers.length,
        maxYears: null,
        annualHours: (lastTier?.annualHours ?? 0) + 40,
        label: 'New Tier',
      ));
    });
  }

  void _removeTier(int index) {
    setState(() {
      _tiers.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final policy = PtoPolicyModel(
      id: widget.policy?.id ?? '',
      companyId: widget.companyId,
      name: _nameController.text.trim(),
      isActive: _isActive,
      isDefault: widget.policy?.isDefault ?? false,
      accrualMethod: _accrualMethod,
      tiers: _tiers,
      hoursPerDay: double.tryParse(_hoursPerDayController.text) ?? 8,
      hoursPerWeek: double.tryParse(_hoursPerWeekController.text) ?? 40,
      waitingPeriodMonths: int.tryParse(_waitingPeriodController.text) ?? 12,
      maxAccrualHours: _maxAccrualController.text.isEmpty
          ? null
          : double.tryParse(_maxAccrualController.text),
      maxCarryoverHours: _maxCarryoverController.text.isEmpty
          ? null
          : double.tryParse(_maxCarryoverController.text),
      createdAt: widget.policy?.createdAt ?? DateTime.now(),
    );

    await widget.onSave(policy);
    setState(() => _isSaving = false);
  }
}
