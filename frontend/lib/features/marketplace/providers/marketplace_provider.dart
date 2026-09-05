import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../escrow/providers/escrow_provider.dart';
import '../../metering/data/smart_meter_purchase_service.dart';
import '../../metering/domain/smart_meter_purchase_result.dart';
import '../../metering/providers/meter_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../purchases/data/purchases_repository.dart';
import '../../sales/data/sales_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/marketplace_api_repository.dart';
import '../data/marketplace_mock_api_repository.dart';
import '../data/marketplace_mock_repository.dart';
import '../data/mock_backend_store.dart';
import '../domain/energy_listing.dart';
import '../domain/energy_purchase.dart';
import '../domain/sell_listing_draft.dart';

final marketplaceEventClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Holds the result of the most recent smart meter purchase API synchronization.
final latestSmartMeterResultProvider = StateProvider<SmartMeterPurchaseResult?>(
  (ref) => null,
);

/// Resolves the current user ID from the authenticated session or profile.
/// In mock mode, still uses the real Supabase auth if available.
/// Falls back to a per-session mock user ID if no Supabase session exists.
String _currentUserId(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null && profile.id.isNotEmpty) return profile.id;
  final session = ref.watch(currentSessionProvider);
  if (session != null && session.user.id.isNotEmpty) return session.user.id;
  final role = _currentUserRole(ref);
  return role == 'producer' ? 'producer-1' : 'consumer-1';
}

String _currentUserRole(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null) return profile.role.value;
  final session = ref.watch(currentSessionProvider);
  if (session != null) {
    final role = session.user.userMetadata?['role']?.toString();
    if (role != null && role.isNotEmpty) return role;
  }
  return 'consumer';
}

String _currentUserName(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null && profile.fullName.isNotEmpty) return profile.fullName;
  final session = ref.watch(currentSessionProvider);
  if (session != null) {
    final name = session.user.userMetadata?['full_name']?.toString();
    if (name != null && name.isNotEmpty) return name;
  }
  return 'VoltShare User';
}

/// In live mode, uses [MarketplaceApiRepository].
/// In mock mode, uses [MarketplaceMockApiRepository] with local MockBackendStore fallback.
/// This ensures:
/// - Listings survive logout (stored in MockBackendStore singleton)
/// - sellerId/buyerId come from the authenticated user, not a hardcoded value
/// - Self-purchase is prevented in both modes
/// - Ownership is enforced in both modes
/// Watches auth state so the repository is rebuilt when user changes.
final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  // Watch auth state to rebuild when user logs in/out
  ref.watch(currentProfileProvider);
  ref.watch(currentSessionProvider);
  if (ref.watch(appConfigProvider).isLiveMode) {
    return MarketplaceApiRepository(ref.watch(apiClientProvider));
  }
  return MarketplaceMockRepository(
    currentUserId: _currentUserId(ref),
    currentUserRole: _currentUserRole(ref),
    currentUserName: _currentUserName(ref),
  );
});

final marketplaceQueryProvider = StateProvider<MarketplaceQuery>(
  (ref) => const MarketplaceQuery(),
);

final marketplaceListingsProvider =
    FutureProvider.autoDispose<List<EnergyListing>>((ref) {
      final repository = ref.watch(marketplaceRepositoryProvider);
      final query = ref.watch(marketplaceQueryProvider);
      return repository.loadListings(query);
    });

final marketplaceListingProvider = FutureProvider.autoDispose
    .family<EnergyListing, String>((ref, id) {
      return ref.watch(marketplaceRepositoryProvider).listingById(id);
    });

final myListingsProvider = FutureProvider.autoDispose<List<EnergyListing>>((
  ref,
) {
  return ref.watch(marketplaceRepositoryProvider).myListings();
});

final latestPurchaseProvider = StateProvider<EnergyPurchase?>((ref) => null);

final marketplaceRoleProvider = FutureProvider<UserRole>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile != null) return profile.role;
  return ref.watch(appConfigProvider).isMockMode
      ? UserRole.consumer
      : UserRole.consumer;
});

class MarketplacePermissions {
  const MarketplacePermissions({required this.canBuy, required this.canSell});

  final bool canBuy;
  final bool canSell;
}

final marketplacePermissionsProvider = Provider<MarketplacePermissions>((ref) {
  final isMock = ref.watch(appConfigProvider).isMockMode;
  final role =
      ref.watch(marketplaceRoleProvider).valueOrNull ??
      (isMock ? UserRole.consumer : UserRole.consumer);
  return MarketplacePermissions(
    canBuy: isMock || role == UserRole.consumer || role == UserRole.prosumer,
    canSell: isMock || role == UserRole.producer || role == UserRole.prosumer,
  );
});

final purchaseControllerProvider =
    StateNotifierProvider<PurchaseController, AsyncValue<EnergyPurchase?>>((
      ref,
    ) {
      return PurchaseController(ref);
    });

class PurchaseController extends StateNotifier<AsyncValue<EnergyPurchase?>> {
  PurchaseController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<EnergyPurchase?> purchase({
    required String listingId,
    required double quantityKwh,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncValue.loading();
    try {
      if (quantityKwh <= 0 || quantityKwh.isNaN || quantityKwh.isInfinite) {
        throw const MarketplaceException('Quantity must be a positive number.');
      }

      final appConfig = _ref.read(appConfigProvider);
      final isMockMode = appConfig.isMockMode;
      final eventServerUrl = appConfig.eventServerUrl;
      final eventClient = _ref.read(marketplaceEventClientProvider);
      final permissions = _ref.read(marketplacePermissionsProvider);
      final buyerId = _currentUserId(_ref);
      final marketplaceRepo = _ref.read(marketplaceRepositoryProvider);
      final escrowNotifier = _ref.read(escrowControllerProvider.notifier);
      final walletNotifier = _ref.read(walletControllerProvider.notifier);
      final smartMeterService = _ref.read(smartMeterPurchaseServiceProvider);
      final latestSmartMeterResultNotifier = _ref.read(
        latestSmartMeterResultProvider.notifier,
      );
      final consumerMeterNotifier = _ref.read(consumerMeterProvider.notifier);
      final producerMeterNotifier = _ref.read(producerMeterProvider.notifier);
      final latestPurchaseNotifier = _ref.read(latestPurchaseProvider.notifier);

      if (kDebugMode) {
        print(
          '[PurchaseFlow] Starting purchase: listingId=$listingId, buyerId=$buyerId, '
          'quantityKwh=$quantityKwh, isMockMode=$isMockMode',
        );
      }

      final store = MockBackendStore();
      final countBefore = store.purchases.length;

      // 1. Call backend purchase endpoint - handles escrow, wallet debit, ledger atomically
      final purchase = await marketplaceRepo.purchase(
        listingId: listingId,
        buyerId: buyerId,
        quantityKwh: quantityKwh,
        canBuy: permissions.canBuy,
      );

      final countAfter = store.purchases.length;
      final consumerFilteredCount = store.getPurchasesByBuyer(buyerId).length;

      if (kDebugMode) {
        print(
          '[PurchaseFlow] Business purchase complete: purchaseId=${purchase.id}, listingId=$listingId, '
          'producerId=${purchase.sellerId}, consumerId=$buyerId, '
          'countBefore=$countBefore, countAfter=$countAfter, '
          'consumerFilteredCount=$consumerFilteredCount',
        );
      }

      if (isMockMode) {
        // In mock mode, create escrow and record wallet transaction locally
        final listing = await marketplaceRepo.listingById(listingId);
        final escrow = await escrowNotifier.createForPurchase(
          purchase: purchase,
          listing: listing,
        );
        await walletNotifier.recordPurchase(
          purchase: purchase,
          listing: listing,
          escrowId: escrow.id,
        );
      } else {
        // In live mode, the backend already created escrow and debited wallet.
        // Just refresh providers to reflect the new state.
        unawaited(walletNotifier.refresh());
        unawaited(escrowNotifier.refresh());
      }

      // 2. Transmit Smart Meter Purchase Signal to live hardware/cloud endpoint
      if (kDebugMode) {
        print(
          '[PurchaseFlow] Transmitting smart-meter purchase signal for ${purchase.quantityKwh} kWh...',
        );
      }
      final smartMeterResult = await smartMeterService.sendConsumerPurchase(
        purchase.quantityKwh,
      );

      latestSmartMeterResultNotifier.state = smartMeterResult;

      if (kDebugMode) {
        print(
          '[PurchaseFlow] Smart-meter result: status=${smartMeterResult.status.name}, '
          'message=${smartMeterResult.message ?? smartMeterResult.errorMessage}',
        );
      }

      // 3. Immediately refresh Consumer & Producer Smart Meters
      unawaited(consumerMeterNotifier.refresh());
      unawaited(producerMeterNotifier.refresh());

      // 4. Invalidate related business providers
      latestPurchaseNotifier.state = purchase;
      _ref.invalidate(marketplaceListingsProvider);
      _ref.invalidate(myListingsProvider);
      _ref.invalidate(purchasesListProvider);
      _ref.invalidate(salesProvider);
      _ref.invalidate(walletControllerProvider);
      _ref.invalidate(dashboardProvider);
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationsProvider);

      if (mounted) {
        state = AsyncValue.data(purchase);
      }
      _sendSpeechHomeRight(purchase.unitPrice, eventServerUrl, eventClient);
      _sendSellEvent(
        purchase.unitPrice,
        purchase.quantityKwh,
        eventServerUrl,
        eventClient,
      );
      return purchase;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('[PurchaseFlow] Purchase error: $error\n$stackTrace');
      }
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
      return null;
    }
  }

  /// Sends speech home-right event when a consumer buys at a certain rate.
  void _sendSpeechHomeRight(
    double price,
    String baseUrl,
    http.Client eventClient,
  ) {
    unawaited(_postSpeechHomeRight(price, baseUrl, eventClient));
  }

  Future<void> _postSpeechHomeRight(
    double price,
    String baseUrl,
    http.Client eventClient,
  ) async {
    if (baseUrl.isEmpty) return;
    try {
      await eventClient.post(
        Uri.parse(
          '${baseUrl.replaceFirst(RegExp(r"/+$"), "")}/api/speech/home_right',
        ),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: '{"price": $price, "message": "Buying for $price"}',
      );
    } catch (_) {
      // Silently ignore send failures.
    }
  }

  /// Sends sell event to /api/sell with seller, buyer, and amount info.
  void _sendSellEvent(
    double price,
    double amountKw,
    String baseUrl,
    http.Client eventClient,
  ) {
    unawaited(_postSellEvent(price, amountKw, baseUrl, eventClient));
  }

  Future<void> _postSellEvent(
    double price,
    double amountKw,
    String baseUrl,
    http.Client eventClient,
  ) async {
    if (baseUrl.isEmpty) return;
    try {
      await eventClient.post(
        Uri.parse('${baseUrl.replaceFirst(RegExp(r"/+$"), "")}/api/sell'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body:
            '{"seller": "home_mid", "buyer": "home_right", "amountKw": $amountKw}',
      );
    } catch (_) {
      // Silently ignore send failures.
    }
  }
}

final sellListingControllerProvider =
    StateNotifierProvider<SellListingController, AsyncValue<EnergyListing?>>((
      ref,
    ) {
      return SellListingController(ref);
    });

class SellListingController extends StateNotifier<AsyncValue<EnergyListing?>> {
  SellListingController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<EnergyListing?> publish({
    required SellListingDraft draft,
    required double maxAvailableKwh,
  }) async {
    state = const AsyncValue.loading();
    try {
      final permissions = _ref.read(marketplacePermissionsProvider);
      final listing = await _ref
          .read(marketplaceRepositoryProvider)
          .createListing(
            draft: draft,
            canSell: permissions.canSell,
            maxAvailableKwh: maxAvailableKwh,
          );
      _ref.invalidate(marketplaceListingsProvider);
      _ref.invalidate(myListingsProvider);
      if (mounted) {
        state = AsyncValue.data(listing);
      }
      _sendSpeechHomeMid(listing.pricePerKwh);
      return listing;
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
      return null;
    }
  }

  /// Sends speech home-mid event when a producer lists energy for sale.
  void _sendSpeechHomeMid(double price) {
    unawaited(_postSpeechHomeMid(price));
  }

  Future<void> _postSpeechHomeMid(double price) async {
    final baseUrl = _ref.read(appConfigProvider).eventServerUrl;
    if (baseUrl.isEmpty) return;
    try {
      await _ref
          .read(marketplaceEventClientProvider)
          .post(
            Uri.parse(
              '${baseUrl.replaceFirst(RegExp(r"/+$"), "")}/api/speech/home_mid',
            ),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: '{"price": $price}',
          );
    } catch (_) {
      // Silently ignore send failures.
    }
  }
}
