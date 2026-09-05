import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/domain/energy_listing.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/energy_delivery_verification_service.dart';
import '../data/escrow_api_repository.dart';
import '../data/escrow_mock_repository.dart';
import '../domain/delivery_verification.dart';
import '../domain/escrow_agreement.dart';
import '../domain/escrow_dispute.dart';
import '../domain/escrow_settlement.dart';
import '../domain/trade_default_case.dart';
import '../services/escrow_funding_service.dart';
import '../services/escrow_reconciliation_service.dart';

final escrowRepositoryProvider = Provider<EscrowRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return EscrowApiRepository(ref.watch(apiClientProvider));
  }
  return EscrowMockRepository();
});

final deliveryVerificationServiceProvider =
    Provider<EnergyDeliveryVerificationService>((ref) {
      return const MockEnergyDeliveryVerificationService();
    });

final escrowFundingServiceProvider = Provider<EscrowFundingService>((ref) {
  return const EscrowFundingService();
});

final escrowReconciliationServiceProvider =
    Provider<EscrowReconciliationService>((ref) {
      return EscrowReconciliationService(ref.watch(escrowRepositoryProvider));
    });

final escrowListProvider = FutureProvider<List<EscrowAgreement>>((ref) {
  return ref.watch(escrowRepositoryProvider).escrows();
});

final escrowDetailsProvider = FutureProvider.autoDispose
    .family<EscrowAgreement, String>((ref, id) {
      return ref.watch(escrowRepositoryProvider).escrowById(id);
    });

final escrowForPurchaseProvider = FutureProvider.autoDispose
    .family<EscrowAgreement?, String>((ref, purchaseId) {
      return ref.watch(escrowRepositoryProvider).escrowForPurchase(purchaseId);
    });

final defaultCaseProvider = FutureProvider.autoDispose
    .family<TradeDefaultCase, String>((ref, id) {
      return ref.watch(escrowRepositoryProvider).defaultCaseById(id);
    });

final escrowControllerProvider =
    StateNotifierProvider<
      EscrowController,
      AsyncValue<EscrowSettlementResult?>
    >((ref) => EscrowController(ref));

class EscrowController
    extends StateNotifier<AsyncValue<EscrowSettlementResult?>> {
  EscrowController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<EscrowAgreement> createForPurchase({
    required EnergyPurchase purchase,
    required EnergyListing listing,
  }) async {
    if (_ref.read(appConfigProvider).isLiveMode) {
      // In live mode, the backend creates escrow atomically during purchase.
      // Fetch the escrow associated with this purchase.
      final escrow = await _ref
          .read(escrowRepositoryProvider)
          .escrowForPurchase(purchase.id);
      if (escrow != null) {
        return escrow;
      }
    }
    // In mock mode, create escrow locally
    final wallet = await _ref.read(walletRepositoryProvider).loadWallet();
    _ref
        .read(escrowFundingServiceProvider)
        .validateFunding(wallet: wallet, purchase: purchase);
    final escrow = await _ref
        .read(escrowRepositoryProvider)
        .createFundedEscrow(purchase: purchase, listing: listing);
    _ref.invalidate(escrowListProvider);
    return escrow;
  }

  Future<void> refresh() async {
    _ref.invalidate(escrowListProvider);
    _ref.invalidate(escrowDetailsProvider);
  }

  Future<EscrowSettlementResult?> cancelByBuyer(String escrowId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref
          .read(escrowRepositoryProvider)
          .cancelByBuyer(
            escrowId: escrowId,
            idempotencyKey: 'cancel-$escrowId',
          );
      await _ref
          .read(walletControllerProvider.notifier)
          .applyEscrowSettlement(result);
      _ref.invalidate(escrowDetailsProvider(escrowId));
      state = AsyncValue.data(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<List<String>> recover() async {
    final notes = await _ref
        .read(escrowReconciliationServiceProvider)
        .recoverInterruptedOperations();
    _ref.invalidate(escrowListProvider);
    return notes;
  }

  Future<EscrowSettlementResult?> verifyAndSettle({
    required String escrowId,
    required double deliveredKwh,
    required bool integrityOk,
    String meterIdentifier = 'MTR-DEMO-001',
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(escrowRepositoryProvider);
      final escrow = await repository.escrowById(escrowId);
      final verification = _ref
          .read(deliveryVerificationServiceProvider)
          .verify(
            DeliveryVerificationInput(
              escrow: escrow,
              simulatedMeterReadingKwh: deliveredKwh,
              deliveryStart: escrow.fundedAt ?? escrow.createdAt,
              deliveryEnd: DateTime.now(),
              meterIdentifier: meterIdentifier,
              integrityOk: integrityOk,
            ),
          );
      final idempotencyKey =
          '${escrow.id}-${verification.deliveredEnergyKwh}-${verification.verificationStatus.name}';
      final result = repository is EscrowApiRepository
          ? await repository.settleAsync(
              escrow: escrow,
              verification: verification,
              idempotencyKey: idempotencyKey,
            )
          : repository.settle(
              escrow: escrow,
              verification: verification,
              idempotencyKey: idempotencyKey,
            );
      await _ref
          .read(walletControllerProvider.notifier)
          .applyEscrowSettlement(result);
      _ref.invalidate(escrowListProvider);
      _ref.invalidate(escrowDetailsProvider(escrowId));
      state = AsyncValue.data(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<EscrowDispute?> raiseDispute({
    required String escrowId,
    required String raisedBy,
    required String category,
    required String description,
  }) async {
    try {
      final dispute = await _ref
          .read(escrowRepositoryProvider)
          .raiseDispute(
            escrowId: escrowId,
            raisedBy: raisedBy,
            category: category,
            description: description,
          );
      _ref.invalidate(escrowDetailsProvider(escrowId));
      return dispute;
    } catch (_) {
      return null;
    }
  }
}
