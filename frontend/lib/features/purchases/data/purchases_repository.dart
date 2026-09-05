import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../authentication/data/auth_repository.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../marketplace/domain/marketplace_filter.dart';

import '../../marketplace/data/mock_backend_store.dart';

abstract class PurchasesRepository {
  Future<List<EnergyPurchase>> loadPurchases();
}

/// Fetches purchases from the centralized [MockBackendStore] in mock mode.
///
/// Uses [buyerId] (when non-empty) to filter purchases by the current user
/// so that each user only sees their own purchase history.
class MockPurchasesRepository implements PurchasesRepository {
  MockPurchasesRepository({this.buyerId = '', MockBackendStore? store})
    : _store = store ?? MockBackendStore();

  /// The current user's ID — filters purchases to only this buyer.
  /// If empty, all purchases are returned (demo/no-auth mode).
  final String buyerId;
  final MockBackendStore _store;

  @override
  Future<List<EnergyPurchase>> loadPurchases() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _store.seed();
    final raw = buyerId.isNotEmpty
        ? _store.getPurchasesByBuyer(buyerId)
        : _store.purchases;
    return raw.map((item) => _parsePurchase(item)).toList();
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
    (s) => s.name.toLowerCase() == statusName.toLowerCase(),
    orElse: () => PurchaseStatus.confirmed,
  );
  return EnergyPurchase(
    id: data['id']?.toString() ?? '',
    listingId:
        data['listingId']?.toString() ?? data['listing_id']?.toString() ?? '',
    buyerId:
        data['buyerId']?.toString() ??
        data['buyer_id']?.toString() ??
        data['consumerId']?.toString() ??
        data['consumer_id']?.toString() ??
        '',
    sellerId:
        data['sellerId']?.toString() ??
        data['seller_id']?.toString() ??
        data['producerId']?.toString() ??
        data['producer_id']?.toString() ??
        '',
    sellerName:
        data['sellerName']?.toString() ??
        data['seller_name']?.toString() ??
        'Energy Producer',
    listingTitle:
        data['listingTitle']?.toString() ??
        data['listing_title']?.toString() ??
        'Clean Energy',
    quantityKwh: (data['quantityKwh'] ?? data['quantity_kwh'] ?? 0).toDouble(),
    unitPrice: (data['unitPrice'] ?? data['unit_price'] ?? 0).toDouble(),
    platformFee: (data['platformFee'] ?? data['platform_fee'] ?? 0).toDouble(),
    totalAmount: (data['totalAmount'] ?? data['total_amount'] ?? 0).toDouble(),
    estimatedSavings:
        (data['estimatedSavings'] ?? data['estimated_savings'] ?? 0).toDouble(),
    co2ImpactKg: (data['co2ImpactKg'] ?? data['co2_impact_kg'] ?? 0).toDouble(),
    purchasedAt:
        DateTime.tryParse(
          data['purchasedAt']?.toString() ??
              data['purchased_at']?.toString() ??
              data['createdAt']?.toString() ??
              data['created_at']?.toString() ??
              '',
        ) ??
        DateTime.now(),
    status: parsedStatus,
  );
}

/// Resolves the current user ID from auth state for mock mode.
String _mockUserId(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null && profile.id.isNotEmpty) return profile.id;
  final session = ref.watch(currentSessionProvider);
  if (session != null && session.user.id.isNotEmpty) return session.user.id;
  return 'consumer-1';
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  // Watch profile and session to update when user logs in/out
  ref.watch(currentProfileProvider);
  ref.watch(currentSessionProvider);
  if (ref.watch(appConfigProvider).isLiveMode) {
    return LivePurchasesRepository(ref.watch(apiClientProvider));
  }
  final userId = _mockUserId(ref);
  return MockPurchasesRepository(buyerId: userId);
});

final purchasesListProvider = FutureProvider.autoDispose<List<EnergyPurchase>>((
  ref,
) {
  final repository = ref.watch(purchasesRepositoryProvider);
  return repository.loadPurchases();
});
