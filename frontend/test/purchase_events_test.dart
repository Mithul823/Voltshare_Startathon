import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/features/authentication/data/auth_repository.dart';
import 'package:frontend/features/marketplace/data/marketplace_mock_repository.dart';
import 'package:frontend/features/marketplace/domain/energy_purchase.dart';
import 'package:frontend/features/marketplace/providers/marketplace_provider.dart';

class FailingPurchaseRepository extends MarketplaceMockRepository {
  FailingPurchaseRepository()
    : super(currentUserId: 'buyer', currentUserRole: 'consumer');
  bool attempted = false;
  @override
  Future<EnergyPurchase> purchase({
    required String listingId,
    required String buyerId,
    required double quantityKwh,
    required bool canBuy,
  }) async {
    attempted = true;
    throw StateError('Payment rejected');
  }
}

void main() {
  test('failed purchases never send external sale events', () async {
    final requests = <http.Request>[];
    final repository = FailingPurchaseRepository();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: '',
            supabasePublishableKey: '',
            useMockBackend: true,
            eventServerUrl: 'https://events.example.com',
          ),
        ),
        currentSessionProvider.overrideWithValue(null),
        currentProfileProvider.overrideWith((ref) async => null),
        marketplaceRepositoryProvider.overrideWithValue(repository),
        marketplacePermissionsProvider.overrideWithValue(
          const MarketplacePermissions(canBuy: true, canSell: false),
        ),
        marketplaceEventClientProvider.overrideWithValue(
          MockClient((request) async {
            requests.add(request);
            return http.Response('{}', 200);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(purchaseControllerProvider.notifier)
        .purchase(listingId: 'ravi', quantityKwh: 1);
    await Future<void>.delayed(Duration.zero);
    expect(repository.attempted, isTrue);
    expect(result, isNull);
    expect(requests, isEmpty);
  });
}
