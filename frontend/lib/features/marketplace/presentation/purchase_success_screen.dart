import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../providers/marketplace_provider.dart';

class PurchaseSuccessScreen extends ConsumerWidget {
  const PurchaseSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(latestPurchaseProvider);
    final meterResult = ref.watch(latestSmartMeterResultProvider);
    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const AppPageHeader(
              title: 'Simulated purchase complete',
              fallbackRoute: AppRoutes.marketplace,
            ),
            const SizedBox(height: 12),
            if (purchase == null)
              const Text('No recent purchase found.')
            else ...[
              Text(
                '${purchase.quantityKwh.toStringAsFixed(1)} kWh purchased successfully.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (meterResult != null && !meterResult.isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9100).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF9100).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFF9100),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Purchase recorded, but smart-meter synchronization could not be confirmed.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text('Reference: ${purchase.id}'),
              Text('Energy: ${purchase.quantityKwh.toStringAsFixed(1)} kWh'),
              Text('Total: Rs ${purchase.totalAmount.toStringAsFixed(2)}'),
              const Text(
                'Funds are reserved in simulated escrow until delivery is verified.',
              ),
              Text(
                'Savings: Rs ${purchase.estimatedSavings.toStringAsFixed(2)}',
              ),
              Text(
                'CO2 benefit: ${purchase.co2ImpactKg.toStringAsFixed(1)} kg',
              ),
            ],
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: 'Return to marketplace',
              icon: Icons.storefront,
              onPressed: () => context.go(AppRoutes.marketplace),
            ),
            const SizedBox(height: 10),
            SecondaryActionButton(
              label: 'Go to wallet',
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () => context.go(AppRoutes.wallet),
            ),
            const SizedBox(height: 10),
            SecondaryActionButton(
              label: 'View transaction',
              icon: Icons.receipt_long_outlined,
              onPressed: () => context.go(AppRoutes.wallet),
            ),
          ],
        ),
      ),
    );
  }
}
