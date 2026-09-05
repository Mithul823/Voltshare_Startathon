import 'package:flutter/material.dart';

import '../domain/energy_listing.dart';
import '../domain/energy_purchase.dart';
import '../domain/marketplace_filter.dart';

// =========================================================================
// Search Bar (Redesigned)
// =========================================================================

class MarketplaceSearchBar extends StatefulWidget {
  const MarketplaceSearchBar({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<MarketplaceSearchBar> createState() => _MarketplaceSearchBarState();
}

class _MarketplaceSearchBarState extends State<MarketplaceSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant MarketplaceSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 52,
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search seller, location, or source...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 15,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Icon(
                Icons.search_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Filter Chips (Redesigned)
// =========================================================================

class MarketplaceFilterChips extends StatelessWidget {
  const MarketplaceFilterChips({
    required this.selected,
    required this.onToggle,
    required this.onClear,
    super.key,
  });

  final Set<MarketplaceFilter> selected;
  final ValueChanged<MarketplaceFilter> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in MarketplaceFilter.values) ...[
            _FilterChipStyled(
              label: filter.label,
              selected: selected.contains(filter),
              onSelected: (_) => onToggle(filter),
            ),
            const SizedBox(width: 8),
          ],
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Clear', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _FilterChipStyled extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChipStyled({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.4)
            : theme.colorScheme.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

// =========================================================================
// Sort Dropdown (Redesigned)
// =========================================================================

class MarketplaceSortDropdown extends StatelessWidget {
  const MarketplaceSortDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final MarketplaceSort value;
  final ValueChanged<MarketplaceSort?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<MarketplaceSort>(
            value: value,
            isDense: true,
            isExpanded: false,
            borderRadius: BorderRadius.circular(12),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: theme.colorScheme.surface,
            icon: Icon(
              Icons.unfold_more_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            hint: const Text('Sort by'),
            items: const [
              DropdownMenuItem(
                value: MarketplaceSort.priceLow,
                child: Text('Price: Low to High'),
              ),
              DropdownMenuItem(
                value: MarketplaceSort.priceHigh,
                child: Text('Price: High to Low'),
              ),
              DropdownMenuItem(
                value: MarketplaceSort.distance,
                child: Text('Nearest'),
              ),
              DropdownMenuItem(
                value: MarketplaceSort.rating,
                child: Text('Highest Rated'),
              ),
              DropdownMenuItem(
                value: MarketplaceSort.energyAvailable,
                child: Text('Most Energy'),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Energy Source Icon Helper
// =========================================================================

IconData _sourceIcon(EnergySource source) {
  return switch (source) {
    EnergySource.solar => Icons.wb_sunny_outlined,
    EnergySource.wind => Icons.air_outlined,
    EnergySource.hybrid => Icons.recycling_outlined,
    EnergySource.communitySolar => Icons.groups_outlined,
  };
}

Color _sourceColor(EnergySource source, ThemeData theme) {
  return switch (source) {
    EnergySource.solar => const Color(0xFFFFB300),
    EnergySource.wind => const Color(0xFF42A5F5),
    EnergySource.hybrid => const Color(0xFF66BB6A),
    EnergySource.communitySolar => const Color(0xFFAB47BC),
  };
}

// =========================================================================
// Listing Badge (Redesigned)
// =========================================================================

class ListingBadge extends StatelessWidget {
  const ListingBadge({
    required this.label,
    required this.icon,
    this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Seller Listing Card (Redesigned)
// =========================================================================

class SellerListingCard extends StatelessWidget {
  const SellerListingCard({
    required this.listing,
    required this.onView,
    super.key,
  });

  final EnergyListing listing;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label:
          '${listing.sellerName}, ${listing.availableEnergyKwh.toStringAsFixed(1)} kWh at Rs ${listing.pricePerKwh.toStringAsFixed(2)} per kWh',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Row 1: Avatar + Seller Info + Price ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _sourceColor(
                        listing.energySource,
                        theme,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        _sourceIcon(listing.energySource),
                        size: 20,
                        color: _sourceColor(listing.energySource, theme),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Seller Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.sellerName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Colors.amber.shade600,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                listing.sellerRating.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                ' (${listing.reviewCount})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.outline,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: scheme.outline,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  listing.location,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.outline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // --- Row 2: Badges ---
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ListingBadge(
                      label: listing.energySource.label,
                      icon: Icons.eco_outlined,
                      color: _sourceColor(listing.energySource, theme),
                    ),
                    if (listing.renewableVerified)
                      const ListingBadge(
                        label: 'Verified',
                        icon: Icons.verified_outlined,
                        color: Color(0xFF4CAF50),
                      ),
                    if (listing.batteryBacked)
                      const ListingBadge(
                        label: 'Battery',
                        icon: Icons.battery_charging_full,
                        color: Color(0xFF2196F3),
                      ),
                    ListingBadge(
                      label: '${listing.distanceKm.toStringAsFixed(1)} km',
                      icon: Icons.near_me_outlined,
                      color: scheme.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // --- Row 3: Energy Available + Price (separated) ---
                Row(
                  children: [
                    // Energy available
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${listing.availableEnergyKwh.toStringAsFixed(1)} kWh',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Price + View button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Price',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs ${listing.pricePerKwh.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 2,
                                left: 2,
                              ),
                              child: Text(
                                '/kWh',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.primary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // --- Row 4: View Button ---
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: onView,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'View Listing',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// Quantity Selector
// =========================================================================

class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    required this.quantity,
    required this.max,
    required this.onChanged,
    super.key,
  });

  final double quantity;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Decrease',
              onPressed: quantity <= 0.5
                  ? null
                  : () => onChanged((quantity - 0.5).clamp(0.5, max)),
              icon: const Icon(Icons.remove_circle_outline_rounded),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.primaryContainer,
                  thumbColor: theme.colorScheme.primary,
                  overlayColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: quantity.clamp(0.5, max),
                  min: 0.5,
                  max: max < 0.5 ? 0.5 : max,
                  divisions: ((max - 0.5) / 0.5).floor().clamp(1, 100),
                  label: '${quantity.toStringAsFixed(1)} kWh',
                  onChanged: onChanged,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Increase',
              onPressed: quantity >= max
                  ? null
                  : () => onChanged((quantity + 0.5).clamp(0.5, max)),
              icon: const Icon(Icons.add_circle_outline_rounded),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                '${quantity.toStringAsFixed(1)} kWh',
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Price Breakdown Card
// =========================================================================

class PriceBreakdownCard extends StatelessWidget {
  const PriceBreakdownCard({required this.quote, super.key});

  final PurchaseQuote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _priceRow(context, 'Subtotal', quote.subtotal, isTotal: false),
            _priceRow(
              context,
              'Platform fee',
              quote.platformFee,
              isTotal: false,
            ),
            Divider(height: 20, color: theme.colorScheme.outlineVariant),
            _priceRow(context, 'Total', quote.totalAmount, isTotal: true),
            const SizedBox(height: 4),
            _priceRow(
              context,
              'Estimated savings',
              quote.estimatedSavings,
              isTotal: false,
              accent: true,
            ),
            _priceRow(
              context,
              'CO2 avoided',
              quote.co2ImpactKg,
              isTotal: false,
              suffix: ' kg',
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(
    BuildContext context,
    String label,
    double value, {
    bool isTotal = false,
    bool accent = false,
    String suffix = '',
  }) {
    final theme = Theme.of(context);
    final text = suffix.isEmpty
        ? 'Rs ${value.toStringAsFixed(2)}'
        : '${value.toStringAsFixed(1)}$suffix';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 15 : 13,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
                color: accent
                    ? Colors.green.shade700
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: accent
                  ? Colors.green.shade700
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Listing Form Section
// =========================================================================

class ListingFormSection extends StatelessWidget {
  const ListingFormSection({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
