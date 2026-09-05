import '../../marketplace/domain/energy_listing.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../domain/delivery_verification.dart';
import '../domain/escrow_agreement.dart';
import '../domain/escrow_audit_event.dart';
import '../domain/escrow_dispute.dart';
import '../domain/escrow_operation_record.dart';
import '../domain/escrow_settlement.dart';
import '../domain/trade_default_case.dart';
import 'escrow_mock_repository.dart';

class EscrowApiRepository implements EscrowRepository {
  EscrowApiRepository(this._client, {IdempotencyKeyGenerator? keys})
    : _keys = keys ?? IdempotencyKeyGenerator();

  final ApiClient _client;
  final IdempotencyKeyGenerator _keys;

  @override
  Future<EscrowAgreement> createFundedEscrow({
    required EnergyPurchase purchase,
    required EnergyListing listing,
  }) async {
    // The backend creates the escrow atomically during purchase creation.
    // Fetch the escrow associated with this purchase from the backend.
    final data = await _client.get('/escrows') as List;
    for (final item in data) {
      final escrow = _escrow(item as Map);
      if (escrow.purchaseId == purchase.id) {
        return escrow;
      }
    }
    throw const EscrowException(
      'Backend did not create an escrow for this purchase.',
    );
  }

  @override
  Future<List<EscrowAgreement>> escrows() async {
    final data = await _client.get('/escrows') as List;
    return data.map((item) => _escrow(item as Map)).toList();
  }

  @override
  Future<EscrowAgreement> escrowById(String id) async {
    return _escrow(await _client.get('/escrows/$id') as Map);
  }

  @override
  Future<EscrowAgreement?> escrowForPurchase(String purchaseId) async {
    final items = await escrows();
    for (final item in items) {
      if (item.purchaseId == purchaseId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<TradeDefaultCase>> defaultCases() async => const [];

  @override
  Future<TradeDefaultCase> defaultCaseById(String id) {
    throw const EscrowException('Default case details are unavailable.');
  }

  @override
  Future<List<EscrowDispute>> disputes() async {
    final data = await _client.get('/disputes') as List;
    return data.map((item) => _dispute(item as Map)).toList();
  }

  @override
  Future<List<EscrowAuditEvent>> auditEvents(String escrowId) async => const [];

  @override
  Future<List<EscrowOperationRecord>> operationRecords() async => const [];

  @override
  Future<EscrowDispute> raiseDispute({
    required String escrowId,
    required String raisedBy,
    required String category,
    required String description,
  }) async {
    return _dispute(await _client.post(
      '/escrows/$escrowId/disputes',
      idempotencyKey: _keys.next('dispute'),
      body: {'category': category, 'description': description},
    ) as Map);
  }

  @override
  EscrowSettlementResult settle({
    required EscrowAgreement escrow,
    required DeliveryVerificationResult verification,
    required String idempotencyKey,
  }) {
    throw const EscrowException(
      'Use settleAsync for backend settlement operations.',
    );
  }

  Future<EscrowSettlementResult> settleAsync({
    required EscrowAgreement escrow,
    required DeliveryVerificationResult verification,
    required String idempotencyKey,
  }) async {
    return _settlement(await _client.post(
      '/escrows/${escrow.id}/settle',
      idempotencyKey: idempotencyKey,
      body: {
        'deliveredEnergyKwh': verification.deliveredEnergyKwh,
        'meterMatched': verification.meterMatched,
        'tamperingDetected': verification.tamperingDetected,
        'withinDeliveryWindow': verification.withinDeliveryWindow,
      },
    ) as Map);
  }

  @override
  Future<EscrowSettlementResult> cancelByBuyer({
    required String escrowId,
    required String idempotencyKey,
  }) async {
    return _settlement(await _client.post(
      '/escrows/$escrowId/cancel',
      idempotencyKey: idempotencyKey,
    ) as Map);
  }

  @override
  Future<EscrowAgreement> simulateCrash({
    required String escrowId,
    required EscrowCrashScenario scenario,
  }) {
    throw const EscrowException(
      'Crash simulation is available only in mock mode.',
    );
  }

  @override
  Future<List<String>> reconcile() async {
    final data = await _client.post(
      '/escrows/reconcile',
      idempotencyKey: _keys.next('reconcile'),
    ) as Map;
    return ((data['notes'] as List?) ?? []).map((item) => item.toString()).toList();
  }

  @override
  bool validateMoneyConservation(EscrowSettlementResult result) {
    return result.conservesMoney;
  }

  @override
  bool verifyHash(EscrowAgreement escrow) => escrow.integrityHash.isNotEmpty;
}

EscrowAgreement _escrow(Map data) {
  return EscrowAgreement(
    id: data['id'].toString(),
    purchaseId: data['purchaseId'].toString(),
    listingId: data['listingId'].toString(),
    buyerId: data['buyerId'].toString(),
    sellerId: data['sellerId'].toString(),
    energyQuantityKwh: (data['energyQuantityKwh'] as num).toDouble(),
    amountHeldPaise: (data['amountHeldPaise'] as num).toInt(),
    platformFeePaise: (data['platformFeePaise'] as num).toInt(),
    totalHeldPaise: (data['totalHeldPaise'] as num).toInt(),
    deliveredEnergyKwh: (data['deliveredEnergyKwh'] as num).toDouble(),
    status: EscrowStatus.values.byName(data['status'].toString()),
    createdAt: DateTime.parse(data['createdAt'].toString()),
    fundedAt: data['fundedAt'] == null ? null : DateTime.parse(data['fundedAt'].toString()),
    deliveryDeadline: DateTime.parse(data['deliveryDeadline'].toString()),
    completedAt: data['completedAt'] == null ? null : DateTime.parse(data['completedAt'].toString()),
    releasedAt: data['releasedAt'] == null ? null : DateTime.parse(data['releasedAt'].toString()),
    refundedAt: data['refundedAt'] == null ? null : DateTime.parse(data['refundedAt'].toString()),
    disputedAt: data['disputedAt'] == null ? null : DateTime.parse(data['disputedAt'].toString()),
    failureReason: data['failureReason']?.toString(),
    integrityHash: data['integrityHash'].toString(),
    version: (data['version'] as num).toInt(),
  );
}

EscrowSettlementResult _settlement(Map data) {
  return EscrowSettlementResult(
    escrow: _escrow(data['escrow'] as Map),
    sellerReleasePaise: (data['sellerReleasePaise'] as num).toInt(),
    buyerRefundPaise: (data['buyerRefundPaise'] as num).toInt(),
    platformFeeRetainedPaise: (data['platformFeeRetainedPaise'] as num).toInt(),
    frozenPaise: (data['frozenPaise'] as num).toInt(),
    idempotencyKey: data['idempotencyKey'].toString(),
  );
}

EscrowDispute _dispute(Map data) {
  return EscrowDispute(
    id: data['id'].toString(),
    escrowId: data['escrowId'].toString(),
    raisedBy: data['raisedBy'].toString(),
    category: data['category'].toString(),
    description: data['description'].toString(),
    status: DisputeStatus.underReview,
    evidence: const [],
    createdAt: DateTime.parse(data['createdAt'].toString()),
    updatedAt: DateTime.parse(data['createdAt'].toString()),
    resolution: 'Backend review pending.',
  );
}
