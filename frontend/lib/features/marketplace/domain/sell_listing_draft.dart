import 'marketplace_filter.dart';

class SellListingDraft {
  const SellListingDraft({
    required this.availableEnergyKwh,
    required this.pricePerKwh,
    required this.batteryReservePercentage,
    required this.availabilityStart,
    required this.availabilityEnd,
    required this.energySource,
    this.notes = '',
  });

  final double availableEnergyKwh;
  final double pricePerKwh;
  final int batteryReservePercentage;
  final DateTime availabilityStart;
  final DateTime availabilityEnd;
  final EnergySource energySource;
  final String notes;
}
