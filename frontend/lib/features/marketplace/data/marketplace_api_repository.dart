import '../../../core/network/api_client.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../domain/energy_listing.dart';
import '../domain/energy_purchase.dart';
import '../domain/marketplace_filter.dart';
import '../domain/sell_listing_draft.dart';
import 'marketplace_mock_repository.dart';

class MarketplaceApiRepository implements MarketplaceRepository {
  MarketplaceApiRepository(this._client, {IdempotencyKeyGenerator? keys})
    : _keys = keys ?? IdempotencyKeyGenerator();

  final ApiClient _client;
  final IdempotencyKeyGenerator _keys;
  EnergyPurchase? _latestPurchase;

  @override
  Future<List<EnergyListing>> loadListings(MarketplaceQuery query) async {
    final params = <String, String>{
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      'sort': _sortParam(query.sort),
    };
    for (final filter in query.filters) {
      switch (filter) {
        case MarketplaceFilter.cheapest:
          params['maximum_price'] = '8.2';
        case MarketplaceFilter.nearby:
          break;
        case MarketplaceFilter.highestRating:
          params['sort'] = 'rating_high_to_low';
        case MarketplaceFilter.solarOnly:
          params['energy_source'] = 'solar';
        case MarketplaceFilter.batteryBacked:
          break;
        case MarketplaceFilter.availableNow:
          params['available_now'] = 'true';
        case MarketplaceFilter.underEight:
          params['maximum_price'] = '8';
      }
    }
    final data = await _client.get(
      '/listings',
      query: params,
    );
    return (data as List).map((item) => _listing(item as Map)).toList();
  }

  @override
  Future<EnergyListing> listingById(String id) async {
    return _listing(await _client.get('/listings/$id') as Map);
  }

  @override
  PurchaseQuote quote(EnergyListing listing, double quantityKwh) {
    if (quantityKwh < 0.5) {
      throw const MarketplaceException('Select at least 0.5 kWh.');
    }
    if (quantityKwh > listing.availableEnergyKwh) {
      throw const MarketplaceException('Not enough energy available.');
    }
    const platformFeeRate = 0.05;
    const gridPricePerKwh = 10.25;
    const co2KgPerKwh = 0.7;
    final subtotal = quantityKwh * listing.pricePerKwh;
    final fee = subtotal * platformFeeRate;
    return PurchaseQuote(
      quantityKwh: quantityKwh,
      unitPrice: listing.pricePerKwh,
      subtotal: subtotal,
      platformFee: fee,
      totalAmount: subtotal + fee,
      estimatedSavings:
          (quantityKwh * gridPricePerKwh - subtotal)
              .clamp(0, double.infinity),
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
    if (!canBuy) {
      throw const MarketplaceException(
        'This role can browse but cannot buy energy.',
      );
    }
    final data = await _client.post(
      '/purchases',
      idempotencyKey: _keys.next('purchase'),
      body: {'listingId': listingId, 'quantityKwh': quantityKwh},
    ) as Map;
    final purchase = _purchase(data['purchase'] as Map);
    _latestPurchase = purchase;
    return purchase;
  }

  @override
  Future<EnergyListing> createListing({
    required SellListingDraft draft,
    required bool canSell,
    required double maxAvailableKwh,
  }) async {
    if (!canSell) {
      throw const MarketplaceException(
        'This role cannot publish energy listings.',
      );
    }
    final data = await _client.post(
      '/listings',
      idempotencyKey: _keys.next('listing'),
      body: {
        'energySource': draft.energySource.name,
        'availableEnergyKwh': draft.availableEnergyKwh,
        'pricePerKwh': draft.pricePerKwh,
        'batteryReservePercentage': draft.batteryReservePercentage,
        'availabilityStart': draft.availabilityStart.toIso8601String(),
        'availabilityEnd': draft.availabilityEnd.toIso8601String(),
        'notes': draft.notes,
      },
    ) as Map;
    return _listing(data);
  }

  @override
  Future<List<EnergyListing>> myListings() async {
    final data = await _client.get('/users/me/listings') as List;
    return data.map((item) => _listing(item as Map)).toList();
  }

  @override
  Future<void> cancelListing(String id) async {
    await _client.post('/listings/$id/cancel');
  }

  @override
  Future<EnergyListing> duplicateListing(String id) async {
    return _listing(await _client.post('/listings/$id/duplicate') as Map);
  }

  @override
  Future<void> pauseListing(String id) async {
    await _client.post('/listings/$id/suspend');
  }

  @override
  Future<void> deleteListing(String id) async {
    // Use cancel as the delete mechanism since backend doesn't have a dedicated delete
    await _client.post('/listings/$id/cancel');
  }

  @override
  Future<EnergyListing> updateListingQuantity(String id, double newQuantity) async {
    final data = await _client.patch('/listings/$id', body: {
      'availableEnergyKwh': newQuantity,
    }) as Map;
    return _listing(data);
  }

  @override
  EnergyPurchase? get latestPurchase => _latestPurchase;
}

EnergyListing _listing(Map data) {
  return EnergyListing(
    id: data['id'].toString(),
    sellerId: data['sellerId'].toString(),
    sellerName: data['sellerName'].toString(),
    sellerRole: data['sellerRole'].toString(),
    sellerInitials: data['sellerInitials'].toString(),
    sellerRating: (data['sellerRating'] as num).toDouble(),
    reviewCount: (data['reviewCount'] as num).toInt(),
    energySource: EnergySource.values.byName(data['energySource'].toString()),
    availableEnergyKwh: (data['availableEnergyKwh'] as num).toDouble(),
    pricePerKwh: (data['pricePerKwh'] as num).toDouble(),
    distanceKm: (data['distanceKm'] as num).toDouble(),
    location: data['location'].toString(),
    batteryBacked: data['batteryBacked'] == true,
    renewableVerified: data['renewableVerified'] == true,
    availabilityStart: DateTime.parse(data['availabilityStart'].toString()),
    availabilityEnd: DateTime.parse(data['availabilityEnd'].toString()),
    createdAt: DateTime.parse(data['createdAt'].toString()),
    listingStatus: ListingStatus.values.byName(data['listingStatus'].toString()),
    notes: data['notes']?.toString(),
  );
}

String _sortParam(MarketplaceSort sort) {
  return switch (sort) {
    MarketplaceSort.priceLow => 'price_low_to_high',
    MarketplaceSort.priceHigh => 'price_high_to_low',
    MarketplaceSort.distance => 'distance',
    MarketplaceSort.rating => 'rating_high_to_low',
    MarketplaceSort.energyAvailable => 'quantity_high_to_low',
  };
}

EnergyPurchase _purchase(Map data) {
  final statusName = data['status'].toString() == 'cancelled'
      ? 'failed'
      : data['status'].toString();
  return EnergyPurchase(
    id: data['id'].toString(),
    listingId: data['listingId'].toString(),
    buyerId: data['buyerId'].toString(),
    sellerId: data['sellerId'].toString(),
    quantityKwh: (data['quantityKwh'] as num).toDouble(),
    unitPrice: (data['unitPrice'] as num).toDouble(),
    platformFee: (data['platformFee'] as num).toDouble(),
    totalAmount: (data['totalAmount'] as num).toDouble(),
    estimatedSavings: (data['estimatedSavings'] as num).toDouble(),
    co2ImpactKg: (data['co2ImpactKg'] as num).toDouble(),
    purchasedAt: DateTime.parse(data['purchasedAt'].toString()),
    status: PurchaseStatus.values.byName(statusName),
  );
}
