import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/voltshare_ui.dart';
import '../domain/marketplace_filter.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/marketplace_widgets.dart';

class ListingDetailsScreen extends ConsumerStatefulWidget {
  const ListingDetailsScreen({required this.listingId, super.key});
  final String listingId;

  @override
  ConsumerState<ListingDetailsScreen> createState() =>
      _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends ConsumerState<ListingDetailsScreen> {
  double _quantity = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listingValue = ref.watch(
      marketplaceListingProvider(widget.listingId),
    );
    return Scaffold(
      body: ResponsivePage(
        child: listingValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Listing unavailable')),
          data: (listing) {
            _quantity = _quantity.clamp(0.5, listing.availableEnergyKwh);
            final quote = ref
                .read(marketplaceRepositoryProvider)
                .quote(listing, _quantity);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: listing.sellerName,
                  fallbackRoute: '/marketplace',
                ),

                const SizedBox(height: 16),

                // Seller summary card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            listing.sellerInitials,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${listing.sellerRating}',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    ' (${listing.reviewCount} reviews)',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.outline),
                                  const SizedBox(width: 4),
                                  Text(
                                    listing.location,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

                const SizedBox(height: 16),

                // Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ListingBadge(
                      label: listing.energySource.label,
                      icon: Icons.eco_outlined,
                    ),
                    if (listing.renewableVerified)
                      const ListingBadge(
                        label: 'Renewable verified',
                        icon: Icons.verified_outlined,
                        color: Color(0xFF4CAF50),
                      ),
                    if (listing.batteryBacked)
                      const ListingBadge(
                        label: 'Battery-backed',
                        icon: Icons.battery_charging_full,
                        color: Color(0xFF2196F3),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Price & availability
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs ${listing.pricePerKwh.toStringAsFixed(2)}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4, left: 4),
                                child: Text(
                                  '/kWh',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 20, color: Colors.amber.shade700),
                              const SizedBox(width: 4),
                              Text(
                                '${listing.availableEnergyKwh.toStringAsFixed(1)} kWh',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Availability time
                Card(
                  elevation: 0,
                  color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.tertiaryContainer),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 6),
                        Text(
                          'Available ${TimeOfDay.fromDateTime(listing.availabilityStart).format(context)} - ${TimeOfDay.fromDateTime(listing.availabilityEnd).format(context)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quantity selector
                Text('Select Quantity', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 8),
                QuantitySelector(
                  quantity: _quantity,
                  max: listing.availableEnergyKwh,
                  onChanged: (value) => setState(() => _quantity = value),
                ),

                const SizedBox(height: 16),

                // Price breakdown
                PriceBreakdownCard(quote: quote),

                const SizedBox(height: 16),

                // Environmental impact
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.eco_rounded, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Compared with grid (Rs 10.25/kWh), this saves ~Rs ${quote.estimatedSavings.toStringAsFixed(2)} and avoids ${quote.co2ImpactKg.toStringAsFixed(1)} kg CO₂.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                      '/marketplace/${listing.id}/confirm?qty=${_quantity.toStringAsFixed(1)}',
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    label: const Text('Continue to Purchase', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
