import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/network/api_exception.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../marketplace/domain/marketplace_filter.dart';
import '../data/purchases_repository.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(purchasesListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: purchasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(context, ref, error),
        data: (purchases) {
          if (purchases.isEmpty) {
            return _buildEmpty(context, ref);
          }
          return _buildList(context, ref, purchases);
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    String message;
    if (error is ApiException) {
      message = switch (error.code) {
        'AUTH_REQUIRED' || 'AUTH_INVALID_TOKEN' =>
          'Your session expired. Please sign in again.',
        'ACCESS_DENIED' => 'You do not have permission to view purchases.',
        'NETWORK_ERROR' => 'No internet connection.',
        'TIMEOUT' => 'Purchase history is temporarily unavailable.',
        'HTTP_500' || 'HTTP_502' || 'HTTP_503' =>
          'Purchase history is temporarily unavailable.',
        _ => error.message,
      };
    } else {
      message = 'Could not load purchase history.';
    }

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ref.invalidate(purchasesListProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No purchases yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Energy purchases you make will appear here.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.marketplace),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Open Marketplace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<EnergyPurchase> purchases,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(purchasesListProvider);
        await ref.read(purchasesListProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: purchases.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final purchase = purchases[index];
          return _PurchaseCard(purchase: purchase);
        },
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.purchase});

  final EnergyPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (purchase.status) {
      PurchaseStatus.completed => Colors.green,
      PurchaseStatus.confirmed => Colors.blue,
      PurchaseStatus.pending => Colors.orange,
      PurchaseStatus.cancelled => Colors.red,
      PurchaseStatus.refunded => Colors.purple,
      PurchaseStatus.failed => Colors.red.shade700,
    };
    final statusLabel = switch (purchase.status) {
      PurchaseStatus.completed => 'Completed',
      PurchaseStatus.confirmed => 'Confirmed',
      PurchaseStatus.pending => 'Pending',
      PurchaseStatus.cancelled => 'Cancelled',
      PurchaseStatus.refunded => 'Refunded',
      PurchaseStatus.failed => 'Failed',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Listing title
            Text(
              purchase.displayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Seller name
            Text(
              purchase.displaySeller,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${purchase.quantityKwh.toStringAsFixed(1)} kWh',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('Reference', purchase.id),
            _infoRow('Total', 'Rs ${purchase.totalAmount.toStringAsFixed(2)}'),
            _infoRow('Unit price', 'Rs ${purchase.unitPrice.toStringAsFixed(2)}/kWh'),
            _infoRow('Date', _formatDate(purchase.purchasedAt)),
            if (purchase.estimatedSavings > 0)
              _infoRow(
                'Estimated savings',
                'Rs ${purchase.estimatedSavings.toStringAsFixed(2)}',
              ),
            if (purchase.co2ImpactKg > 0)
              _infoRow(
                'CO₂ avoided',
                '${purchase.co2ImpactKg.toStringAsFixed(1)} kg',
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
