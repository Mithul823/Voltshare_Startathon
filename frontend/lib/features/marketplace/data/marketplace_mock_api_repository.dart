/// Mock-mode marketplace repository that posts/gets listings from the backend.
///
/// When ``USE_MOCK_BACKEND=true``, producers create listings by POSTing to the
/// backend's unauthenticated ``/mock/listings`` endpoint (instead of storing
/// them in the local ``MockBackendStore`` singleton).  The backend persists
/// them to ``data/listings.json`` via ``JsonFileMarketplaceRepository`` so
/// that a consumer on another device can see the same listings by GETing
/// that endpoint.
///
/// Operations that are purely local (quote calculation, price validation)
/// are still handled in-process for responsiveness.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/energy_listing.dart';
import '../domain/energy_purchase.dart';
import '../domain/marketplace_filter.dart';
import '../domain/sell_listing_draft.dart';
import 'marketplace_mock_repository.dart';

class MarketplaceMockApiRepository implements MarketplaceRepository {
  MarketplaceMockApiRepository({
    required String baseUrl,
    required this.currentUserId,
    required this.currentUserRole,
    this.currentUserName = 'Energy Seller',
    http.Client? httpClient,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;
  final String currentUserId;
  final String currentUserRole;
  final String currentUserName;

  EnergyPurchase? _latestPurchase;

  static const platformFeeRate = 0.03;
  static const gridPricePerKwh = 10.25;
  static const co2KgPerKwh = 0.7;

  // ── helpers ────────────────────────────────────────────────────────

  Future<Object?> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw MarketplaceException(
      'Backend request failed: ${response.statusCode}',
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded as Map<String, dynamic>;
    }
    throw MarketplaceException(
      'Backend request failed: ${response.statusCode}',
    );
  }

  Future<void> _postNoBody(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient
        .post(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw MarketplaceException(
      'Backend request failed: ${response.statusCode}',
    );
  }

  // ── MarketplaceRepository interface ────────────────────────────────

  @override
  Future<List<EnergyListing>> loadListings(MarketplaceQuery query) async {
    try {
      final data = await _get('/mock/listings');
      final parsed = (data as List)
          .map((item) => _listingFromJson(item as Map<String, dynamic>))
          .toList();
      return _applyQuery(parsed, query);
    } catch (_) {
      // If the backend is not running, fall back to an empty list
      return [];
    }
  }

  @override
  Future<EnergyListing> listingById(String id) async {
    final data = await _get('/mock/listings/$id');
    return _listingFromJson(data as Map<String, dynamic>);
  }

  @override
  PurchaseQuote quote(EnergyListing listing, double quantityKwh) {
    if (quantityKwh < 0.5) {
      throw const MarketplaceException('Select at least 0.5 kWh.');
    }
    if (quantityKwh > listing.availableEnergyKwh) {
      throw const MarketplaceException('Not enough energy available.');
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
    if (!canBuy) {
      throw const MarketplaceException(
        'This role can browse but cannot buy energy.',
      );
    }

    // Fetch the listing from the backend to get latest state
    EnergyListing listing;
    try {
      listing = await listingById(listingId);
    } catch (_) {
      throw const MarketplaceException('Listing unavailable.');
    }

    if (listing.sellerId == buyerId) {
      throw const MarketplaceException(
        'You cannot purchase your own energy listing.',
      );
    }

    if (quantityKwh > listing.availableEnergyKwh) {
      throw MarketplaceException(
        'Only ${listing.availableEnergyKwh.toStringAsFixed(1)} kWh is currently available.',
      );
    }

    final subtotal = quantityKwh * listing.pricePerKwh;
    final fee = subtotal * platformFeeRate;
    final totalAmount = subtotal + fee;

    // POST purchase to the backend → persisted to data/purchases.json
    // The backend also updates the listing's available energy atomically.
    try {
      final data = await _post('/mock/purchases', {
        'listingId': listingId,
        'buyerId': buyerId,
        'sellerId': listing.sellerId,
        'sellerName': listing.sellerName,
        'listingTitle': listing.notes,
        'quantityKwh': quantityKwh,
        'unitPrice': listing.pricePerKwh,
        'platformFee': fee,
        'totalAmount': totalAmount,
        'estimatedSavings': (quantityKwh * gridPricePerKwh - subtotal).clamp(
          0,
          double.infinity,
        ),
        'co2ImpactKg': quantityKwh * co2KgPerKwh,
      });

      final purchase = _purchaseFromJson(data);
      _latestPurchase = purchase;
      return purchase;
    } catch (_) {
      // If the backend call fails, fall back to local-only purchase
      // (won't appear in purchase history, but the user's flow continues)
      final purchase = EnergyPurchase(
        id: 'mock-purchase-${DateTime.now().millisecondsSinceEpoch}',
        listingId: listingId,
        buyerId: buyerId,
        sellerId: listing.sellerId,
        sellerName: listing.sellerName,
        listingTitle: listing.notes,
        quantityKwh: quantityKwh,
        unitPrice: listing.pricePerKwh,
        platformFee: fee,
        totalAmount: totalAmount,
        estimatedSavings: (quantityKwh * gridPricePerKwh - subtotal).clamp(
          0,
          double.infinity,
        ),
        co2ImpactKg: quantityKwh * co2KgPerKwh,
        purchasedAt: DateTime.now(),
        status: PurchaseStatus.completed,
      );
      _latestPurchase = purchase;
      return purchase;
    }
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

    _validateDraft(draft, maxAvailableKwh);

    // POST to the backend → gets persisted as JSON file
    final data = await _post('/mock/listings', {
      'sellerId': currentUserId,
      'sellerName': currentUserName,
      'sellerRole': currentUserRole,
      'title': draft.notes.isNotEmpty ? draft.notes : 'Energy Listing',
      'energySource': draft.energySource.name,
      'availableEnergyKwh': draft.availableEnergyKwh,
      'pricePerKwh': draft.pricePerKwh,
      'batteryReservePercentage': draft.batteryReservePercentage,
      'availabilityStart': draft.availabilityStart.toIso8601String(),
      'availabilityEnd': draft.availabilityEnd.toIso8601String(),
      'notes': draft.notes,
    });

    return _listingFromJson(data);
  }

  @override
  Future<List<EnergyListing>> myListings() async {
    try {
      final data = await _get('/mock/listings/all');
      final all = (data as List)
          .map((item) => _listingFromJson(item as Map<String, dynamic>))
          .toList();
      return all.where((l) => l.sellerId == currentUserId).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> cancelListing(String id) async {
    await _postNoBody('/mock/listings/$id/cancel');
  }

  @override
  Future<EnergyListing> duplicateListing(String id) async {
    // Fetch, mutate, re-POST
    final listing = await listingById(id);
    final data = await _post('/mock/listings', {
      'sellerId': currentUserId,
      'sellerName': currentUserName,
      'sellerRole': currentUserRole,
      'title': '${listing.notes ?? 'Energy Listing'} (Copy)',
      'energySource': listing.energySource.name,
      'availableEnergyKwh': listing.availableEnergyKwh,
      'pricePerKwh': listing.pricePerKwh,
      'batteryReservePercentage': listing.batteryBacked ? 25 : 0,
      'availabilityStart': DateTime.now().toIso8601String(),
      'availabilityEnd': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
      'notes': '${listing.notes ?? 'Energy Listing'} (Copy)',
    });
    return _listingFromJson(data);
  }

  @override
  Future<void> pauseListing(String id) async {
    await _postNoBody('/mock/listings/$id/pause');
  }

  @override
  Future<void> deleteListing(String id) async {
    await _postNoBody('/mock/listings/$id/delete');
  }

  @override
  Future<EnergyListing> updateListingQuantity(
    String id,
    double newQuantity,
  ) async {
    final data = await _post('/mock/listings/$id/quantity', {
      'availableEnergyKwh': newQuantity,
    });
    return _listingFromJson(data);
  }

  @override
  EnergyPurchase? get latestPurchase => _latestPurchase;

  // ── internals ──────────────────────────────────────────────────────

  EnergyPurchase _purchaseFromJson(Map<String, dynamic> data) {
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
    );
  }

  EnergyListing _listingFromJson(Map<String, dynamic> data) {
    final sourceStr = data['energySource']?.toString() ?? 'solar';
    final statusStr = data['listingStatus']?.toString() ?? 'active';
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
      pricePerKwh: (data['pricePerKwh'] as num?)?.toDouble() ?? 0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      location: data['location']?.toString() ?? '',
      batteryBacked: data['batteryBacked'] == true,
      renewableVerified: data['renewableVerified'] == true,
      availabilityStart: _parseDt(data['availabilityStart']),
      availabilityEnd: _parseDt(data['availabilityEnd']),
      createdAt: _parseDt(data['createdAt']),
      listingStatus: status,
      notes: data['notes']?.toString() ?? data['title']?.toString(),
    );
  }

  List<EnergyListing> _applyQuery(
    List<EnergyListing> source,
    MarketplaceQuery query,
  ) {
    Iterable<EnergyListing> result = source.where(
      (item) => item.listingStatus == ListingStatus.active,
    );
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      result = result.where((item) {
        return item.sellerName.toLowerCase().contains(search) ||
            item.location.toLowerCase().contains(search) ||
            item.energySource.label.toLowerCase().contains(search);
      });
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
              item.availabilityStart.isBefore(DateTime.now()) &&
              item.availabilityEnd.isAfter(DateTime.now()),
        ),
        MarketplaceFilter.underEight => result.where(
          (item) => item.pricePerKwh < 8,
        ),
      };
    }
    final list = result.toList();
    list.sort((a, b) {
      return switch (query.sort) {
        MarketplaceSort.priceLow => a.pricePerKwh.compareTo(b.pricePerKwh),
        MarketplaceSort.priceHigh => b.pricePerKwh.compareTo(a.pricePerKwh),
        MarketplaceSort.distance => a.distanceKm.compareTo(b.distanceKm),
        MarketplaceSort.rating => b.sellerRating.compareTo(a.sellerRating),
        MarketplaceSort.energyAvailable => b.availableEnergyKwh.compareTo(
          a.availableEnergyKwh,
        ),
      };
    });
    return list;
  }

  void _validateDraft(SellListingDraft draft, double maxAvailableKwh) {
    if (draft.availableEnergyKwh <= 0) {
      throw const MarketplaceException('Energy amount must be positive.');
    }
    if (draft.availableEnergyKwh > maxAvailableKwh) {
      throw const MarketplaceException('Listing exceeds available energy.');
    }
    if (draft.pricePerKwh <= 0) {
      throw const MarketplaceException('Price must be positive.');
    }
    if (draft.batteryReservePercentage < 0 ||
        draft.batteryReservePercentage > 100) {
      throw const MarketplaceException('Reserve must be between 0 and 100.');
    }
    if (!draft.availabilityEnd.isAfter(draft.availabilityStart)) {
      throw const MarketplaceException('End time must be after start time.');
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  DateTime _parseDt(Object? val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    if (val is String) {
      try {
        return DateTime.parse(val);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
