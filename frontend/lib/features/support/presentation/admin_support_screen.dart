import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_models.dart';
import '../data/support_repository.dart';
import '../providers/support_provider.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  SupportSummary? _summary;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await ref.read(adminSupportProvider.notifier).getSummary();
    if (mounted) setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSupportProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(adminSupportProvider.notifier).load();
              _loadSummary();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          if (_summary != null) _buildSummaryCards(theme),
          // Filter
          _buildFilterRow(theme),
          // List
          Expanded(
            child: switch (state) {
              SupportLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              SupportError(:final message, :final onRetry) => _buildError(
                message,
                onRetry,
              ),
              SupportSuccess(:final tickets) => _buildList(context, tickets),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: [
          _SummaryCard(
            label: 'Total',
            value: '${_summary!.total}',
            color: theme.colorScheme.primary,
          ),
          _SummaryCard(
            label: 'Open',
            value: '${_summary!.open}',
            color: Colors.orange,
          ),
          _SummaryCard(
            label: 'In Progress',
            value: '${_summary!.inProgress}',
            color: Colors.blue,
          ),
          _SummaryCard(
            label: 'Resolved',
            value: '${_summary!.resolved}',
            color: Colors.green,
          ),
          _SummaryCard(
            label: 'Closed',
            value: '${_summary!.closed}',
            color: theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(ThemeData theme) {
    const statuses = ['All', 'Open', 'In Progress', 'Resolved', 'Closed'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((s) {
            final selected = _statusFilter == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: selected,
                onSelected: (v) => setState(() => _statusFilter = s),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<SupportTicket> tickets) {
    final filtered = _statusFilter == 'All'
        ? tickets
        : tickets.where((t) => t.status == _statusFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No ${_statusFilter.toLowerCase()} tickets',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _TicketCard(
        ticket: filtered[index],
        onTap: () => _showActionSheet(context, filtered[index]),
      ),
    );
  }

  void _showActionSheet(BuildContext context, SupportTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AdminTicketActionSheet(
        ticket: ticket,
        onAction: () {
          ref.read(adminSupportProvider.notifier).load();
          _loadSummary();
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      ticket.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ticket.userName.isNotEmpty ? ticket.userName : 'Unknown',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ticket.userRole,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ticket.category,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${ticket.messageCount} msgs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.flag, size: 12, color: _priorityColor(theme)),
                  const SizedBox(width: 4),
                  Text(
                    ticket.priority,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _priorityColor(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(ticket.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
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

  Color _statusColor(ThemeData theme) {
    switch (ticket.status) {
      case 'Open':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      case 'Resolved':
        return Colors.green;
      case 'Closed':
        return theme.colorScheme.outline;
      default:
        return theme.colorScheme.outline;
    }
  }

  Color _priorityColor(ThemeData theme) {
    switch (ticket.priority) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.amber;
      case 'Low':
        return Colors.green;
      default:
        return theme.colorScheme.outline;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _AdminTicketActionSheet extends ConsumerStatefulWidget {
  final SupportTicket ticket;
  final VoidCallback onAction;

  const _AdminTicketActionSheet({required this.ticket, required this.onAction});

  @override
  ConsumerState<_AdminTicketActionSheet> createState() =>
      _AdminTicketActionSheetState();
}

class _AdminTicketActionSheetState
    extends ConsumerState<_AdminTicketActionSheet> {
  final _replyController = TextEditingController();
  bool _sending = false;
  bool _updating = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticket = widget.ticket;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ticket: ${ticket.subject}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Info
                _InfoRow(label: 'User', value: ticket.userName),
                _InfoRow(label: 'Role', value: ticket.userRole),
                _InfoRow(label: 'Category', value: ticket.category),
                _InfoRow(label: 'Priority', value: ticket.priority),
                _InfoRow(label: 'Status', value: ticket.status),
                if (ticket.assignedAdmin != null)
                  _InfoRow(label: 'Assigned', value: ticket.assignedAdmin!),
                const SizedBox(height: 8),
                Text(
                  'Description:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(ticket.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),

                // Status actions
                if (ticket.isOpen || ticket.isInProgress) ...[
                  Text(
                    'Actions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      if (ticket.isOpen)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _updating
                                ? null
                                : () => _updateStatus('In Progress'),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Accept'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      if (ticket.isInProgress) ...[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _updating
                                ? null
                                : () => _updateStatus('Resolved'),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Resolve'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _updating
                                ? null
                                : () => _updateStatus('Closed'),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Close'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Reply section
                Text(
                  'Reply',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _replyController,
                  decoration: const InputDecoration(
                    hintText: 'Type your reply...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _sendReply,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.reply),
                    label: Text(_sending ? 'Sending...' : 'Send Reply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    try {
      await ref.read(adminSupportProvider.notifier).updateTicket(
        widget.ticket.id,
        {'status': status, 'assigned_admin': 'admin-current'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket $status'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onAction();
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a reply'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .replyToTicket(widget.ticket.id, text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onAction();
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
