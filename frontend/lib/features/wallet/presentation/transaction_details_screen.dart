import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../domain/wallet.dart';
import '../providers/transaction_history_provider.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionValue = ref.watch(
      walletTransactionProvider(transactionId),
    );
    return Scaffold(
      body: ResponsivePage(
        child: transactionValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorMessage(message: error.toString()),
          data: (transaction) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: transaction.type.label,
                  subtitle: transaction.reference,
                  fallbackRoute: AppRoutes.walletActivity,
                ),
                const SizedBox(height: 16),
                _DetailCard(
                  rows: [
                    ('Status', transaction.status.label),
                    ('Amount', formatPaise(transaction.amountPaise)),
                    ('Created', '${transaction.createdAt}'),
                    if (transaction.completedAt != null)
                      ('Completed', '${transaction.completedAt}'),
                    ('Description', transaction.description),
                    if (transaction.counterpartyName != null)
                      ('Counterparty', transaction.counterpartyName!),
                    if (transaction.energyQuantityKwh != null)
                      (
                        'Energy quantity',
                        '${transaction.energyQuantityKwh!.toStringAsFixed(1)} kWh',
                      ),
                    if (transaction.unitPricePaise != null)
                      (
                        'Price per kWh',
                        formatPaise(transaction.unitPricePaise!),
                      ),
                    ('Subtotal', formatPaise(transaction.subtotalPaise)),
                    ('Platform fee', formatPaise(transaction.platformFeePaise)),
                    if (transaction.marketplaceListingId != null)
                      ('Listing', transaction.marketplaceListingId!),
                    if (transaction.energyPurchaseId != null)
                      ('Purchase', transaction.energyPurchaseId!),
                    if (transaction.escrowId != null)
                      ('Simulated escrow', transaction.escrowId!),
                    if (transaction.escrowStatusLabel != null)
                      ('Escrow status', transaction.escrowStatusLabel!),
                    if (transaction.escrowId != null)
                      ('Seller release', 'Pending delivery verification'),
                    if (transaction.escrowId != null)
                      ('Buyer refund', 'Pending delivery verification'),
                    if (transaction.escrowId != null)
                      ('Frozen amount', 'Rs 0.00 unless review is triggered'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'This transaction belongs to the simulated VoltShare wallet. It does not represent real money movement.',
                ),
                if (transaction.escrowId != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Simulated escrow disclaimer: reserved funds are settled only by mock delivery verification in this demo.',
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryActionButton(
                  label: 'View receipt',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () =>
                      context.push(AppRoutes.receipt(transaction.id)),
                ),
                if (transaction.escrowId != null) ...[
                  const SizedBox(height: 10),
                  SecondaryActionButton(
                    label: 'View escrow activity',
                    icon: Icons.verified_user_outlined,
                    onPressed: () => context.push(
                      AppRoutes.escrowDetails(transaction.escrowId!),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SecondaryActionButton(
                  label: 'Report issue',
                  icon: Icons.flag_outlined,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Issue reporting is a placeholder in this phase.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SecondaryActionButton(
                  label: 'Return to wallet',
                  icon: Icons.account_balance_wallet_outlined,
                  onPressed: () => context.go(AppRoutes.wallet),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(row.$1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
