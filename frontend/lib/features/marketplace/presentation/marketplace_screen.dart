import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../data/marketplace_mock_repository.dart';
import '../domain/energy_listing.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/marketplace_widgets.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../realtime/providers/realtime_provider.dart';

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(marketplaceListingsProvider);
    final query = ref.watch(marketplaceQueryProvider);
    ref.watch(webSocketProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(marketplaceListingsProvider),
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              AppPageHeader(
                title: 'Marketplace',
                showBackButton: false,
                actions: [
                  const NotificationBell(),
                  IconButton(
                    tooltip: 'Create listing',
                    onPressed: () => context.push(AppRoutes.createListing),
                    icon: const Icon(Icons.add_circle_outline),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'My listings',
                    onPressed: () => context.push(AppRoutes.myListings),
                    icon: const Icon(Icons.list_alt_outlined),
                  ),
                  // Grid/List toggle icon - kept for future implementation
                ],
              ),

              const SizedBox(height: 16),

              // --- Search ---
              MarketplaceSearchBar(
                value: query.search,
                onChanged: (value) {
                  ref.read(marketplaceQueryProvider.notifier).state =
                      query.copyWith(search: value);
                },
              ),

              const SizedBox(height: 16),

              // --- Filters ---
              MarketplaceFilterChips(
                selected: query.filters,
                onToggle: (filter) {
                  final next = {...query.filters};
                  next.contains(filter)
                      ? next.remove(filter)
                      : next.add(filter);
                  ref.read(marketplaceQueryProvider.notifier).state =
                      query.copyWith(filters: next);
                },
                onClear: () {
                  ref.read(marketplaceQueryProvider.notifier).state =
                      const MarketplaceQuery();
                },
              ),

              const SizedBox(height: 24),

              // --- Sort + Results count ---
              Row(
                children: [
                  Expanded(
                    child: listings.whenOrNull(
                      data: (items) => Text(
                        '${items.length} listing${items.length == 1 ? '' : 's'} found',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ) ?? const SizedBox.shrink(),
                  ),
                  MarketplaceSortDropdown(
                    value: query.sort,
                    onChanged: (sort) {
                      if (sort != null) {
                        ref.read(marketplaceQueryProvider.notifier).state =
                            query.copyWith(sort: sort);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // --- Section Title ---
              const SectionHeader(title: 'Nearby & Recommended'),

              const SizedBox(height: 24),

              // --- Listings ---
              listings.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Marketplace unavailable',
                  message: 'We could not load energy listings. Please check your connection.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(marketplaceListingsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No listings found',
                      message: query.search.isNotEmpty || query.filters.isNotEmpty
                          ? 'Try clearing filters or changing your search.'
                          : 'No energy listings available at the moment.',
                      actionLabel: query.search.isNotEmpty || query.filters.isNotEmpty
                          ? 'Clear filters'
                          : null,
                      onAction: query.search.isNotEmpty || query.filters.isNotEmpty
                          ? () {
                              ref.read(marketplaceQueryProvider.notifier).state =
                                  const MarketplaceQuery();
                            }
                          : null,
                    );
                  }
                  return _ListingGrid(items: items, onView: (id) {
                    context.push('/marketplace/$id');
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Listing Grid (responsive)
// =========================================================================

class _ListingGrid extends StatelessWidget {
  final List<EnergyListing> items;
  final ValueChanged<String> onView;

  const _ListingGrid({required this.items, required this.onView});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 640;
        if (!wide) {
          return Column(
            children: [
              for (final listing in items) ...[
                SellerListingCard(
                  listing: listing,
                  onView: () => onView(listing.id),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.82,
          children: [
            for (final listing in items)
              SellerListingCard(
                listing: listing,
                onView: () => onView(listing.id),
              ),
          ],
        );
      },
    );
  }
}

// =========================================================================
// Empty State
// =========================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
