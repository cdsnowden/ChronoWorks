import 'package:flutter/material.dart';
import '../../models/support_ticket.dart';
import '../../services/support_ticket_service.dart';
import 'ticket_detail_screen.dart';
import 'create_ticket_screen.dart';

class TicketsListScreen extends StatefulWidget {
  final String? accountManagerId;
  final String? companyId;

  const TicketsListScreen({
    Key? key,
    this.accountManagerId,
    this.companyId,
  }) : super(key: key);

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  final SupportTicketService _ticketService = SupportTicketService();
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'open', child: Text('Open')),
              const PopupMenuItem(
                  value: 'in_progress', child: Text('In Progress')),
              const PopupMenuItem(value: 'resolved', child: Text('Resolved')),
              const PopupMenuItem(value: 'closed', child: Text('Closed')),
            ],
          ),
        ],
      ),
      body: _buildTicketsList(),
      floatingActionButton: widget.companyId != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateTicketScreen(
                      companyId: widget.companyId!,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Ticket'),
            )
          : null,
    );
  }

  Widget _buildTicketsList() {
    Stream<List<SupportTicket>> ticketsStream;

    if (widget.accountManagerId != null) {
      // Account Manager view - show assigned tickets
      ticketsStream = _ticketService.getTicketsForAccountManager(
        widget.accountManagerId!,
        status: _filterStatus == 'all' ? null : _filterStatus,
      );
    } else if (widget.companyId != null) {
      // Company view - show company tickets
      ticketsStream = _ticketService.getTicketsForCompany(
        widget.companyId!,
        status: _filterStatus == 'all' ? null : _filterStatus,
      );
    } else {
      // Super Admin view - show all open tickets
      ticketsStream = _ticketService.getAllOpenTickets();
    }

    return StreamBuilder<List<SupportTicket>>(
      stream: ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final tickets = snapshot.data ?? [];

        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.support_agent_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _filterStatus != 'all'
                      ? 'No ${_filterStatus.replaceAll('_', ' ')} tickets'
                      : 'No tickets yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            return _buildTicketCard(tickets[index]);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    Color statusColor;
    IconData statusIcon;

    switch (ticket.status) {
      case TicketStatus.open:
        statusColor = Colors.orange;
        statusIcon = Icons.new_releases;
        break;
      case TicketStatus.inProgress:
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
        break;
      case TicketStatus.resolved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TicketStatus.closed:
        statusColor = Colors.grey;
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    Color priorityColor;
    switch (ticket.priority) {
      case TicketPriority.urgent:
        priorityColor = Colors.red;
        break;
      case TicketPriority.high:
        priorityColor = Colors.orange;
        break;
      case TicketPriority.medium:
        priorityColor = Colors.blue;
        break;
      case TicketPriority.low:
        priorityColor = Colors.grey;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailScreen(ticketId: ticket.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Priority Badge
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Ticket Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              ticket.ticketNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ticket.priority.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                            if (ticket.escalatedToSuperAdmin) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_upward,
                                  size: 16, color: Colors.red[700]),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.subject,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.companyName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Icon
                  Column(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        ticket.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        ticket.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.message, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${ticket.messages.length} messages',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(ticket.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Assigned To (if applicable)
              if (ticket.assignedToName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Assigned to ${ticket.assignedToName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
