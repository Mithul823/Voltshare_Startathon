import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/domain/energy_purchase.dart';
import '../../marketplace/domain/marketplace_filter.dart';
import '../data/sales_provider.dart';
import '../data/sales_repository.dart';

/// Producer Sales screen — replaces the development placeholder.
class ProducerSalesScreen extends ConsumerStatefulWidget {
  const ProducerSalesScreen({super.key});

  @override
  ConsumerState<ProducerSalesScreen> createState() =>
      _ProducerSalesScreenState();
}

class _ProducerSalesScreenState extends ConsumerState<ProducerSalesScreen> {
  String? _statusFilter;
  int _currentPage = 1;

  void _applyFilters({int page = 1}) {
    setState(() => _currentPage = page);
    ref.read(salesProvider.notifier).load(status: _statusFilter, page: page);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesProvider);
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          _buildFilterChips(context),
          const Divider(height: 1),
          Expanded(child: _buildSalesContent(context, state)),
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
            Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Sales',
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

  Widget _buildFilterChips(BuildContext context) {
    final statuses = [
      ('All', null),
      ('Completed', 'completed'),
      ('Pending', 'pending'),
      ('Confirmed', 'confirmed'),
      ('Cancelled', 'cancelled'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: statuses.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(
                item.$1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _statusFilter == item.$2
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              selected: _statusFilter == item.$2,
              onSelected: (_) {
                setState(() => _statusFilter = item.$2);
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

  Widget _buildSalesContent(BuildContext context, SalesState state) {
    return switch (state) {
      SalesLoading() => const Center(child: CircularProgressIndicator()),
      SalesError(:final message) => _buildError(context, message),
      SalesSuccess(:final data) => _buildSalesData(context, data),
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
              onPressed: () => ref.read(salesProvider.notifier).retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesData(BuildContext context, ProducerSalesPage page) {
    return RefreshIndicator(
      onRefresh: () async => _applyFilters(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards
          _buildSummaryRow(context, page.summary),
          const SizedBox(height: 16),
          // Sales list
          if (page.isEmpty)
            _buildEmpty(context)
          else
            ..._buildSaleItems(context, page),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, ProducerSaleSummary summary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SummaryCard(
            label: 'Net Earnings',
            value: summary.netRevenueInr,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Energy Sold',
            value: '${summary.energySoldKwh.toStringAsFixed(1)} kWh',
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Completed',
            value: '${summary.completedSales}',
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Pending',
            value: '${summary.pendingSales}',
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Pending Sett.',
            value: summary.pendingSettlementInr,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No sales yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed purchases from your energy listings will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSaleItems(BuildContext context, ProducerSalesPage page) {
    final items = <Widget>[];
    for (int i = 0; i < page.items.length; i++) {
      items.add(
        _SaleCard(
          sale: page.items[i],
          onTap: () => _showSaleDetail(context, page.items[i]),
        ),
      );
      if (i < page.items.length - 1) {
        items.add(const SizedBox(height: 8));
      }
    }
    if (page.hasMore) {
      items.add(const SizedBox(height: 12));
      items.add(
        Center(
          child: OutlinedButton(
            onPressed: () => _applyFilters(page: _currentPage + 1),
            child: const Text('Load More'),
          ),
        ),
      );
    }
    return items;
  }

  void _showSaleDetail(BuildContext context, EnergyPurchase sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SaleDetailSheet(sale: sale),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.onTap});

  final EnergyPurchase sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(sale.status);
    final statusLabel = _statusLabel(sale.status);

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
                  Expanded(
                    child: Text(
                      sale.displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${sale.quantityKwh.toStringAsFixed(1)} kWh \u00d7 \u20b9${sale.unitPrice.toStringAsFixed(2)}/kWh',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Gross \u20b9${sale.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Net \u20b9${(sale.totalAmount - sale.platformFee).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(sale.purchasedAt),
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

  Color _statusColor(PurchaseStatus status) {
    return switch (status) {
      PurchaseStatus.completed => Colors.green,
      PurchaseStatus.confirmed => Colors.blue,
      PurchaseStatus.pending => Colors.orange,
      PurchaseStatus.cancelled => Colors.red,
      PurchaseStatus.refunded => Colors.purple,
      PurchaseStatus.failed => Colors.red.shade700,
    };
  }

  String _statusLabel(PurchaseStatus status) {
    return switch (status) {
      PurchaseStatus.completed => 'Completed',
      PurchaseStatus.confirmed => 'Confirmed',
      PurchaseStatus.pending => 'Pending',
      PurchaseStatus.cancelled => 'Cancelled',
      PurchaseStatus.refunded => 'Refunded',
      PurchaseStatus.failed => 'Failed',
    };
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SaleDetailSheet extends StatelessWidget {
  const _SaleDetailSheet({required this.sale});

  final EnergyPurchase sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(sale.status);
    final statusLabel = _statusLabel(sale.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.8,
      minChildSize: 0.35,
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
              'Sale Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Reference', value: sale.id, context: context),
            _DetailRow(
              label: 'Listing',
              value: sale.listingTitle ?? 'Unknown',
              context: context,
            ),
            _DetailRow(label: 'Buyer', value: sale.buyerId, context: context),
            const Divider(height: 20),
            _DetailRow(
              label: 'Quantity',
              value: '${sale.quantityKwh.toStringAsFixed(1)} kWh',
              context: context,
            ),
            _DetailRow(
              label: 'Unit Price',
              value: '\u20b9${sale.unitPrice.toStringAsFixed(2)}/kWh',
              context: context,
            ),
            _DetailRow(
              label: 'Gross Amount',
              value: '\u20b9${sale.totalAmount.toStringAsFixed(2)}',
              context: context,
            ),
            _DetailRow(
              label: 'Platform Fee',
              value: '\u20b9${sale.platformFee.toStringAsFixed(2)}',
              context: context,
            ),
            _DetailRow(
              label: 'Net Amount',
              value:
                  '\u20b9${(sale.totalAmount - sale.platformFee).toStringAsFixed(2)}',
              context: context,
            ),
            const Divider(height: 20),
            _DetailRow(
              label: 'Status',
              value: statusLabel,
              valueColor: statusColor,
              context: context,
            ),
            _DetailRow(
              label: 'Date',
              value: _formatDetailDate(sale.purchasedAt),
              context: context,
            ),
            if (sale.co2ImpactKg > 0)
              _DetailRow(
                label: 'CO\u2082 Avoided',
                value: '${sale.co2ImpactKg.toStringAsFixed(1)} kg',
                context: context,
              ),
            const SizedBox(height: 16),
            // Timeline
            Text(
              'Timeline',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _TimelineStep(
              title: 'Order placed',
              active: true,
              timestamp: sale.purchasedAt,
            ),
            _TimelineStep(
              title: 'Payment confirmed',
              active: sale.status.index >= PurchaseStatus.confirmed.index,
              timestamp: sale.purchasedAt,
            ),
            _TimelineStep(
              title: 'Escrow funded',
              active:
                  sale.status == PurchaseStatus.completed ||
                  sale.status == PurchaseStatus.confirmed,
              timestamp: sale.purchasedAt,
            ),
            _TimelineStep(
              title: 'Energy delivered',
              active: sale.status == PurchaseStatus.completed,
              timestamp: sale.status == PurchaseStatus.completed
                  ? sale.purchasedAt
                  : null,
            ),
            _TimelineStep(
              title: 'Settlement completed',
              active: sale.status == PurchaseStatus.completed,
              timestamp: sale.status == PurchaseStatus.completed
                  ? sale.purchasedAt
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PurchaseStatus status) => switch (status) {
    PurchaseStatus.completed => Colors.green,
    PurchaseStatus.confirmed => Colors.blue,
    PurchaseStatus.pending => Colors.orange,
    PurchaseStatus.cancelled => Colors.red,
    PurchaseStatus.refunded => Colors.purple,
    PurchaseStatus.failed => Colors.red.shade700,
  };

  String _statusLabel(PurchaseStatus status) => switch (status) {
    PurchaseStatus.completed => 'Completed',
    PurchaseStatus.confirmed => 'Confirmed',
    PurchaseStatus.pending => 'Pending',
    PurchaseStatus.cancelled => 'Cancelled',
    PurchaseStatus.refunded => 'Refunded',
    PurchaseStatus.failed => 'Failed',
  };

  String _formatDetailDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.context,
    this.valueColor,
  });

  final String label;
  final String value;
  final BuildContext context;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.active,
    this.timestamp,
  });

  final String title;
  final bool active;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.grey.shade300;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: active ? Colors.green : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: active
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: active ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
          if (timestamp != null)
            Text(
              '${timestamp!.day}/${timestamp!.month}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
