import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/network/auth_token_provider.dart';
import 'package:frontend/features/ai/data/ai_repository.dart';
import 'package:frontend/features/admin_dashboard/data/admin_mgmt_repository.dart';
import 'package:frontend/features/marketplace/data/marketplace_mock_repository.dart';
import 'package:frontend/features/marketplace/data/mock_backend_store.dart';
import 'package:frontend/features/marketplace/domain/marketplace_filter.dart';
import 'package:frontend/features/marketplace/domain/sell_listing_draft.dart';

class _FakeTokenProvider implements AuthTokenProvider {
  @override
  Future<String?> accessToken() async => 'fake-token';

  @override
  Future<String?> forceRefresh() async => 'fake-token';
}

class _FailingApiClient extends ApiClient {
  _FailingApiClient()
    : super(
        config: const AppConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: 'publishable',
        ),
        tokenProvider: _FakeTokenProvider(),
      );

  @override
  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? headers,
    String? idempotencyKey,
  }) async {
    throw const ApiException(
      code: 'TIMEOUT',
      message: 'Connection timed out',
      statusCode: 408,
    );
  }
}

void main() {
  group('Stabilization & Regression Tests', () {
    test(
      'Producer listing creation validates energy amount against available generation',
      () async {
        final store = MockBackendStore.fresh();
        final repo = MarketplaceMockRepository(
          currentUserId: 'producer-1',
          currentUserRole: 'producer',
          store: store,
        );

        final now = DateTime.now();

        // Attempting to list more than maxAvailableKwh (14.3) should throw an informative error
        expect(
          () => repo.createListing(
            draft: SellListingDraft(
              availableEnergyKwh: 20.0,
              pricePerKwh: 6.5,
              energySource: EnergySource.solar,
              batteryReservePercentage: 20,
              availabilityStart: now,
              availabilityEnd: now.add(const Duration(hours: 4)),
            ),
            canSell: true,
            maxAvailableKwh: 14.3,
          ),
          throwsA(
            predicate<Exception>(
              (e) =>
                  e.toString().contains('14.3') ||
                  e.toString().contains('Listing exceeds available energy'),
            ),
          ),
        );

        // Attempting to list <= 0 energy should fail
        expect(
          () => repo.createListing(
            draft: SellListingDraft(
              availableEnergyKwh: 0,
              pricePerKwh: 6.5,
              energySource: EnergySource.solar,
              batteryReservePercentage: 20,
              availabilityStart: now,
              availabilityEnd: now.add(const Duration(hours: 4)),
            ),
            canSell: true,
            maxAvailableKwh: 14.3,
          ),
          throwsA(
            predicate<Exception>(
              (e) => e.toString().contains('Energy amount must be positive'),
            ),
          ),
        );

        // Non-seller role should be rejected
        final consumerRepoForRejection = MarketplaceMockRepository(
          currentUserId: 'consumer-test',
          currentUserRole: 'consumer',
          store: store,
        );
        expect(
          () => consumerRepoForRejection.createListing(
            draft: SellListingDraft(
              availableEnergyKwh: 5.0,
              pricePerKwh: 6.5,
              energySource: EnergySource.solar,
              batteryReservePercentage: 20,
              availabilityStart: now,
              availabilityEnd: now.add(const Duration(hours: 4)),
            ),
            canSell: false,
            maxAvailableKwh: 14.3,
          ),
          throwsA(
            predicate<Exception>(
              (e) => e.toString().contains(
                'This role cannot publish energy listings',
              ),
            ),
          ),
        );

        // Valid listing amount creates listing immediately without timeout
        final listing = await repo.createListing(
          draft: SellListingDraft(
            availableEnergyKwh: 5.0,
            pricePerKwh: 6.5,
            energySource: EnergySource.solar,
            batteryReservePercentage: 20,
            availabilityStart: now,
            availabilityEnd: now.add(const Duration(hours: 4)),
          ),
          canSell: true,
          maxAvailableKwh: 14.3,
        );

        expect(listing.id, isNotEmpty);
        expect(listing.availableEnergyKwh, 5.0);
        expect(listing.listingStatus, ListingStatus.active);
      },
    );

    test(
      'Consumer purchase decrements inventory and marks sold when depleted',
      () async {
        final store = MockBackendStore.fresh();
        final producerRepo = MarketplaceMockRepository(
          currentUserId: 'producer-1',
          currentUserRole: 'producer',
          store: store,
        );

        final now = DateTime.now();

        final listing = await producerRepo.createListing(
          draft: SellListingDraft(
            availableEnergyKwh: 4.0,
            pricePerKwh: 7.0,
            energySource: EnergySource.solar,
            batteryReservePercentage: 20,
            availabilityStart: now,
            availabilityEnd: now.add(const Duration(hours: 4)),
          ),
          canSell: true,
          maxAvailableKwh: 14.3,
        );

        final consumerRepo = MarketplaceMockRepository(
          currentUserId: 'consumer-1',
          currentUserRole: 'consumer',
          store: store,
        );

        // Partial purchase
        final purchase1 = await consumerRepo.purchase(
          listingId: listing.id,
          buyerId: 'consumer-1',
          quantityKwh: 2.5,
          canBuy: true,
        );
        expect(purchase1.quantityKwh, 2.5);

        final updatedListing = await consumerRepo.listingById(listing.id);
        expect(updatedListing.availableEnergyKwh, 1.5);
        expect(updatedListing.listingStatus, ListingStatus.active);

        // Purchase remainder
        await consumerRepo.purchase(
          listingId: listing.id,
          buyerId: 'consumer-1',
          quantityKwh: 1.5,
          canBuy: true,
        );

        final depletedListing = await consumerRepo.listingById(listing.id);
        expect(depletedListing.availableEnergyKwh, 0.0);
        expect(depletedListing.listingStatus, ListingStatus.sold);
        expect(depletedListing.isSoldOut, isTrue);
      },
    );

    test(
      'GeminiHybridAiRepository falls back gracefully on API failure',
      () async {
        final failingApi = AiApiRepository(_FailingApiClient());
        final hybridRepo = GeminiHybridAiRepository(failingApi);

        // Pricing suggestion should return fallback safely without throwing
        final suggestion = await hybridRepo.pricingSuggestion(quantityKwh: 5.0);
        expect(suggestion.suggestedPrice, greaterThan(0));

        // Chat should return fallback response without crashing
        final chatResponse = await hybridRepo.chat('How to optimize battery?');
        expect(chatResponse.answer, isNotEmpty);
      },
    );

    test(
      'Consumer purchases and Producer sales share canonical MockBackendStore transactions',
      () async {
        final store = MockBackendStore.fresh();
        final producerRepo = MarketplaceMockRepository(
          currentUserId: 'producer-1',
          currentUserRole: 'producer',
          store: store,
        );
        final consumerRepo = MarketplaceMockRepository(
          currentUserId: 'consumer-1',
          currentUserRole: 'consumer',
          store: store,
        );

        final now = DateTime.now();

        // 1. Producer creates listing
        final listing = await producerRepo.createListing(
          draft: SellListingDraft(
            availableEnergyKwh: 10.0,
            pricePerKwh: 5.5,
            energySource: EnergySource.solar,
            batteryReservePercentage: 20,
            availabilityStart: now,
            availabilityEnd: now.add(const Duration(hours: 4)),
          ),
          canSell: true,
          maxAvailableKwh: 14.3,
        );

        // 2. Consumer purchases 6 kWh
        final purchase = await consumerRepo.purchase(
          listingId: listing.id,
          buyerId: 'consumer-1',
          quantityKwh: 6.0,
          canBuy: true,
        );

        // Verify purchase in store
        final buyerPurchases = store.getPurchasesByBuyer('consumer-1');
        expect(buyerPurchases.any((p) => p['id'] == purchase.id), isTrue);

        // Verify sale appears for producer in store
        final sellerSales = store.getPurchasesBySeller('producer-1');
        expect(sellerSales.any((s) => s['id'] == purchase.id), isTrue);

        // Verify buyer isolation: consumer-2 does not see consumer-1's purchase
        final otherBuyerPurchases = store.getPurchasesByBuyer('consumer-2');
        expect(otherBuyerPurchases.any((p) => p['id'] == purchase.id), isFalse);
      },
    );

    test(
      'Admin user management suspends and reactivates users correctly',
      () async {
        final adminRepo = AdminMgmtMockRepository();

        // Get initial user list
        final initialUsers = await adminRepo.listUsers();
        expect(initialUsers.items, isNotEmpty);

        final targetUser = initialUsers.items.firstWhere((u) => u.isActive);
        final userId = targetUser.id;

        // Suspend user
        final suspendedUser = await adminRepo.suspendUser(userId);
        expect(suspendedUser.isActive, isFalse);

        final detailAfterSuspend = await adminRepo.getUserDetail(userId);
        expect(detailAfterSuspend.isActive, isFalse);

        // Reactivate user
        final reactivatedUser = await adminRepo.reactivateUser(userId);
        expect(reactivatedUser.isActive, isTrue);

        final detailAfterReactivate = await adminRepo.getUserDetail(userId);
        expect(detailAfterReactivate.isActive, isTrue);
      },
    );
  });
}
