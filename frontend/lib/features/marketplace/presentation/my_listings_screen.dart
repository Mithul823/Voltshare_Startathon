import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../domain/marketplace_filter.dart';
import '../providers/marketplace_provider.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    final repository = ref.watch(marketplaceRepositoryProvider);
    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'My listings',
              fallbackRoute: AppRoutes.marketplace,
              actions: [
                IconButton(
                  tooltip: 'Create listing',
                  onPressed: () => context.push(AppRoutes.createListing),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            listings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Could not load your listings.'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                    'No session listings yet. Publish one from Sell Energy.',
                  );
                }
                return Column(
                  children: [
                    for (final item in items) ...[
                      Card(
                        child: ListTile(
                          title: Text(
                            '${item.availableEnergyKwh.toStringAsFixed(1)} kWh • Rs ${item.pricePerKwh.toStringAsFixed(2)}/kWh',
                          ),
                          subtitle: Text(
                            '${item.energySource.label} • ${item.listingStatus.name} • created ${TimeOfDay.fromDateTime(item.createdAt).format(context)}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Cancel listing',
                                onPressed:
                                    item.listingStatus == ListingStatus.active
                                    ? () async {
                                        await repository.cancelListing(item.id);
                                        ref.invalidate(myListingsProvider);
                                        ref.invalidate(
                                          marketplaceListingsProvider,
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.cancel_outlined),
                              ),
                              IconButton(
                                tooltip: 'Duplicate listing',
                                onPressed: () async {
                                  await repository.duplicateListing(item.id);
                                  ref.invalidate(myListingsProvider);
                                  ref.invalidate(marketplaceListingsProvider);
                                },
                                icon: const Icon(Icons.copy_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
