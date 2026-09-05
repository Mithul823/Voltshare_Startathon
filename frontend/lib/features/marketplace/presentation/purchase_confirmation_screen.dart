import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/voltshare_ui.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/marketplace_widgets.dart';

class PurchaseConfirmationScreen extends ConsumerWidget {
  const PurchaseConfirmationScreen({
    required this.listingId,
    required this.quantityKwh,
    super.key,
  });

  final String listingId;
  final double quantityKwh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingValue = ref.watch(marketplaceListingProvider(listingId));
    final purchaseState = ref.watch(purchaseControllerProvider);
    return Scaffold(
      body: ResponsivePage(
        child: listingValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Listing unavailable'),
          data: (listing) {
            final quote = ref
                .read(marketplaceRepositoryProvider)
                .quote(listing, quantityKwh);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPageHeader(
                  title: 'Confirm simulated purchase',
                  fallbackRoute: '/marketplace',
                ),
                const SizedBox(height: 12),
                Text(
                  '${listing.sellerName} • ${quantityKwh.toStringAsFixed(1)} kWh at Rs ${listing.pricePerKwh.toStringAsFixed(2)}/kWh',
                ),
                const SizedBox(height: 12),
                PriceBreakdownCard(quote: quote),
                const SizedBox(height: 12),
                const Text(
                  'Payment method: VoltShare demo wallet. No real money will be transferred.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your simulated funds will be reserved and released to the seller only after energy delivery is verified.',
                ),
                if (purchaseState.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Purchase failed. Check quantity and permissions.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryActionButton(
                  label: purchaseState.isLoading
                      ? 'Confirming...'
                      : 'Confirm simulated purchase',
                  icon: Icons.check_circle_outline,
                  onPressed: purchaseState.isLoading
                      ? null
                      : () async {
                          final purchase = await ref
                              .read(purchaseControllerProvider.notifier)
                              .purchase(
                                listingId: listing.id,
                                quantityKwh: quantityKwh,
                              );
                          if (context.mounted && purchase != null) {
                            context.go(
                              '/marketplace/purchase-success/${purchase.id}',
                            );
                          }
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
