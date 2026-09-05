// ignore_for_file: annotate_overrides

import '../domain/energy_listing.dart';
import '../domain/energy_purchase.dart';
import '../domain/marketplace_filter.dart';
import '../domain/sell_listing_draft.dart';
import 'mock_backend_store.dart';

class MarketplaceQuery {
  const MarketplaceQuery({
    this.search = '',
    this.filters = const {},
    this.sort = MarketplaceSort.priceLow,
  });

  final String search;
  final Set<MarketplaceFilter> filters;
  final MarketplaceSort sort;

  MarketplaceQuery copyWith({
    String? search,
    Set<MarketplaceFilter>? filters,
    MarketplaceSort? sort,
  }) {
    return MarketplaceQuery(
      search: search ?? this.search,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
    );
  }
}

abstract class MarketplaceRepository {
  Future<List<EnergyListing>> loadListings(MarketplaceQuery query);
  Future<EnergyListing> listingById(String id);
  PurchaseQuote quote(EnergyListing listing, double quantityKwh);
  Future<EnergyPurchase> purchase({
    required String listingId,
    required String buyerId,
    required double quantityKwh,
    required bool canBuy,
  });
  Future<EnergyListing> createListing({
    required SellListingDraft draft,
    required bool canSell,
    required double maxAvailableKwh,
  });
  Future<List<EnergyListing>> myListings();
  Future<void> cancelListing(String id);
  Future<EnergyListing> duplicateListing(String id);
  Future<void> pauseListing(String id);
  Future<void> deleteListing(String id);
  Future<EnergyListing> updateListingQuantity(String id, double newQuantity);
  EnergyPurchase? get latestPurchase;
}

class MarketplaceMockRepository implements MarketplaceRepository {
  MarketplaceMockRepository({
    required this.currentUserId,
    required this.currentUserRole,
    this.currentUserName = 'Energy Seller',
    DateTime? now,
    MockBackendStore? store,
  }) : _now = now ?? DateTime.now(),
       _store = store ?? MockBackendStore() {
    _store.seed();
  }

  final String currentUserId;
  final String currentUserRole;
  final String currentUserName;
  final DateTime _now;
  final MockBackendStore _store;

  static const platformFeeRate = 0.03;
  static const gridPricePerKwh = 10.25;
  static const co2KgPerKwh = 0.7;

  bool get _isProducerOrProsumer =>
      currentUserRole == 'producer' || currentUserRole == 'prosumer';
  bool get _isConsumerOrProsumer =>
      currentUserRole == 'consumer' || currentUserRole == 'prosumer';

  @override
  Future<List<EnergyListing>> loadListings(MarketplaceQuery query) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final allListings = _store.getActiveListings(excludeSellerId: null);
    final parsed = allListings.map(_listingFromStore).toList();
    return _applyQuery(parsed, query);
  }

  @override
  Future<EnergyListing> listingById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final entry = _store.getListing(id);
    if (entry == null) throw const MarketplaceException('Listing unavailable.');
    return _listingFromStore(entry);
  }

  @override
  PurchaseQuote quote(EnergyListing listing, double quantityKwh) {
    if (quantityKwh < 0.5)
      throw const MarketplaceException('Select at least 0.5 kWh.');
    if (listing.isSoldOut)
      throw const MarketplaceException('This listing is sold out.');
    if (quantityKwh > listing.availableEnergyKwh) {
      throw MarketplaceException(
        'Only ${listing.availableEnergyKwh.toStringAsFixed(1)} kWh available.',
      );
    }
    final subtotal = quantityKwh * listing.pricePerKwh;
    final fee = subtotal * platformFeeRate;
    final gridCost = quantityKwh * gridPricePerKwh;
    return PurchaseQuote(
      quantityKwh: quantityKwh,
      unitPrice: listing.pricePerKwh,
      subtotal: subtotal,
      platformFee: fee,
      totalAmount: subtotal + fee,
      estimatedSavings: (gridCost - subtotal).clamp(0, double.infinity),
      co2ImpactKg: quantityKwh * co2KgPerKwh,
    );
  }

  @override
  Future<EnergyPurchase> purchase({
    required String listingId,
    required String buyerId,
    required double quantityKwh,
    required bool canBuy,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!_isConsumerOrProsumer)
      throw const MarketplaceException('This role cannot buy energy.');
    if (!canBuy)
      throw const MarketplaceException('This role cannot buy energy.');
    if (buyerId.isEmpty)
      throw const MarketplaceException('You must be logged in to purchase.');

    final listing = _store.getListing(listingId);
    if (listing == null)
      throw const MarketplaceException('Listing unavailable.');
    if (listing['sellerId'] == buyerId)
      throw const MarketplaceException('You cannot purchase your own listing.');

    final listingTitle = listing['title']?.toString() ?? 'Energy Listing';
    final sellerName = listing['sellerName']?.toString() ?? 'Seller';
    final sellerId = listing['sellerId'].toString();
    final availableKwh =
        (listing['availableEnergyKwh'] as num?)?.toDouble() ?? 0;
    final pricePerKwh = (listing['pricePerKwh'] as num?)?.toDouble() ?? 0;

    if (quantityKwh > availableKwh)
      throw MarketplaceException(
        'Only ${availableKwh.toStringAsFixed(1)} kWh available.',
      );
    if (availableKwh <= 0)
      throw const MarketplaceException('This listing is sold out.');

    final subtotal = quantityKwh * pricePerKwh;
    final fee = subtotal * platformFeeRate;
    final totalAmount = subtotal + fee;
    final remaining = availableKwh - quantityKwh;
    final newStatus = remaining <= 0
        ? ListingStatus.sold.name
        : ListingStatus.active.name;

    // Deduct inventory in store
    _store.updateListing(listingId, {
      'availableEnergyKwh': remaining,
      'listingStatus': newStatus,
    });

    // Create purchase record
    final purchaseData = _store.addPurchase({
      'listingId': listingId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'listingTitle': listingTitle,
      'quantityKwh': quantityKwh,
      'unitPrice': pricePerKwh,
      'platformFee': fee,
      'totalAmount': totalAmount,
      'estimatedSavings': (quantityKwh * gridPricePerKwh - subtotal).clamp(
        0,
        double.infinity,
      ),
      'co2ImpactKg': quantityKwh * co2KgPerKwh,
      'purchasedAt': DateTime.now().toIso8601String(),
      'status': PurchaseStatus.completed.name,
    });

    return _purchaseFromStore(purchaseData);
  }

  @override
  Future<EnergyListing> createListing({
    required SellListingDraft draft,
    required bool canSell,
    required double maxAvailableKwh,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!_isProducerOrProsumer)
      throw const MarketplaceException(
        'This role cannot publish energy listings.',
      );
    if (!canSell)
      throw const MarketplaceException(
        'This role cannot publish energy listings.',
      );
    _validateDraft(draft, maxAvailableKwh);

    final listingData = _store.addListing({
      'sellerId': currentUserId,
      'sellerName': currentUserName,
      'sellerRole': currentUserRole,
      'title': draft.notes.isNotEmpty ? draft.notes : 'Energy Listing',
      'energySource': draft.energySource.name,
      'availableEnergyKwh': draft.availableEnergyKwh,
      'quantityTotalKwh': draft.availableEnergyKwh,
      'quantitySoldKwh': 0,
      'totalRevenue': 0,
      'pricePerKwh': draft.pricePerKwh,
      'location': 'Your neighbourhood',
      'batteryBacked': draft.batteryReservePercentage >= 25,
      'renewableVerified': true,
      'availabilityStart': draft.availabilityStart.toIso8601String(),
      'availabilityEnd': draft.availabilityEnd.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'listingStatus': ListingStatus.active.name,
    });
    return _listingFromStore(listingData);
  }

  @override
  Future<List<EnergyListing>> myListings() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final owned = _store.getListingsByOwner(currentUserId);
    return owned.map(_listingFromStore).toList();
  }

  @override
  Future<void> cancelListing(String id) async {
    final listing = _store.getListing(id);
    if (listing == null) throw const MarketplaceException('Listing not found.');
    if (listing['sellerId'] != currentUserId)
      throw const MarketplaceException(
        'You can only cancel your own listings.',
      );
    _store.updateListing(id, {'listingStatus': ListingStatus.cancelled.name});
  }

  @override
  Future<EnergyListing> duplicateListing(String id) async {
    final listing = _store.getListing(id);
    if (listing == null) throw const MarketplaceException('Listing not found.');
    if (listing['sellerId'] != currentUserId)
      throw const MarketplaceException(
        'You can only duplicate your own listings.',
      );
    final copy = Map<String, dynamic>.from(listing)
      ..remove('id')
      ..['createdAt'] = DateTime.now().toIso8601String()
      ..['listingStatus'] = ListingStatus.active.name
      ..['availableEnergyKwh'] =
          listing['quantityTotalKwh'] ?? listing['availableEnergyKwh']
      ..['quantitySoldKwh'] = 0
      ..['totalRevenue'] = 0;
    final newEntry = _store.addListing(copy);
    return _listingFromStore(newEntry);
  }

  @override
  Future<void> pauseListing(String id) async {
    final listing = _store.getListing(id);
    if (listing == null) throw const MarketplaceException('Listing not found.');
    if (listing['sellerId'] != currentUserId)
      throw const MarketplaceException('You can only pause your own listings.');
    _store.updateListing(id, {'listingStatus': ListingStatus.cancelled.name});
  }

  @override
  Future<void> deleteListing(String id) async {
    final listing = _store.getListing(id);
    if (listing == null) throw const MarketplaceException('Listing not found.');
    if (listing['sellerId'] != currentUserId)
      throw const MarketplaceException(
        'You can only delete your own listings.',
      );
    _store.listings.remove(id);
  }

  @override
  Future<EnergyListing> updateListingQuantity(
    String id,
    double newQuantity,
  ) async {
    final listing = _store.getListing(id);
    if (listing == null) throw const MarketplaceException('Listing not found.');
    if (listing['sellerId'] != currentUserId)
      throw const MarketplaceException(
        'You can only update your own listings.',
      );
    final totalKwh =
        (listing['quantityTotalKwh'] as num?)?.toDouble() ?? newQuantity;
    if (newQuantity < 0)
      throw const MarketplaceException('Quantity cannot be negative.');
    _store.updateListing(id, {
      'availableEnergyKwh': newQuantity,
      'quantityTotalKwh': totalKwh,
    });
    return _listingFromStore(listing);
  }

  @override
  EnergyPurchase? get latestPurchase {
    final purchases = _store.getPurchasesByBuyer(currentUserId);
    return purchases.isEmpty ? null : _purchaseFromStore(purchases.last);
  }

  EnergyListing _listingFromStore(Map<String, dynamic> data) {
    final sourceVal = data['energySource'];
    final sourceStr = (sourceVal is String ? sourceVal : 'solar');
    final statusVal = data['listingStatus'];
    final statusStr = (statusVal is String ? statusVal : 'active');
    final source = EnergySource.values.firstWhere(
      (s) => s.name == sourceStr,
      orElse: () => EnergySource.solar,
    );
    final status = ListingStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => ListingStatus.active,
    );
    return EnergyListing(
      id: data['id']?.toString() ?? '',
      sellerId: data['sellerId']?.toString() ?? '',
      sellerName: data['sellerName']?.toString() ?? 'Seller',
      sellerRole: data['sellerRole']?.toString() ?? 'producer',
      sellerInitials: _initials(data['sellerName']?.toString() ?? 'Seller'),
      sellerRating: (data['sellerRating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      energySource: source,
      availableEnergyKwh: (data['availableEnergyKwh'] as num?)?.toDouble() ?? 0,
      quantityTotalKwh: (data['quantityTotalKwh'] as num?)?.toDouble(),
      quantitySoldKwh: (data['quantitySoldKwh'] as num?)?.toDouble(),
      totalRevenue: (data['totalRevenue'] as num?)?.toDouble(),
      pricePerKwh: (data['pricePerKwh'] as num?)?.toDouble() ?? 0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      location: data['location']?.toString() ?? '',
      batteryBacked: data['batteryBacked'] == true,
      renewableVerified: data['renewableVerified'] == true,
      availabilityStart: _parseDt(data['availabilityStart']),
      availabilityEnd: _parseDt(data['availabilityEnd']),
      createdAt: _parseDt(data['createdAt']),
      listingStatus: status,
      notes: data['title']?.toString() ?? data['notes']?.toString(),
    );
  }

  EnergyPurchase _purchaseFromStore(Map<String, dynamic> data) {
    final statusName = data['status']?.toString() ?? 'completed';
    final status = PurchaseStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => PurchaseStatus.completed,
    );
    return EnergyPurchase(
      id: data['id']?.toString() ?? '',
      listingId: data['listingId']?.toString() ?? '',
      buyerId: data['buyerId']?.toString() ?? '',
      sellerId: data['sellerId']?.toString() ?? '',
      sellerName: data['sellerName']?.toString(),
      listingTitle: data['listingTitle']?.toString(),
      quantityKwh: (data['quantityKwh'] as num?)?.toDouble() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      estimatedSavings: (data['estimatedSavings'] as num?)?.toDouble() ?? 0,
      co2ImpactKg: (data['co2ImpactKg'] as num?)?.toDouble() ?? 0,
      purchasedAt: _parseDt(data['purchasedAt']),
      status: status,
      buyerName: data['buyerName']?.toString(),
      listingStatus: data['listingStatus']?.toString(),
    );
  }

  List<EnergyListing> _applyQuery(
    List<EnergyListing> source,
    MarketplaceQuery query,
  ) {
    Iterable<EnergyListing> result = source.where(
      (item) => item.listingStatus == ListingStatus.active && !item.isSoldOut,
    );
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      result = result.where(
        (item) =>
            item.sellerName.toLowerCase().contains(search) ||
            item.location.toLowerCase().contains(search) ||
            item.energySource.label.toLowerCase().contains(search),
      );
    }
    for (final filter in query.filters) {
      result = switch (filter) {
        MarketplaceFilter.cheapest => result.where(
          (item) => item.pricePerKwh <= 8.2,
        ),
        MarketplaceFilter.nearby => result.where(
          (item) => item.distanceKm <= 3,
        ),
        MarketplaceFilter.highestRating => result.where(
          (item) => item.sellerRating >= 4.8,
        ),
        MarketplaceFilter.solarOnly => result.where(
          (item) =>
              item.energySource == EnergySource.solar ||
              item.energySource == EnergySource.communitySolar,
        ),
        MarketplaceFilter.batteryBacked => result.where(
          (item) => item.batteryBacked,
        ),
        MarketplaceFilter.availableNow => result.where(
          (item) =>
              item.availabilityStart.isBefore(_now) &&
              item.availabilityEnd.isAfter(_now),
        ),
        MarketplaceFilter.underEight => result.where(
          (item) => item.pricePerKwh < 8,
        ),
      };
    }
    final list = result.toList();
    list.sort(
      (a, b) => switch (query.sort) {
        MarketplaceSort.priceLow => a.pricePerKwh.compareTo(b.pricePerKwh),
        MarketplaceSort.priceHigh => b.pricePerKwh.compareTo(a.pricePerKwh),
        MarketplaceSort.distance => a.distanceKm.compareTo(b.distanceKm),
        MarketplaceSort.rating => b.sellerRating.compareTo(a.sellerRating),
        MarketplaceSort.energyAvailable => b.availableEnergyKwh.compareTo(
          a.availableEnergyKwh,
        ),
      },
    );
    return list;
  }

  void _validateDraft(SellListingDraft draft, double maxAvailableKwh) {
    if (draft.availableEnergyKwh <= 0)
      throw const MarketplaceException('Energy amount must be positive.');
    if (draft.availableEnergyKwh > maxAvailableKwh)
      throw const MarketplaceException('Listing exceeds available energy.');
    if (draft.pricePerKwh <= 0)
      throw const MarketplaceException('Price must be positive.');
    if (draft.batteryReservePercentage < 0 ||
        draft.batteryReservePercentage > 100)
      throw const MarketplaceException('Reserve must be between 0 and 100.');
    if (!draft.availabilityEnd.isAfter(draft.availabilityStart))
      throw const MarketplaceException('End time must be after start time.');
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  DateTime _parseDt(Object? val) {
    if (val == null) return _now;
    if (val is DateTime) return val;
    if (val is String) {
      try {
        return DateTime.parse(val);
      } catch (_) {
        return _now;
      }
    }
    return _now;
  }
}

class MarketplaceException implements Exception {
  const MarketplaceException(this.message);
  final String message;
  @override
  String toString() => message;
}
