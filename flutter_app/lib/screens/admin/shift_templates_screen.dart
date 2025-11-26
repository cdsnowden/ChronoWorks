import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shift_template_model.dart';
import '../../services/shift_template_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/constants.dart';

class ShiftTemplatesScreen extends StatefulWidget {
  const ShiftTemplatesScreen({super.key});

  @override
  State<ShiftTemplatesScreen> createState() => _ShiftTemplatesScreenState();
}

class _ShiftTemplatesScreenState extends State<ShiftTemplatesScreen> {
  final ShiftTemplateService _templateService = ShiftTemplateService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    final companyId = currentUser.companyId;
    if (companyId == null) {
      return const Scaffold(
        body: Center(child: Text('No company associated with your account')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Templates'),
      ),
      body: StreamBuilder<List<ShiftTemplateModel>>(
        stream: _templateService.getCompanyTemplatesStream(companyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No shift templates yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first template to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return _buildTemplateCard(template, companyId);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateDialog(null, currentUser.id, companyId),
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
    );
  }

  Widget _buildTemplateCard(ShiftTemplateModel template, String companyId) {
    // Allow editing all templates (both global and company-specific)
    final canEdit = true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: template.isGlobal ? const Color(0xFF6A1B9A) : const Color(0xFF0D47A1),
          child: Icon(
            template.isGlobal ? Icons.public : Icons.business,
            color: Colors.white,
          ),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              template.formattedTimeRange,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '${template.durationHours.toStringAsFixed(1)} hours',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF0D47A1)),
                    onPressed: () => _showTemplateDialog(template, template.createdBy ?? '', companyId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFC62828)),
                    onPressed: () => _confirmDelete(template),
                  ),
                ],
              )
            : Chip(
                label: const Text('Global', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF6A1B9A),
              ),
      ),
    );
  }

  void _showTemplateDialog(ShiftTemplateModel? template, String userId, String companyId) {
    showDialog(
      context: context,
      builder: (context) => _TemplateDialog(
        template: template,
        userId: userId,
        companyId: companyId,
        onSave: (name, startTime, endTime, hasLunchBreak, isDayOff, dayOffType, paidHours, isGlobal) async {
          try {
            if (template == null) {
              // Create new template
              await _templateService.createTemplate(
                name: name,
                startTime: startTime,
                endTime: endTime,
                hasLunchBreak: hasLunchBreak,
                isDayOff: isDayOff,
                dayOffType: dayOffType,
                paidHours: paidHours,
                createdBy: userId,
                companyId: companyId,
                isGlobal: isGlobal,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template created successfully')),
                );
              }
            } else {
              // Update existing template
              await _templateService.updateTemplate(
                templateId: template.id,
                name: name,
                startTime: startTime,
                endTime: endTime,
                hasLunchBreak: hasLunchBreak,
                isDayOff: isDayOff,
                dayOffType: dayOffType,
                paidHours: paidHours,
                isGlobal: isGlobal,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template updated successfully')),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFC62828)),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDelete(ShiftTemplateModel template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _templateService.deleteTemplate(template.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Template deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: const Color(0xFFC62828),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
  }
}

class _TemplateDialog extends StatefulWidget {
  final ShiftTemplateModel? template;
  final String userId;
  final String companyId;
  final Function(String name, TimeOfDay? startTime, TimeOfDay? endTime, bool hasLunchBreak, bool isDayOff, String? dayOffType, double? paidHours, bool isGlobal) onSave;

  const _TemplateDialog({
    this.template,
    required this.userId,
    required this.companyId,
    required this.onSave,
  });

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late TextEditingController _nameController;
  late TextEditingController _paidHoursController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isGlobal;
  late bool _hasLunchBreak;
  late bool _isDayOff;
  late String _dayOffType;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.template?.name ?? '',
    );
    _paidHoursController = TextEditingController(
      text: widget.template?.paidHours?.toString() ?? '8.0',
    );
    _startTime = widget.template?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = widget.template?.endTime ?? const TimeOfDay(hour: 17, minute: 0);
    _isGlobal = widget.template?.isGlobal ?? false;
    _hasLunchBreak = widget.template?.hasLunchBreak ?? false;
    _isDayOff = widget.template?.isDayOff ?? false;
    _dayOffType = widget.template?.dayOffType ?? 'unpaid';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paidHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? 'New Shift Template' : 'Edit Shift Template'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  hintText: 'e.g., Morning Shift',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Day Off'),
                subtitle: const Text('This is a day off template'),
                value: _isDayOff,
                onChanged: (value) => setState(() => _isDayOff = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_isDayOff) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _dayOffType,
                  decoration: const InputDecoration(
                    labelText: 'Day Off Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'holiday', child: Text('Holiday')),
                  ],
                  onChanged: (value) => setState(() => _dayOffType = value ?? 'unpaid'),
                ),
                if (_dayOffType == 'paid' || _dayOffType == 'holiday') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _paidHoursController,
                    decoration: const InputDecoration(
                      labelText: 'Paid Hours',
                      hintText: '8.0',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter paid hours';
                      }
                      final hours = double.tryParse(value);
                      if (hours == null || hours <= 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ],
              if (!_isDayOff) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeField(
                        label: 'Start Time',
                        time: _startTime,
                        onTimePicked: (time) => setState(() => _startTime = time),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeField(
                        label: 'End Time',
                        time: _endTime,
                        onTimePicked: (time) => setState(() => _endTime = time),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Lunch Break'),
                  subtitle: const Text('Deduct 1 hour for unpaid lunch'),
                  value: _hasLunchBreak,
                  onChanged: (value) => setState(() => _hasLunchBreak = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Global Template'),
                subtitle: const Text('Available to all users'),
                value: _isGlobal,
                onChanged: (value) => setState(() => _isGlobal = value),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0D47A1), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDurationText(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay time,
    required Function(TimeOfDay) onTimePicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onTimePicked(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          time.format(context),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  double _calculateDuration() {
    if (_isDayOff) return 0.0;

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    double duration = (endMinutes - startMinutes) / 60.0;

    // Deduct 1 hour for lunch break if checked
    if (_hasLunchBreak) {
      duration -= 1.0;
    }

    return duration;
  }

  String _getDurationText() {
    if (_isDayOff) {
      if (_dayOffType == 'paid') {
        final hours = double.tryParse(_paidHoursController.text) ?? 0;
        return 'Paid Day Off: ${hours.toStringAsFixed(1)} hours paid (not counted in schedule hours)';
      } else if (_dayOffType == 'holiday') {
        final hours = double.tryParse(_paidHoursController.text) ?? 0;
        return 'Holiday: ${hours.toStringAsFixed(1)} hours paid (not counted in schedule hours)';
      } else {
        return 'Unpaid Day Off (not counted in schedule hours)';
      }
    }

    final duration = _calculateDuration();
    return 'Duration: ${duration.toStringAsFixed(1)} hours${_hasLunchBreak ? ' (includes 1hr lunch deduction)' : ''}';
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (!_isDayOff) {
        final duration = _calculateDuration();
        if (duration <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
              backgroundColor: Color(0xFFC62828),
            ),
          );
          return;
        }
      }

      double? paidHours;
      if (_isDayOff && (_dayOffType == 'paid' || _dayOffType == 'holiday')) {
        paidHours = double.tryParse(_paidHoursController.text);
      }

      widget.onSave(
        _nameController.text.trim(),
        _isDayOff ? null : _startTime,
        _isDayOff ? null : _endTime,
        _hasLunchBreak,
        _isDayOff,
        _isDayOff ? _dayOffType : null,
        paidHours,
        _isGlobal,
      );
      Navigator.pop(context);
    }
  }
}
