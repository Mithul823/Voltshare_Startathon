import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/emergency_models.dart';
import '../providers/emergency_provider.dart';

class AdminEmergencyScreen extends ConsumerStatefulWidget {
  const AdminEmergencyScreen({super.key});

  @override
  ConsumerState<AdminEmergencyScreen> createState() => _AdminEmergencyScreenState();
}

class _AdminEmergencyScreenState extends ConsumerState<AdminEmergencyScreen> {
  EmergencySummary? _summary;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await ref.read(adminEmergencyProvider.notifier).getSummary();
    if (mounted) setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminEmergencyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(adminEmergencyProvider.notifier).load();
              _loadSummary();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          if (_summary != null) _buildSummaryCards(theme),
          // Filter chips
          _buildFilterRow(theme),
          // List
          Expanded(
            child: switch (state) {
              EmergencyLoading() => const Center(child: CircularProgressIndicator()),
              EmergencyError(:final message, :final onRetry) => _buildError(message, onRetry),
              EmergencySuccess(:final requests) => _buildList(context, requests),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: [
          _SummaryCard(label: 'Total', value: '${_summary!.total}', color: theme.colorScheme.primary),
          _SummaryCard(label: 'Pending', value: '${_summary!.pending}', color: Colors.orange),
          _SummaryCard(label: 'Approved', value: '${_summary!.approved}', color: Colors.blue),
          _SummaryCard(label: 'Rejected', value: '${_summary!.rejected}', color: Colors.red),
          _SummaryCard(label: 'Completed', value: '${_summary!.completed}', color: Colors.green),
          _SummaryCard(label: 'Critical', value: '${_summary!.critical}', color: Colors.red.shade800),
        ],
      ),
    );
  }

  Widget _buildFilterRow(ThemeData theme) {
    const statuses = ['All', 'Pending', 'Approved', 'Rejected', 'In Progress', 'Completed'];
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
                label: Text(s, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
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

  Widget _buildList(BuildContext context, List<EmergencyRequest> requests) {
    final filtered = _statusFilter == 'All'
        ? requests
        : requests.where((r) => r.status == _statusFilter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No ${_statusFilter.toLowerCase()} emergency requests',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _AdminRequestCard(
        request: filtered[index],
        onAction: () => _showActionSheet(context, filtered[index]),
      ),
    );
  }

  void _showActionSheet(BuildContext context, EmergencyRequest request) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => _AdminRequestActionSheet(
        request: request,
        onAction: () => ref.read(adminEmergencyProvider.notifier).load(),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              )),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _AdminRequestCard extends StatelessWidget {
  final EmergencyRequest request;
  final VoidCallback onAction;

  const _AdminRequestCard({required this.request, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final priorityColor = _priorityColor(theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onAction,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    flex: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(request.priority,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priorityColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(request.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(request.statusDisplay,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      request.consumerName.isNotEmpty ? request.consumerName : 'Unknown',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.bolt, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${request.requiredEnergyKwh.toStringAsFixed(0)} kWh',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(request.category, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text(_formatTime(request.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ],
          ),
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _AdminRequestActionSheet extends ConsumerStatefulWidget {
  final EmergencyRequest request;
  final VoidCallback onAction;

  const _AdminRequestActionSheet({required this.request, required this.onAction});

  @override
  ConsumerState<_AdminRequestActionSheet> createState() => _AdminRequestActionSheetState();
}

class _AdminRequestActionSheetState extends ConsumerState<_AdminRequestActionSheet> {
  bool _allocating = false;
  final _notesController = TextEditingController();
  final _allocationEnergyController = TextEditingController();
  final _allocationRemarksController = TextEditingController();
  String _allocationSource = 'Government Reserve';
  bool _updating = false;

  static const _sources = [
    'Government Reserve', 'Partner Producer', 'Community Storage',
    'Battery Backup', 'Emergency Grid',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _allocationEnergyController.dispose();
    _allocationRemarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                  child: Text('Request Details', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                // Info section
                _InfoRow(label: 'Title', value: req.title),
                _InfoRow(label: 'Consumer', value: req.consumerName),
                _InfoRow(label: 'Category', value: req.category),
                _InfoRow(label: 'Priority', value: req.priority),
                _InfoRow(label: 'Status', value: req.statusDisplay),
                _InfoRow(label: 'Required Energy', value: '${req.requiredEnergyKwh.toStringAsFixed(1)} kWh'),
                _InfoRow(label: 'Allocated Energy', value: '${req.allocatedEnergyKwh.toStringAsFixed(1)} kWh'),
                if (req.address != null) _InfoRow(label: 'Location', value: req.address!),
                if (req.phone != null) _InfoRow(label: 'Phone', value: req.phone!),
                const SizedBox(height: 8),
                Text('Description:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(req.description, style: theme.textTheme.bodyMedium),
                if (req.adminNotes != null) ...[
                  const SizedBox(height: 12),
                  Text('Admin Notes:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.blue)),
                  const SizedBox(height: 4),
                  Text(req.adminNotes!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 20),

                // Status actions
                if (req.isPending || req.isInProgress) ...[
                  Text('Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  // Admin notes
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Notes',
                      border: OutlineInputBorder(),
                      hintText: 'Add notes about this request...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Status buttons
                  if (req.isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _updating ? null : () => _updateStatus('Approved'),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Approve'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _updating ? null : () => _updateStatus('Rejected'),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Reject'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _updating ? null : () => _updateStatus('In Progress'),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Mark In Progress'),
                      ),
                    ),
                  ],
                  if (req.isApproved || req.isInProgress) ...[
                    if (!req.isCompleted) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _updating ? null : () => _updateStatus('Completed'),
                          icon: const Icon(Icons.task_alt, size: 18),
                          label: const Text('Mark Completed'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ],
                  ],
                ],

                // Allocation section
                if (req.isApproved || req.isInProgress) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Allocate Energy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _allocationEnergyController,
                    decoration: const InputDecoration(
                      labelText: 'Energy to Allocate (kWh)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bolt),
                      suffixText: 'kWh',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: _allocationSource,
                    decoration: const InputDecoration(
                      labelText: 'Source',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.source),
                    ),
                    items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _allocationSource = v!),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _allocationRemarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                      hintText: 'Any remarks about this allocation...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _allocating ? null : _allocateEnergy,
                      icon: _allocating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: Text(_allocating ? 'Allocating...' : 'Allocate Energy'),
                    ),
                  ),
                ],
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
      final data = <String, dynamic>{'status': status};
      if (_notesController.text.trim().isNotEmpty) {
        data['admin_notes'] = _notesController.text.trim();
      }
      final result = await ref.read(adminEmergencyProvider.notifier).updateRequest(widget.request.id, data);
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request $status successfully'), behavior: SnackBarBehavior.floating),
          );
          widget.onAction();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update request'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _allocateEnergy() async {
    if (_allocationEnergyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter energy amount'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final energy = double.tryParse(_allocationEnergyController.text.trim());
    if (energy == null || energy <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid energy amount'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _allocating = true);
    try {
      final data = {
        'request_id': widget.request.id,
        'source': _allocationSource,
        'allocated_energy': energy,
        'remarks': _allocationRemarksController.text.trim().isEmpty
            ? null
            : _allocationRemarksController.text.trim(),
      };

      final allocation = await ref.read(adminEmergencyProvider.notifier).createAllocation(data);

      // Also update the allocated energy on the request
      final totalAllocated = widget.request.allocatedEnergyKwh + energy;
      await ref.read(adminEmergencyProvider.notifier).updateRequest(
        widget.request.id,
        {'allocated_energy_kwh': totalAllocated, 'status': 'Approved'},
      );

      if (mounted) {
        if (allocation != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$energy kWh allocated successfully'), behavior: SnackBarBehavior.floating),
          );
          widget.onAction();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to allocate energy'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _allocating = false);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            )),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
