import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/voltshare_ui.dart';
import '../../marketplace/data/marketplace_mock_repository.dart';
import '../../marketplace/data/mock_backend_store.dart';
import '../../wallet/domain/wallet.dart';
import '../data/energy_delivery_verification_service.dart';
import '../domain/delivery_verification.dart';
import '../domain/escrow_agreement.dart';
import '../domain/escrow_operation_record.dart';
import '../providers/escrow_provider.dart';

class EscrowDebugPanelScreen extends ConsumerStatefulWidget {
  const EscrowDebugPanelScreen({super.key});

  @override
  ConsumerState<EscrowDebugPanelScreen> createState() =>
      _EscrowDebugPanelScreenState();
}

class _EscrowDebugPanelScreenState
    extends ConsumerState<EscrowDebugPanelScreen> {
  String _log = 'Choose a mock scenario.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Escrow test panel',
              subtitle: 'Debug-only simulated scenarios',
              fallbackRoute: '/wallet',
            ),
            const SizedBox(height: 12),
            const Text(
              'Demo controls only. No real escrow, banking, settlement, or meter verification is performed.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _button(
                  'Successful delivery',
                  () => _settle(1, true, 'MTR-DEMO-001'),
                ),
                _button(
                  'Partial delivery',
                  () => _settle(0.7, true, 'MTR-DEMO-001'),
                ),
                _button(
                  'Seller default',
                  () => _settle(0.2, true, 'MTR-DEMO-001'),
                ),
                _button('Buyer cancellation', _cancel),
                _button('Meter mismatch', () => _settle(1, true, 'BAD-METER')),
                _button('Tampering', () => _settle(1, false, 'MTR-DEMO-001')),
                _button(
                  'Timeout',
                  () => _settle(1, true, 'MTR-DEMO-001', timeout: true),
                ),
                _button('Duplicate settlement', _duplicate),
                _button(
                  'Crash after funds reserved',
                  () => _crash(EscrowCrashScenario.afterFundsReserved),
                ),
                _button(
                  'Crash after seller credit',
                  () => _crash(EscrowCrashScenario.afterSellerCredit),
                ),
                _button('Recovery', _recover),
                _button('Integrity verification', _integrity),
                _button('Money conservation', _money),
              ],
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_log),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, Future<void> Function() action) {
    return OutlinedButton(onPressed: action, child: Text(label));
  }

  Future<void> _settle(
    double delivered,
    bool integrityOk,
    String meter, {
    bool timeout = false,
  }) async {
    final escrow = await _demoEscrow();
    final input = DeliveryVerificationInput(
      escrow: escrow,
      simulatedMeterReadingKwh: delivered,
      deliveryStart: escrow.createdAt,
      deliveryEnd: timeout
          ? escrow.deliveryDeadline.add(const Duration(hours: 2))
          : escrow.createdAt.add(const Duration(hours: 1)),
      meterIdentifier: meter,
      integrityOk: integrityOk,
    );
    final verification = const MockEnergyDeliveryVerificationService().verify(
      input,
    );
    final result = ref
        .read(escrowRepositoryProvider)
        .settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey:
              'debug-${escrow.id}-$delivered-$integrityOk-$meter-$timeout',
        );
    setState(() {
      _log =
          '${result.escrow.status.label}\nSeller: ${formatPaise(result.sellerReleasePaise)}\nRefund: ${formatPaise(result.buyerRefundPaise)}\nFrozen: ${formatPaise(result.frozenPaise)}';
    });
  }

  Future<void> _cancel() async {
    final escrow = await _demoEscrow();
    final result = await ref
        .read(escrowRepositoryProvider)
        .cancelByBuyer(
          escrowId: escrow.id,
          idempotencyKey: 'debug-cancel-${escrow.id}',
        );
    setState(() => _log = 'Buyer cancellation: ${result.escrow.status.label}');
  }

  Future<void> _duplicate() async {
    final escrow = await _demoEscrow();
    final verification = const MockEnergyDeliveryVerificationService().verify(
      DeliveryVerificationInput(
        escrow: escrow,
        simulatedMeterReadingKwh: 1,
        deliveryStart: escrow.createdAt,
        deliveryEnd: escrow.createdAt.add(const Duration(hours: 1)),
        meterIdentifier: 'MTR-DEMO-001',
        integrityOk: true,
      ),
    );
    final first = ref
        .read(escrowRepositoryProvider)
        .settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'debug-duplicate-${escrow.id}',
        );
    final second = ref
        .read(escrowRepositoryProvider)
        .settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'debug-duplicate-${escrow.id}',
        );
    setState(
      () => _log =
          'Duplicate prevented: ${identical(first, second) || first.sellerReleasePaise == second.sellerReleasePaise}',
    );
  }

  Future<void> _crash(EscrowCrashScenario scenario) async {
    final escrow = await _demoEscrow();
    await ref
        .read(escrowRepositoryProvider)
        .simulateCrash(escrowId: escrow.id, scenario: scenario);
    setState(() => _log = 'Crash simulated: ${scenario.name}');
  }

  Future<void> _recover() async {
    final notes = await ref.read(escrowControllerProvider.notifier).recover();
    setState(
      () => _log = notes.isEmpty ? 'No recovery work found.' : notes.join('\n'),
    );
  }

  Future<void> _integrity() async {
    final escrow = await _demoEscrow();
    final ok = ref.read(escrowRepositoryProvider).verifyHash(escrow);
    setState(() => _log = 'Integrity verification: $ok');
  }

  Future<void> _money() async {
    final escrow = await _demoEscrow();
    final verification = const MockEnergyDeliveryVerificationService().verify(
      DeliveryVerificationInput(
        escrow: escrow,
        simulatedMeterReadingKwh: 0.7,
        deliveryStart: escrow.createdAt,
        deliveryEnd: escrow.createdAt.add(const Duration(hours: 1)),
        meterIdentifier: 'MTR-DEMO-001',
        integrityOk: true,
      ),
    );
    final result = ref
        .read(escrowRepositoryProvider)
        .settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'debug-money-${escrow.id}',
        );
    setState(() => _log = 'Money conservation: ${result.conservesMoney}');
  }

  Future<EscrowAgreement> _demoEscrow() async {
    final repository = ref.read(escrowRepositoryProvider);
    final marketplace = MarketplaceMockRepository(
      currentUserId: 'test-buyer',
      currentUserRole: 'consumer',
      store: MockBackendStore.fresh(),
      now: DateTime(2026, 7, 18, 12),
    );
    final listing = await marketplace.listingById('ravi');
    final purchase = await marketplace.purchase(
      listingId: listing.id,
      buyerId: 'test-buyer',
      quantityKwh: 1,
      canBuy: true,
    );
    return repository.createFundedEscrow(purchase: purchase, listing: listing);
  }
}
