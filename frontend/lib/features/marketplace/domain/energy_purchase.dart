import 'marketplace_filter.dart';

class EnergyPurchase {
  const EnergyPurchase({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.sellerName,
    this.listingTitle,
    required this.quantityKwh,
    required this.unitPrice,
    required this.platformFee,
    required this.totalAmount,
    required this.estimatedSavings,
    required this.co2ImpactKg,
    required this.purchasedAt,
    required this.status,
    this.buyerName,
    this.listingStatus,
    this.producerInitials,
  });

  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final String? sellerName;
  final String? listingTitle;
  final double quantityKwh;
  final double unitPrice;
  final double platformFee;
  final double totalAmount;
  final double estimatedSavings;
  final double co2ImpactKg;
  final DateTime purchasedAt;
  final PurchaseStatus status;
  final String? buyerName;
  final String? listingStatus;
  final String? producerInitials;

  String get displayTitle =>
      listingTitle ?? sellerName ?? 'Purchase ${id.substring(0, id.length > 8 ? 8 : id.length)}';

  String get displaySeller =>
      sellerName ?? 'Producer $sellerId';

  String get displayBuyer =>
      buyerName ?? 'Consumer $buyerId';
}

class PurchaseQuote {
  const PurchaseQuote({
    required this.quantityKwh,
    required this.unitPrice,
    required this.subtotal,
    required this.platformFee,
    required this.totalAmount,
    required this.estimatedSavings,
    required this.co2ImpactKg,
  });

  final double quantityKwh;
  final double unitPrice;
  final double subtotal;
  final double platformFee;
  final double totalAmount;
  final double estimatedSavings;
  final double co2ImpactKg;
}
