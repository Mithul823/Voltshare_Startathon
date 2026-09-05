import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_models.dart';
import '../providers/admin_mgmt_provider.dart';

/// Admin Audit Logs screen — replaces the development placeholder.
class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  String? _eventTypeFilter;
  String? _severityFilter;

  void _applyFilters({int page = 1}) {
    ref
        .read(adminAuditProvider.notifier)
        .load(
          eventType: _eventTypeFilter,
          severity: _severityFilter,
          page: page,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAuditProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildSummaryRow(context, state),
          _buildFilterChips(context),
          const Divider(height: 1),
          Expanded(child: _buildAuditList(context, state)),
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
            Icons.policy_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Audit Logs',
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

  Widget _buildSummaryRow(BuildContext context, AdminAuditState state) {
    if (state is! AdminAuditSuccess) return const SizedBox.shrink();
    final warning = state.data.items
        .where((l) => l.severity == 'warning')
        .length;
    final critical = state.data.items
        .where((l) => l.severity == 'critical')
        .length;
    final adminActions = state.data.items
        .where((l) => l.eventType == 'admin_action')
        .length;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _SummaryChip(
            label: 'Total today',
            value: '${state.data.items.length}',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Warnings',
            value: '$warning',
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Critical',
            value: '$critical',
            color: Colors.red,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Admin',
            value: '$adminActions',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final eventTypes = [
      ('All', null),
      ('Admin', 'admin_action'),
      ('Auth', 'authentication'),
      ('Marketplace', 'marketplace'),
      ('Financial', 'financial'),
      ('Security', 'security'),
      ('Dispute', 'dispute'),
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: eventTypes.map((type) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(
                type.$1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _eventTypeFilter == type.$2
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              selected: _eventTypeFilter == type.$2,
              onSelected: (_) {
                setState(() => _eventTypeFilter = type.$2);
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

  Widget _buildAuditList(BuildContext context, AdminAuditState state) {
    return switch (state) {
      AdminAuditLoading() => const Center(child: CircularProgressIndicator()),
      AdminAuditError(:final message) => _buildError(context, message),
      AdminAuditSuccess(:final data) => _buildAuditItems(context, data),
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

  Widget _buildAuditItems(BuildContext context, PaginatedAuditLogs data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.policy_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No audit activity found.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Try adjusting your filters.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _applyFilters(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.items.length,
        itemBuilder: (context, index) {
          return _AuditItem(
            log: data.items[index],
            onTap: () => _showAuditDetail(context, data.items[index]),
          );
        },
      ),
    );
  }

  void _showAuditDetail(BuildContext context, AdminAuditLog log) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AuditDetailSheet(log: log),
    );
  }
}

class _AuditItem extends StatelessWidget {
  const _AuditItem({required this.log, required this.onTap});
  final AdminAuditLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _eventIcon(log.eventType);
    final color = _severityColor(log.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.action.replaceAll('_', ' '),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (log.summary.isNotEmpty)
                      Text(
                        log.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (log.actorName != null) ...[
                          Text(
                            log.actorName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.severity,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (log.timestamp != null)
                          Text(
                            _formatRelative(log.timestamp!),
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
            ],
          ),
        ),
      ),
    );
  }

  IconData _eventIcon(String type) {
    return switch (type) {
      'authentication' => Icons.login_outlined,
      'admin_action' => Icons.admin_panel_settings_outlined,
      'marketplace' => Icons.storefront_outlined,
      'financial' => Icons.account_balance_outlined,
      'security' => Icons.security_outlined,
      'dispute' => Icons.forum_outlined,
      'settlement' => Icons.check_circle_outlined,
      _ => Icons.info_outline,
    };
  }

  Color _severityColor(String severity) {
    return switch (severity) {
      'critical' => Colors.red,
      'warning' => Colors.orange,
      'info' => Colors.blue,
      _ => Colors.grey,
    };
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _AuditDetailSheet extends StatelessWidget {
  const _AuditDetailSheet({required this.log});
  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            'Event Details',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Action',
            value: log.action.replaceAll('_', ' '),
            context: context,
          ),
          _DetailRow(
            label: 'Event Type',
            value: log.eventType,
            context: context,
          ),
          _DetailRow(label: 'Severity', value: log.severity, context: context),
          if (log.actorName != null)
            _DetailRow(label: 'Actor', value: log.actorName!, context: context),
          if (log.actorRole != null)
            _DetailRow(label: 'Role', value: log.actorRole!, context: context),
          if (log.resourceType != null)
            _DetailRow(
              label: 'Resource',
              value: log.resourceType!,
              context: context,
            ),
          if (log.resourceId != null)
            _DetailRow(
              label: 'Resource ID',
              value: log.resourceId!,
              context: context,
            ),
          if (log.summary.isNotEmpty)
            _DetailRow(label: 'Summary', value: log.summary, context: context),
          if (log.status != null)
            _DetailRow(label: 'Status', value: log.status!, context: context),
          if (log.metadataSummary != null)
            _DetailRow(
              label: 'Metadata',
              value: log.metadataSummary!,
              context: context,
            ),
          if (log.timestamp != null)
            _DetailRow(
              label: 'Timestamp',
              value: _formatDate(log.timestamp!),
              context: context,
            ),
          if (log.sourceIp != null)
            _DetailRow(
              label: 'Source IP',
              value: log.sourceIp!,
              context: context,
            ),
          const SizedBox(height: 8),
          Text(
            log.id,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _DetailRow({
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              fontSize: 13,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}
