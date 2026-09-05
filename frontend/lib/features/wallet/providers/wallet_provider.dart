import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../../marketplace/domain/energy_listing.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../escrow/domain/escrow_settlement.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/wallet_api_repository.dart';
import '../data/wallet_mock_repository.dart';
import '../domain/wallet.dart';
import '../domain/wallet_summary.dart';
import '../domain/wallet_transaction.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return WalletApiRepository(ref.watch(apiClientProvider));
  }
  return WalletMockRepository();
});

final walletRoleProvider = FutureProvider<UserRole>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?.role ?? UserRole.consumer;
});

class WalletState {
  const WalletState({
    required this.wallet,
    required this.transactions,
    required this.summary,
  });

  final Wallet wallet;
  final List<WalletTransaction> transactions;
  final WalletSummary summary;
}

final walletControllerProvider =
    StateNotifierProvider<WalletController, AsyncValue<WalletState>>((ref) {
      return WalletController(ref)..load();
    });

class WalletController extends StateNotifier<AsyncValue<WalletState>> {
  WalletController(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _readState());
    } catch (error, stackTrace) {
      state = AsyncValue.error(_friendly(error), stackTrace);
    }
  }

  Future<void> refresh() async {
    try {
      state = AsyncValue.data(await _readState());
    } catch (error, stackTrace) {
      state = AsyncValue.error(_friendly(error), stackTrace);
    }
  }

  Future<WalletTransaction> recordPurchase({
    required EnergyPurchase purchase,
    required EnergyListing listing,
    String? escrowId,
  }) async {
    try {
      final role = await _ref.read(walletRoleProvider.future);
      final transaction = await _ref
          .read(walletRepositoryProvider)
          .recordPurchase(
            purchase: purchase,
            listing: listing,
            role: role,
            escrowId: escrowId,
          );
      await refresh();
      return transaction;
    } catch (error) {
      throw _friendly(error);
    }
  }

  Future<void> applyEscrowSettlement(EscrowSettlementResult result) async {
    await _ref
        .read(walletRepositoryProvider)
        .applyEscrowSettlement(
          escrowId: result.escrow.id,
          idempotencyKey: result.idempotencyKey,
          buyerRefundPaise: result.buyerRefundPaise,
          sellerReleasePaise: result.sellerReleasePaise,
          platformFeeRetainedPaise: result.platformFeeRetainedPaise,
          frozenPaise: result.frozenPaise,
        );
    await refresh();
  }

  Future<void> recordSale({
    required EnergyListing listing,
    required double quantityKwh,
  }) async {
    try {
      await _ref
          .read(walletRepositoryProvider)
          .recordSale(listing: listing, quantityKwh: quantityKwh);
      await refresh();
    } catch (error) {
      throw _friendly(error);
    }
  }

  Future<void> settlePendingSales() async {
    await _ref.read(walletRepositoryProvider).settlePendingSales();
    await refresh();
  }

  Future<WalletState> _readState() async {
    final repository = _ref.read(walletRepositoryProvider);
    final wallet = await repository.loadWallet();
    final transactions = await repository.transactions(
      const TransactionHistoryQuery(),
    );
    return WalletState(
      wallet: wallet,
      transactions: transactions,
      summary: repository.summary(),
    );
  }

  WalletException _friendly(Object error) {
    if (error is WalletException) {
      return error;
    }
    return const WalletException('Wallet action failed. Please try again.');
  }
}
