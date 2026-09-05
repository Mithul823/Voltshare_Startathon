import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../../escrow/providers/escrow_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/marketplace_api_repository.dart';
import '../data/marketplace_mock_api_repository.dart';
import '../data/marketplace_mock_repository.dart';
import '../domain/energy_listing.dart';
import '../domain/energy_purchase.dart';
import '../domain/sell_listing_draft.dart';

/// Resolves the current user ID from the authenticated session or profile.
/// In mock mode, still uses the real Supabase auth if available.
/// Falls back to a per-session mock user ID if no Supabase session exists.
String _currentUserId(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null) return profile.id;
  final session = ref.read(currentSessionProvider);
  if (session != null) return session.user.id;
  // If no Supabase session exists (mock mode without Supabase), use mock user
  return '';
}

String _currentUserRole(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null) return profile.role.value;
  return 'consumer';
}

String _currentUserName(Ref ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null) return profile.fullName;
  return 'Energy Seller';
}

/// In live mode, uses [MarketplaceApiRepository].
/// In mock mode, uses [MarketplaceMockRepository] with the real auth identity.
/// This ensures:
/// - Listings survive logout (stored in MockBackendStore singleton)
/// - sellerId/buyerId come from the authenticated user, not a hardcoded value
/// - Self-purchase is prevented in both modes
/// - Ownership is enforced in both modes
/// Watches auth state so the repository is rebuilt when user changes.
final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  // Watch auth state to rebuild when user logs in/out
  ref.watch(currentProfileProvider);
  if (ref.watch(appConfigProvider).isLiveMode) {
    return MarketplaceApiRepository(ref.watch(apiClientProvider));
  }
  // In mock mode, use the mock API repository that posts/gets listings
  // from the backend's /mock/listings endpoint (persisted as JSON file).
  return MarketplaceMockApiRepository(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
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
  return profile?.role ?? UserRole.consumer;
});

class MarketplacePermissions {
  const MarketplacePermissions({required this.canBuy, required this.canSell});

  final bool canBuy;
  final bool canSell;
}

final marketplacePermissionsProvider = Provider<MarketplacePermissions>((ref) {
  final role =
      ref.watch(marketplaceRoleProvider).valueOrNull ?? UserRole.consumer;
  return MarketplacePermissions(
    canBuy: role == UserRole.consumer || role == UserRole.prosumer,
    canSell: role == UserRole.producer || role == UserRole.prosumer,
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
    state = const AsyncValue.loading();
    try {
      final isMockMode = _ref.read(appConfigProvider).isMockMode;
      final permissions = _ref.read(marketplacePermissionsProvider);
      final buyerId = _currentUserId(_ref);
      final listing = await _ref
          .read(marketplaceRepositoryProvider)
          .listingById(listingId);

      // Fire speech bubble events with the actual price
      _sendSpeechHomeRight(listing.pricePerKwh);
      _sendSellEvent(listing.pricePerKwh, quantityKwh);

      // Call backend purchase endpoint - handles escrow, wallet debit, ledger atomically
      final purchase = await _ref
          .read(marketplaceRepositoryProvider)
          .purchase(
            listingId: listingId,
            buyerId: buyerId,
            quantityKwh: quantityKwh,
            canBuy: permissions.canBuy,
          );

      if (isMockMode) {
        // In mock mode, create escrow and record wallet transaction locally
        final escrow = await _ref
            .read(escrowControllerProvider.notifier)
            .createForPurchase(purchase: purchase, listing: listing);
        await _ref
            .read(walletControllerProvider.notifier)
            .recordPurchase(
              purchase: purchase,
              listing: listing,
              escrowId: escrow.id,
            );
      } else {
        // In live mode, the backend already created escrow and debited wallet.
        // Just refresh providers to reflect the new state.
        unawaited(_ref
            .read(walletControllerProvider.notifier)
            .refresh());
        unawaited(_ref.read(escrowControllerProvider.notifier).refresh());
      }

      _ref.read(latestPurchaseProvider.notifier).state = purchase;
      _ref.invalidate(marketplaceListingsProvider);
      _ref.invalidate(myListingsProvider);
      state = AsyncValue.data(purchase);
      return purchase;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  /// Sends speech home-right event when a consumer buys at a certain rate.
  void _sendSpeechHomeRight(double price) {
    unawaited(_postSpeechHomeRight(price));
  }

  Future<void> _postSpeechHomeRight(double price) async {
    try {
      await http.post(
        Uri.parse('https://bullpen-unsorted-clad.ngrok-free.dev/api/speech/home_right'),
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
  void _sendSellEvent(double price, double amountKw) {
    unawaited(_postSellEvent(price, amountKw));
  }

  Future<void> _postSellEvent(double price, double amountKw) async {
    try {
      await http.post(
        Uri.parse('https://bullpen-unsorted-clad.ngrok-free.dev/api/sell'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: '{"seller": "home_mid", "buyer": "home_right", "amountKw": $amountKw}',
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
      // Fire speech home-mid event for producer listing
      _sendSpeechHomeMid(draft.pricePerKwh);

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
      state = AsyncValue.data(listing);
      return listing;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  /// Sends speech home-mid event when a producer lists energy for sale.
  void _sendSpeechHomeMid(double price) {
    unawaited(_postSpeechHomeMid(price));
  }

  Future<void> _postSpeechHomeMid(double price) async {
    try {
      await http.post(
        Uri.parse('https://bullpen-unsorted-clad.ngrok-free.dev/api/speech/home_mid'),
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
