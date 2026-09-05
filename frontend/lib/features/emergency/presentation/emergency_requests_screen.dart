import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../data/emergency_models.dart';
import '../providers/emergency_provider.dart';

class EmergencyRequestsScreen extends ConsumerWidget {
  const EmergencyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emergencyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Assistance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(emergencyProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.emergencyForm),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
        backgroundColor: theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onError,
      ),
      body: switch (state) {
        EmergencyLoading() => const Center(child: CircularProgressIndicator()),
        EmergencyError(:final message, :final onRetry) => _buildError(message, onRetry),
        EmergencySuccess(:final requests) => _buildList(context, ref, requests),
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

  Widget _buildList(BuildContext context, WidgetRef ref, List<EmergencyRequest> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emergency_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No emergency requests yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Tap the button below to create one',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) => _RequestCard(request: requests[index]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final EmergencyRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final priorityColor = _priorityColor(theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    request.priority,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Category & Status
            Row(
              children: [
                _Chip(request.category, Icons.category_outlined),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.statusDisplay,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Energy
            LayoutBuilder(
              builder: (context, constraints) {
                final showAllocated = request.allocatedEnergyKwh > 0 && constraints.maxWidth > 260;
                return Row(
                  children: [
                    Icon(Icons.bolt, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${request.requiredEnergyKwh.toStringAsFixed(1)} kWh required',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (showAllocated) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('${request.allocatedEnergyKwh.toStringAsFixed(1)} kWh allocated',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (request.address != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(request.address!, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            // Time
            Text(
              _formatTime(request.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme) {
    switch (request.status) {
      case 'Pending': return Colors.orange;
      case 'Approved': return Colors.blue;
      case 'Rejected': return Colors.red;
      case 'In Progress': return Colors.amber.shade700;
      case 'Completed': return Colors.green;
      default: return theme.colorScheme.outline;
    }
  }

  Color _priorityColor(ThemeData theme) {
    switch (request.priority) {
      case 'Critical': return Colors.red;
      case 'High': return Colors.orange;
      case 'Medium': return Colors.amber;
      case 'Low': return Colors.green;
      default: return theme.colorScheme.outline;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
