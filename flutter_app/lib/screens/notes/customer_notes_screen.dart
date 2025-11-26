import 'package:flutter/material.dart';
import '../../models/customer_note.dart';
import '../../services/customer_note_service.dart';

class CustomerNotesScreen extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CustomerNotesScreen({
    Key? key,
    required this.companyId,
    required this.companyName,
  }) : super(key: key);

  @override
  State<CustomerNotesScreen> createState() => _CustomerNotesScreenState();
}

class _CustomerNotesScreenState extends State<CustomerNotesScreen>
    with SingleTickerProviderStateMixin {
  final CustomerNoteService _noteService = CustomerNoteService();
  late TabController _tabController;

  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createNote() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateNoteSheet(companyId: widget.companyId),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note created successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Notes'),
            Text(
              widget.companyName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Notes'),
            Tab(text: 'Follow-ups'),
            Tab(text: 'By Type'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllNotesTab(),
          _buildFollowUpsTab(),
          _buildByTypeTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        icon: const Icon(Icons.add),
        label: const Text('Add Note'),
      ),
    );
  }

  Widget _buildAllNotesTab() {
    return StreamBuilder<List<CustomerNote>>(
      stream: _noteService.getNotesForCompany(widget.companyId, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final notes = snapshot.data ?? [];

        if (notes.isEmpty) {
          return _buildEmptyState(
            Icons.note_outlined,
            'No notes yet',
            'Add your first note to track interactions',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          itemBuilder: (context, index) => _buildNoteCard(notes[index]),
        );
      },
    );
  }

  Widget _buildFollowUpsTab() {
    return StreamBuilder<List<CustomerNote>>(
      stream: _noteService.getNotesWithFollowUp(
        companyId: widget.companyId,
        onlyOverdue: false,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final notes = snapshot.data ?? [];

        if (notes.isEmpty) {
          return _buildEmptyState(
            Icons.schedule,
            'No follow-ups',
            'All follow-ups are completed',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          itemBuilder: (context, index) => _buildNoteCard(notes[index]),
        );
      },
    );
  }

  Widget _buildByTypeTab() {
    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildFilterChip('All', 'all'),
              _buildFilterChip('Interaction', NoteType.interaction),
              _buildFilterChip('Onboarding', NoteType.onboardingCall),
              _buildFilterChip('Support', NoteType.supportCall),
              _buildFilterChip('Feedback', NoteType.feedback),
              _buildFilterChip('Feature Request', NoteType.featureRequest),
              _buildFilterChip('Upsell', NoteType.upsellOpportunity),
              _buildFilterChip('Churn Risk', NoteType.churnRisk),
              _buildFilterChip('Success', NoteType.successStory),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: _filterType == 'all'
              ? _buildAllNotesTab()
              : StreamBuilder<List<CustomerNote>>(
                  stream: _noteService.getNotesByType(
                    widget.companyId,
                    _filterType,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final notes = snapshot.data ?? [];

                    if (notes.isEmpty) {
                      return _buildEmptyState(
                        Icons.filter_list_off,
                        'No notes of this type',
                        'Try a different filter',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notes.length,
                      itemBuilder: (context, index) =>
                          _buildNoteCard(notes[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterType = type);
        },
      ),
    );
  }

  Widget _buildNoteCard(CustomerNote note) {
    final typeIcon = NoteType.getIcon(note.noteType);
    final sentimentIcon = NoteSentiment.getIcon(note.sentiment);
    final sentimentColor = NoteSentiment.getColor(note.sentiment);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(typeIcon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  note.noteType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                Text(sentimentIcon, style: TextStyle(fontSize: 20, color: sentimentColor)),
                if (note.hasFollowUp && !note.followUpCompleted) ...[
                  const SizedBox(width: 8),
                  Icon(
                    note.isOverdue ? Icons.warning : Icons.schedule,
                    size: 20,
                    color: note.isOverdue ? Colors.red : Colors.orange,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Note Content
            Text(
              note.note,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Tags
            if (note.tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: note.tags.map((tag) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[800],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Follow-up Info
            if (note.hasFollowUp && !note.followUpCompleted) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: note.isOverdue ? Colors.red[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      note.isOverdue ? Icons.warning : Icons.schedule,
                      size: 16,
                      color: note.isOverdue ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note.isOverdue
                            ? 'Follow-up overdue!'
                            : 'Follow-up: ${_formatDate(note.followUpDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: note.isOverdue ? Colors.red[900] : Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _markFollowUpComplete(note.id),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Complete'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      note.createdByName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(note.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markFollowUpComplete(String noteId) async {
    try {
      await _noteService.markFollowUpComplete(noteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up marked as complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return '${now.difference(date).inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

class _CreateNoteSheet extends StatefulWidget {
  final String companyId;

  const _CreateNoteSheet({required this.companyId});

  @override
  _CreateNoteSheetState createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<_CreateNoteSheet> {
  final _formKey = GlobalKey<FormState>();
  final CustomerNoteService _noteService = CustomerNoteService();
  final TextEditingController _noteController = TextEditingController();

  String _selectedType = NoteType.interaction;
  String _selectedSentiment = NoteSentiment.neutral;
  bool _followUpRequired = false;
  DateTime? _followUpDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _noteService.createNote(
        companyId: widget.companyId,
        note: _noteController.text.trim(),
        noteType: _selectedType,
        sentiment: _selectedSentiment,
        followUpRequired: _followUpRequired,
        followUpDate: _followUpDate,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Note',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Note Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Note Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  NoteType.interaction,
                  NoteType.onboardingCall,
                  NoteType.supportCall,
                  NoteType.feedback,
                  NoteType.featureRequest,
                  NoteType.upsellOpportunity,
                  NoteType.churnRisk,
                  NoteType.successStory,
                ]
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.replaceAll('_', ' ').toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),

              // Sentiment
              DropdownButtonFormField<String>(
                value: _selectedSentiment,
                decoration: const InputDecoration(
                  labelText: 'Sentiment',
                  border: OutlineInputBorder(),
                ),
                items: [
                  NoteSentiment.positive,
                  NoteSentiment.neutral,
                  NoteSentiment.negative,
                ]
                    .map((sentiment) => DropdownMenuItem(
                          value: sentiment,
                          child:
                              Text(sentiment.replaceAll('_', ' ').toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedSentiment = value!),
              ),
              const SizedBox(height: 16),

              // Note Content
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Enter your note...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a note';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Follow-up Checkbox
              CheckboxListTile(
                value: _followUpRequired,
                onChanged: (value) {
                  setState(() {
                    _followUpRequired = value!;
                    if (_followUpRequired && _followUpDate == null) {
                      _followUpDate = DateTime.now().add(const Duration(days: 7));
                    }
                  });
                },
                title: const Text('Requires Follow-up'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              // Follow-up Date
              if (_followUpRequired) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _followUpDate != null
                        ? '${_followUpDate!.month}/${_followUpDate!.day}/${_followUpDate!.year}'
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _followUpDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _followUpDate = date);
                    }
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitNote,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Note'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
