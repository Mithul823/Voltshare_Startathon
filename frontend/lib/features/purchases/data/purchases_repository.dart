import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../authentication/data/auth_repository.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../marketplace/domain/marketplace_filter.dart';

abstract class PurchasesRepository {
  Future<List<EnergyPurchase>> loadPurchases();
}

/// Fetches purchases from the backend's unauthenticated ``/mock/purchases``
/// endpoint (stored in ``data/purchases.json``).
///
/// Uses [buyerId] (when non-empty) to filter purchases by the current user
/// so that each user only sees their own purchase history.
class MockPurchasesRepository implements PurchasesRepository {
  MockPurchasesRepository({
    required String baseUrl,
    this.buyerId = '',
    http.Client? httpClient,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;

  /// The current user's ID — filters purchases to only this buyer.
  /// If empty, all purchases are returned (demo/no-auth mode).
  final String buyerId;

  @override
  Future<List<EnergyPurchase>> loadPurchases() async {
    try {
      final queryParams = buyerId.isNotEmpty
          ? '?buyerId=${Uri.encodeQueryComponent(buyerId)}'
          : '';
      final uri = Uri.parse('$_baseUrl/mock/purchases$queryParams');
      final response = await _httpClient
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as List;
        return data.map((item) => _parsePurchase(item as Map)).toList();
      }
    } catch (_) {
      // Backend unavailable — fall through to empty list
    }

    await Future<void>.delayed(const Duration(milliseconds: 100));
    return [];
  }
}

/// Fetches purchases from the authenticated backend endpoint.
class LivePurchasesRepository implements PurchasesRepository {
  LivePurchasesRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<EnergyPurchase>> loadPurchases() async {
    final data = await _client.get('/purchases') as List;
    return data.map((item) => _parsePurchase(item as Map)).toList();
  }
}

EnergyPurchase _parsePurchase(Map data) {
  final statusName = data['status']?.toString() ?? 'confirmed';
  final parsedStatus = PurchaseStatus.values.firstWhere(
    (s) => s.name == statusName || s.name.toLowerCase() == statusName.toLowerCase(),
    orElse: () => PurchaseStatus.confirmed,
  );
  return EnergyPurchase(
    id: data['id']?.toString() ?? '',
    listingId: data['listingId']?.toString() ?? data['listing_id']?.toString() ?? '',
    buyerId: data['buyerId']?.toString() ?? data['buyer_id']?.toString() ?? '',
    sellerId: data['sellerId']?.toString() ?? data['seller_id']?.toString() ?? '',
    sellerName: data['sellerName']?.toString() ?? data['seller_name']?.toString(),
    listingTitle: data['listingTitle']?.toString() ?? data['listing_title']?.toString(),
    quantityKwh: (data['quantityKwh'] ?? data['quantity_kwh'] ?? 0).toDouble(),
    unitPrice: (data['unitPrice'] ?? data['unit_price'] ?? 0).toDouble(),
    platformFee: (data['platformFee'] ?? data['platform_fee'] ?? 0).toDouble(),
    totalAmount: (data['totalAmount'] ?? data['total_amount'] ?? 0).toDouble(),
    estimatedSavings: (data['estimatedSavings'] ?? data['estimated_savings'] ?? 0).toDouble(),
    co2ImpactKg: (data['co2ImpactKg'] ?? data['co2_impact_kg'] ?? 0).toDouble(),
    purchasedAt: DateTime.tryParse(
        data['purchasedAt']?.toString() ?? data['purchased_at']?.toString() ?? '',
    ) ?? DateTime.now(),
    status: parsedStatus,
  );
}

/// Resolves the current user ID from auth state for mock mode.
String _mockUserId(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null) return profile.id;
  final session = ref.read(currentSessionProvider);
  if (session != null) return session.user.id;
  return '';
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return LivePurchasesRepository(ref.watch(apiClientProvider));
  }
  // In mock mode, fetch purchases from the backend's mock endpoint
  // so simulated purchases appear in the purchase history screen.
  // Resolve buyerId from auth state so purchases filter to current user.
  final userId = _mockUserId(ref);
  return MockPurchasesRepository(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    buyerId: userId,
  );
});

final purchasesListProvider = FutureProvider.autoDispose<List<EnergyPurchase>>((ref) {
  final repository = ref.watch(purchasesRepositoryProvider);
  return repository.loadPurchases();
});
