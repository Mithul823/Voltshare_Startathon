import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../domain/marketplace_filter.dart';
import '../domain/sell_listing_draft.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/marketplace_widgets.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '2.0');
  final _price = TextEditingController(text: '8.20');
  final _reserve = TextEditingController(text: '30');
  final _notes = TextEditingController();
  EnergySource _source = EnergySource.solar;
  late final DateTime _start = DateTime.now();
  late final DateTime _end = DateTime.now().add(const Duration(hours: 4));

  @override
  void dispose() {
    _amount.dispose();
    _price.dispose();
    _reserve.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxEnergy =
        ref.watch(dashboardProvider).valueOrNull?.availableToSellKwh ?? 8.5;
    final state = ref.watch(sellListingControllerProvider);
    return Scaffold(
      body: ResponsivePage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Create sell listing',
                fallbackRoute: AppRoutes.dashboard,
              ),
              const SizedBox(height: 8),
              Text(
                'Available to sell from dashboard: ${maxEnergy.toStringAsFixed(1)} kWh',
              ),
              const SizedBox(height: 16),
              ListingFormSection(
                title: 'Listing details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _amount,
                      decoration: const InputDecoration(
                        labelText: 'Energy amount (kWh)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _positive,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _price,
                      decoration: const InputDecoration(
                        labelText: 'Price per kWh',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _positive,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<EnergySource>(
                      initialValue: _source,
                      decoration: const InputDecoration(
                        labelText: 'Energy source',
                      ),
                      items: EnergySource.values
                          .map(
                            (source) => DropdownMenuItem(
                              value: source,
                              child: Text(source.label),
                            ),
                          )
                          .toList(),
                      onChanged: (source) =>
                          setState(() => _source = source ?? _source),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListingFormSection(
                title: 'Availability and reserve',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _reserve,
                      decoration: const InputDecoration(
                        labelText: 'Battery reserve %',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _reserveValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Notes optional',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Availability: ${TimeOfDay.fromDateTime(_start).format(context)} - ${TimeOfDay.fromDateTime(_end).format(context)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListingFormSection(
                title: 'Preview',
                child: Text(
                  '${_amount.text} kWh • Rs ${_price.text}/kWh • ${_source.label}',
                ),
              ),
              const SizedBox(height: 12),
              PricingSuggestionCard(
                quantityKwh: double.tryParse(_amount.text) ?? 1,
              ),
              if (state.hasError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error
                              .toString()
                              .replaceAll('Exception: ', '')
                              .replaceAll('MarketplaceException: ', ''),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryActionButton(
                label: state.isLoading ? 'Publishing...' : 'Publish listing',
                icon: Icons.publish_outlined,
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final listing = await ref
                            .read(sellListingControllerProvider.notifier)
                            .publish(
                              maxAvailableKwh: maxEnergy,
                              draft: SellListingDraft(
                                availableEnergyKwh: double.parse(_amount.text),
                                pricePerKwh: double.parse(_price.text),
                                batteryReservePercentage: int.parse(
                                  _reserve.text,
                                ),
                                availabilityStart: _start,
                                availabilityEnd: _end,
                                energySource: _source,
                                notes: _notes.text,
                              ),
                            );
                        if (context.mounted && listing != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Listing published successfully.'),
                            ),
                          );
                          context.go(AppRoutes.myListings);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _positive(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a positive value';
    return null;
  }

  String? _reserveValidator(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 0 || parsed > 100) {
      return 'Reserve must be 0-100';
    }
    return null;
  }
}
