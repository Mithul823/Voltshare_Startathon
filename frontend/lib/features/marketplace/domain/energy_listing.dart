import 'marketplace_filter.dart';

class EnergyListing {
  const EnergyListing({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerRole,
    required this.sellerInitials,
    required this.sellerRating,
    required this.reviewCount,
    required this.energySource,
    required this.availableEnergyKwh,
    this.quantityTotalKwh,
    this.quantitySoldKwh,
    this.totalRevenue,
    required this.pricePerKwh,
    required this.distanceKm,
    required this.location,
    required this.batteryBacked,
    required this.renewableVerified,
    required this.availabilityStart,
    required this.availabilityEnd,
    required this.createdAt,
    required this.listingStatus,
    this.notes,
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerRole;
  final String sellerInitials;
  final double sellerRating;
  final int reviewCount;
  final EnergySource energySource;
  final double availableEnergyKwh;
  final double? quantityTotalKwh;
  final double? quantitySoldKwh;
  final double? totalRevenue;
  final double pricePerKwh;
  final double distanceKm;
  final String location;
  final bool batteryBacked;
  final bool renewableVerified;
  final DateTime availabilityStart;
  final DateTime availabilityEnd;
  final DateTime createdAt;
  final ListingStatus listingStatus;
  final String? notes;

  bool get isSoldOut => availableEnergyKwh <= 0 || listingStatus == ListingStatus.sold;
  bool get isActive => listingStatus == ListingStatus.active && availableEnergyKwh > 0;
  double get soldKwh => quantitySoldKwh ?? (quantityTotalKwh ?? availableEnergyKwh) - availableEnergyKwh;
  double get revenue => totalRevenue ?? (soldKwh * pricePerKwh);

  EnergyListing copyWith({
    double? availableEnergyKwh,
    ListingStatus? listingStatus,
    String? id,
    DateTime? createdAt,
    double? quantityTotalKwh,
    double? quantitySoldKwh,
    double? totalRevenue,
  }) {
    return EnergyListing(
      id: id ?? this.id,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerRole: sellerRole,
      sellerInitials: sellerInitials,
      sellerRating: sellerRating,
      reviewCount: reviewCount,
      energySource: energySource,
      availableEnergyKwh: availableEnergyKwh ?? this.availableEnergyKwh,
      quantityTotalKwh: quantityTotalKwh ?? this.quantityTotalKwh,
      quantitySoldKwh: quantitySoldKwh ?? this.quantitySoldKwh,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      pricePerKwh: pricePerKwh,
      distanceKm: distanceKm,
      location: location,
      batteryBacked: batteryBacked,
      renewableVerified: renewableVerified,
      availabilityStart: availabilityStart,
      availabilityEnd: availabilityEnd,
      createdAt: createdAt ?? this.createdAt,
      listingStatus: listingStatus ?? this.listingStatus,
      notes: notes,
    );
  }
}
