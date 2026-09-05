import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../data/support_models.dart';
import '../providers/support_provider.dart';

class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(supportProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTicketSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
      body: switch (state) {
        SupportLoading() => const Center(child: CircularProgressIndicator()),
        SupportError(:final message, :final onRetry) => _buildError(
          message,
          onRetry,
        ),
        SupportSuccess(:final tickets) => _buildList(context, ref, tickets),
      },
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

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<SupportTicket> tickets,
  ) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No support tickets yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to create one',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) => _SupportTicketCard(
        ticket: tickets[index],
        onTap: () => context.push(AppRoutes.ticketDetail(tickets[index].id)),
      ),
    );
  }

  void _showCreateTicketSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _CreateTicketSheet(ref: ref),
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _SupportTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final priorityColor = _priorityColor(theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.priority,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ticket.category,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
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
              const SizedBox(height: 8),
              Text(
                ticket.subject,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ticket.messageCount} messages',
                    style: theme.textTheme.bodySmall,
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

class _CreateTicketSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _CreateTicketSheet({required this.ref});

  @override
  ConsumerState<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends ConsumerState<_CreateTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'Marketplace';
  String _priority = 'Medium';
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Create Support Ticket',
                    style: theme.textTheme.titleLarge?.copyWith(
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
            const SizedBox(height: 16),

            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Subject is required'
                  : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                'Marketplace',
                'Wallet',
                'Payment',
                'Login',
                'Account',
                'AI Assistant',
                'Energy Trading',
                'Bug',
                'Other',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              items: const [
                'Low',
                'Medium',
                'High',
                'Critical',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Describe your issue (min 10 characters)'
                  : null,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting...' : 'Submit Ticket'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final data = {
        'category': _category,
        'subject': _subjectController.text.trim(),
        'description': _descriptionController.text.trim(),
        'priority': _priority,
      };

      final result = await widget.ref
          .read(supportProvider.notifier)
          .createTicket(data);
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket created successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create ticket'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
