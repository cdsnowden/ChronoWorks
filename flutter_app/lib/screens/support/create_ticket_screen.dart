import 'package:flutter/material.dart';
import '../../models/support_ticket.dart';
import '../../services/support_ticket_service.dart';

class CreateTicketScreen extends StatefulWidget {
  final String companyId;

  const CreateTicketScreen({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupportTicketService _ticketService = SupportTicketService();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = TicketCategory.technicalIssue;
  String _selectedPriority = TicketPriority.medium;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final ticketId = await _ticketService.createTicket(
        companyId: widget.companyId,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, ticketId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Support Ticket'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Our support team will respond to your ticket within 24 hours.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Subject
              const Text(
                'Subject *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'Brief description of the issue',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  if (value.trim().length < 5) {
                    return 'Subject must be at least 5 characters';
                  }
                  return null;
                },
                maxLength: 100,
              ),
              const SizedBox(height: 20),

              // Category
              const Text(
                'Category *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                items: [
                  DropdownMenuItem(
                    value: TicketCategory.technicalIssue,
                    child: Row(
                      children: [
                        Icon(Icons.bug_report, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Technical Issue'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketCategory.featureRequest,
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text('Feature Request'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketCategory.billing,
                    child: Row(
                      children: [
                        Icon(Icons.attach_money, size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Billing'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketCategory.accountManagement,
                    child: Row(
                      children: [
                        Icon(Icons.account_circle,
                            size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Account Management'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketCategory.dataExport,
                    child: Row(
                      children: [
                        Icon(Icons.file_download,
                            size: 20, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Text('Data Export'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketCategory.general,
                    child: Row(
                      children: [
                        Icon(Icons.help, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('General Inquiry'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value!);
                },
              ),
              const SizedBox(height: 20),

              // Priority
              const Text(
                'Priority *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                items: [
                  DropdownMenuItem(
                    value: TicketPriority.low,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Low - Not urgent'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketPriority.medium,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Medium - Normal priority'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketPriority.high,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('High - Important'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: TicketPriority.urgent,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Urgent - Critical issue'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedPriority = value!);
                },
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Description *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Please provide detailed information...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.trim().length < 20) {
                    return 'Description must be at least 20 characters';
                  }
                  return null;
                },
                maxLength: 2000,
              ),
              const SizedBox(height: 24),

              // Guidelines Card
              Card(
                color: Colors.amber[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates,
                              color: Colors.amber[800]),
                          const SizedBox(width: 8),
                          Text(
                            'Tips for better support',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Be specific about the issue\n'
                        '• Include steps to reproduce the problem\n'
                        '• Mention any error messages you see\n'
                        '• Include relevant screenshots if possible',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Ticket',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
