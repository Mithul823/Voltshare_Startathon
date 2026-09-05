import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_models.dart';
import '../providers/admin_mgmt_provider.dart';

/// Admin Review Disputes screen — replaces the development placeholder.
class AdminDisputesScreen extends ConsumerStatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  ConsumerState<AdminDisputesScreen> createState() =>
      _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends ConsumerState<AdminDisputesScreen> {
  String? _statusFilter;
  String? _priorityFilter;

  void _applyFilters({int page = 1}) {
    ref
        .read(adminDisputesProvider.notifier)
        .load(status: _statusFilter, priority: _priorityFilter, page: page);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminDisputesProvider);
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildSummaryRow(context),
          _buildFilterTabs(context),
          const Divider(height: 1),
          Expanded(child: _buildDisputeList(context, state)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Icon(
            Icons.forum_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Review Disputes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _applyFilters(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context) {
    final state = ref.watch(adminDisputesProvider);
    final open = state is AdminDisputesSuccess
        ? state.data.items.where((d) => d.status == 'open').length
        : 0;
    final resolved = state is AdminDisputesSuccess
        ? state.data.items.where((d) => d.status == 'resolved').length
        : 0;
    final critical = state is AdminDisputesSuccess
        ? state.data.items.where((d) => d.priority == 'critical').length
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _SummaryChip(label: 'Open', value: '$open', color: Colors.orange),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Resolved',
            value: '$resolved',
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Critical',
            value: '$critical',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    final statuses = [
      ('All', null),
      ('Open', 'open'),
      ('Under Review', 'under_review'),
      ('Resolved', 'resolved'),
      ('Rejected', 'rejected'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: statuses.map((status) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(
                status.$1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _statusFilter == status.$2
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              selected: _statusFilter == status.$2,
              onSelected: (_) {
                setState(() => _statusFilter = status.$2);
                _applyFilters();
              },
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDisputeList(BuildContext context, AdminDisputesState state) {
    return switch (state) {
      AdminDisputesLoading() => const Center(
        child: CircularProgressIndicator(),
      ),
      AdminDisputesError(:final message) => _buildError(context, message),
      AdminDisputesSuccess(:final data) => _buildDisputeItems(context, data),
    };
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _applyFilters(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisputeItems(BuildContext context, PaginatedAdminDisputes data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No disputes require review.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('All disputes have been addressed.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _applyFilters(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: data.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _DisputeCard(
            dispute: data.items[index],
            onTap: () => _showDisputeDetail(context, data.items[index]),
          );
        },
      ),
    );
  }

  void _showDisputeDetail(BuildContext context, AdminDisputeSummary dispute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DisputeDetailSheet(
        dispute: dispute,
        onResolve: (request) async {
          try {
            final result = await ref
                .read(adminDisputesProvider.notifier)
                .resolveDispute(dispute.id, request);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result.message)));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to resolve dispute: $e')),
              );
            }
          }
        },
        onReject: (request) async {
          try {
            final result = await ref
                .read(adminDisputesProvider.notifier)
                .rejectDispute(dispute.id, request);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result.message)));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to reject dispute: $e')),
              );
            }
          }
        },
        onAssign: () async {
          try {
            final result = await ref
                .read(adminDisputesProvider.notifier)
                .assignDispute(dispute.id);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result.message)));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to assign dispute: $e')),
            );
          }
        },
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.dispute, required this.onTap});
  final AdminDisputeSummary dispute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(dispute.status);
    final priorityColor = _priorityColor(dispute.priority);

    return Card(
      margin: EdgeInsets.zero,
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
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dispute.priority,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dispute.status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${dispute.id.length > 8 ? dispute.id.substring(0, 8) : dispute.id}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dispute.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (dispute.buyerName != null) ...[
                    Icon(
                      Icons.person_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dispute.buyerName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (dispute.listingTitle != null) ...[
                    Icon(
                      Icons.bolt_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dispute.listingTitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    dispute.amountInr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (dispute.createdAt != null)
                    Text(
                      _formatRelative(dispute.createdAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
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

  Color _statusColor(String status) {
    return switch (status) {
      'open' => Colors.orange,
      'under_review' => Colors.blue,
      'resolved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'low' => Colors.grey,
      'medium' => Colors.orange,
      'high' => Colors.red.shade400,
      'critical' => Colors.red,
      _ => Colors.grey,
    };
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _DisputeDetailSheet extends StatefulWidget {
  const _DisputeDetailSheet({
    required this.dispute,
    required this.onResolve,
    required this.onReject,
    required this.onAssign,
  });
  final AdminDisputeSummary dispute;
  final Future<void> Function(DisputeResolutionRequest) onResolve;
  final Future<void> Function(DisputeResolutionRequest) onReject;
  final VoidCallback onAssign;

  @override
  State<_DisputeDetailSheet> createState() => _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends State<_DisputeDetailSheet> {
  final _reasonController = TextEditingController();
  final _refundController = TextEditingController();
  final _releaseController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _refundController.dispose();
    _releaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispute;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.45,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dispute Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _DetailField(label: 'ID', value: d.id, context: context),
            if (d.reason.isNotEmpty)
              _DetailField(label: 'Reason', value: d.reason, context: context),
            if (d.buyerName != null)
              _DetailField(
                label: 'Buyer',
                value: d.buyerName!,
                context: context,
              ),
            if (d.sellerName != null)
              _DetailField(
                label: 'Seller',
                value: d.sellerName!,
                context: context,
              ),
            if (d.listingTitle != null)
              _DetailField(
                label: 'Listing',
                value: d.listingTitle!,
                context: context,
              ),
            _DetailField(label: 'Amount', value: d.amountInr, context: context),
            _DetailField(
              label: 'Status',
              value: d.status.replaceAll('_', ' '),
              context: context,
            ),
            _DetailField(
              label: 'Priority',
              value: d.priority,
              context: context,
            ),
            if (d.createdAt != null)
              _DetailField(
                label: 'Submitted',
                value: _formatDate(d.createdAt!),
                context: context,
              ),
            const Divider(height: 24),
            if (d.status == 'open' || d.status == 'under_review') ...[
              Text(
                'Actions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Resolution note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _refundController,
                      decoration: const InputDecoration(
                        labelText: 'Refund (paise)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _releaseController,
                      decoration: const InputDecoration(
                        labelText: 'Release (paise)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _onResolve,
                      child: const Text('Resolve'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onAssign,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Assign to me'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onResolve() async {
    setState(() => _isSubmitting = true);
    await widget.onResolve(
      DisputeResolutionRequest(
        resolution: 'resolved',
        reason: _reasonController.text,
        refundAmountPaise: int.tryParse(_refundController.text) ?? 0,
        releaseToSellerPaise: int.tryParse(_releaseController.text) ?? 0,
      ),
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _onReject() async {
    setState(() => _isSubmitting = true);
    await widget.onReject(
      DisputeResolutionRequest(
        resolution: 'rejected',
        reason: _reasonController.text,
      ),
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    required this.context,
  });
  final String label;
  final String value;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}
