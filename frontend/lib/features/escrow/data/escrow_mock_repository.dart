// ignore_for_file: annotate_overrides

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../marketplace/domain/energy_listing.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../wallet/domain/wallet.dart';
import '../domain/delivery_verification.dart';
import '../domain/escrow_agreement.dart';
import '../domain/escrow_audit_event.dart';
import '../domain/escrow_dispute.dart';
import '../domain/escrow_operation_record.dart';
import '../domain/escrow_settlement.dart';
import '../domain/trade_default_case.dart';
import '../services/escrow_state_machine.dart';

abstract class EscrowRepository {
  Future<EscrowAgreement> createFundedEscrow({
    required EnergyPurchase purchase,
    required EnergyListing listing,
  });
  Future<List<EscrowAgreement>> escrows();
  Future<EscrowAgreement> escrowById(String id);
  Future<EscrowAgreement?> escrowForPurchase(String purchaseId);
  Future<List<TradeDefaultCase>> defaultCases();
  Future<TradeDefaultCase> defaultCaseById(String id);
  Future<List<EscrowDispute>> disputes();
  Future<List<EscrowAuditEvent>> auditEvents(String escrowId);
  Future<List<EscrowOperationRecord>> operationRecords();
  Future<EscrowDispute> raiseDispute({
    required String escrowId,
    required String raisedBy,
    required String category,
    required String description,
  });
  EscrowSettlementResult settle({
    required EscrowAgreement escrow,
    required DeliveryVerificationResult verification,
    required String idempotencyKey,
  });
  Future<EscrowSettlementResult> cancelByBuyer({
    required String escrowId,
    required String idempotencyKey,
  });
  Future<EscrowAgreement> simulateCrash({
    required String escrowId,
    required EscrowCrashScenario scenario,
  });
  Future<List<String>> reconcile();
  bool validateMoneyConservation(EscrowSettlementResult result);
  bool verifyHash(EscrowAgreement escrow);
}

class EscrowMockRepository implements EscrowRepository {
  EscrowMockRepository({DateTime? now, EscrowStateMachine? stateMachine})
    : _now = now ?? DateTime.now(),
      _stateMachine = stateMachine ?? const EscrowStateMachine();

  final DateTime _now;
  final EscrowStateMachine _stateMachine;
  final List<EscrowAgreement> _escrows = [];
  final List<TradeDefaultCase> _defaults = [];
  final List<EscrowDispute> _disputes = [];
  final List<EscrowAuditEvent> _auditEvents = [];
  final List<EscrowOperationRecord> _operations = [];
  final Map<String, EscrowSettlementResult> _settlementsByKey = {};

  Future<EscrowAgreement> createFundedEscrow({
    required EnergyPurchase purchase,
    required EnergyListing listing,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final id = 'ESC-${_escrows.length + 1001}';
    final amountHeld = rupeesToPaise(purchase.quantityKwh * purchase.unitPrice);
    final fee = rupeesToPaise(purchase.platformFee);
    final escrow = _withHash(
      EscrowAgreement(
        id: id,
        purchaseId: purchase.id,
        listingId: listing.id,
        buyerId: purchase.buyerId,
        sellerId: listing.sellerId,
        energyQuantityKwh: purchase.quantityKwh,
        amountHeldPaise: amountHeld,
        platformFeePaise: fee,
        totalHeldPaise: amountHeld + fee,
        deliveredEnergyKwh: 0,
        status: EscrowStatus.energyDeliveryPending,
        createdAt: purchase.purchasedAt,
        fundedAt: purchase.purchasedAt,
        deliveryDeadline: purchase.purchasedAt.add(const Duration(hours: 4)),
        integrityHash: '',
        version: 1,
      ),
    );
    _escrows.add(escrow);
    _audit(escrow.id, 'escrow_created', 'Simulated escrow created and funded');
    _audit(
      escrow.id,
      'funds_reserved',
      'Buyer funds reserved in escrow-held balance',
    );
    return escrow;
  }

  Future<List<EscrowAgreement>> escrows() async => List.unmodifiable(_escrows);

  Future<EscrowAgreement> escrowById(String id) async {
    return _escrows.firstWhere(
      (item) => item.id == id,
      orElse: () => throw const EscrowException('Escrow not found.'),
    );
  }

  Future<EscrowAgreement?> escrowForPurchase(String purchaseId) async {
    for (final escrow in _escrows) {
      if (escrow.purchaseId == purchaseId) {
        return escrow;
      }
    }
    return null;
  }

  Future<List<TradeDefaultCase>> defaultCases() async {
    return List.unmodifiable(_defaults);
  }

  Future<TradeDefaultCase> defaultCaseById(String id) async {
    return _defaults.firstWhere(
      (item) => item.id == id,
      orElse: () => throw const EscrowException('Default case not found.'),
    );
  }

  Future<List<EscrowDispute>> disputes() async => List.unmodifiable(_disputes);

  Future<List<EscrowAuditEvent>> auditEvents(String escrowId) async {
    return _auditEvents.where((item) => item.escrowId == escrowId).toList();
  }

  Future<List<EscrowOperationRecord>> operationRecords() async {
    return List.unmodifiable(_operations);
  }

  Future<EscrowDispute> raiseDispute({
    required String escrowId,
    required String raisedBy,
    required String category,
    required String description,
  }) async {
    final escrow = await escrowById(escrowId);
    final dispute = EscrowDispute(
      id: 'DSP-${_disputes.length + 701}',
      escrowId: escrowId,
      raisedBy: raisedBy,
      category: category,
      description: description,
      status: DisputeStatus.underReview,
      evidence: ['${escrow.id}-meter-reading', '${escrow.id}-ledger-event'],
      createdAt: _now,
      updatedAt: _now,
      resolution:
          'Mock review pending. No human arbitrator has reviewed this case.',
    );
    _disputes.add(dispute);
    _replaceEscrow(
      _withHash(
        escrow.copyWith(
          status: EscrowStatus.disputed,
          disputedAt: _now,
          version: escrow.version + 1,
        ),
      ),
    );
    _audit(escrowId, 'dispute_raised', 'Simulated dispute raised');
    return dispute;
  }

  EscrowSettlementResult settle({
    required EscrowAgreement escrow,
    required DeliveryVerificationResult verification,
    required String idempotencyKey,
  }) {
    final existing = _settlementsByKey[idempotencyKey];
    if (existing != null) {
      _audit(
        escrow.id,
        'duplicate_settlement_attempt',
        'Duplicate settlement ignored',
      );
      return existing;
    }
    _operation(
      escrowId: escrow.id,
      transactionId: escrow.purchaseId,
      idempotencyKey: idempotencyKey,
      type: EscrowOperationType.settlement,
      status: EscrowOperationStatus.started,
      note: 'Settlement started',
    );
    if (escrow.status == EscrowStatus.released ||
        escrow.status == EscrowStatus.refunded ||
        escrow.status == EscrowStatus.frozen) {
      throw const EscrowException('Cannot settle a terminal escrow state.');
    }

    final blocked =
        verification.tamperingDetected ||
        !verification.meterMatched ||
        !verification.withinDeliveryWindow;
    if (blocked) {
      final reason = verification.tamperingDetected
          ? DefaultReason.suspectedTampering
          : verification.meterMatched
          ? DefaultReason.deliveryTimeout
          : DefaultReason.meterMismatch;
      _stateMachine.validate(escrow.status, EscrowStatus.frozen);
      final updated = _withHash(
        escrow.copyWith(
          status: EscrowStatus.frozen,
          deliveredEnergyKwh: verification.deliveredEnergyKwh,
          failureReason: reason.label,
          disputedAt: _now,
          version: escrow.version + 1,
        ),
      );
      _replaceEscrow(updated);
      _audit(escrow.id, 'funds_frozen', 'Escrow frozen for ${reason.label}');
      final defaultCase = _defaultCase(
        escrow: updated,
        reason: reason,
        resolution: DefaultResolution.manualReview,
        financialImpactPaise: escrow.totalHeldPaise,
        delivered: verification.deliveredEnergyKwh,
        status: DefaultCaseStatus.fundsFrozen,
        notes: 'Automatic settlement blocked by delivery verification.',
      );
      final result = EscrowSettlementResult(
        escrow: updated,
        sellerReleasePaise: 0,
        buyerRefundPaise: 0,
        platformFeeRetainedPaise: 0,
        frozenPaise: escrow.totalHeldPaise,
        idempotencyKey: idempotencyKey,
        defaultCase: defaultCase,
      );
      _settlementsByKey[idempotencyKey] = result;
      return result;
    }

    final ratio = (verification.deliveredEnergyKwh / escrow.energyQuantityKwh)
        .clamp(0, 1);
    final acceptedRatio = ratio >= 0.98
        ? 1.0
        : ratio >= 0.5
        ? ratio.toDouble()
        : 0.0;
    final sellerGross = (escrow.amountHeldPaise * acceptedRatio).round();
    final feeRetained = (escrow.platformFeePaise * acceptedRatio).round();
    final buyerRefund = escrow.amountHeldPaise - sellerGross;
    final sellerRelease = (sellerGross - feeRetained).clamp(
      0,
      escrow.totalHeldPaise,
    );
    final platformFee = feeRetained.clamp(0, escrow.platformFeePaise);
    final frozen =
        (escrow.totalHeldPaise - sellerRelease - buyerRefund - platformFee)
            .clamp(0, escrow.totalHeldPaise);
    final status = acceptedRatio >= 1
        ? EscrowStatus.released
        : acceptedRatio >= 0.5
        ? EscrowStatus.deliveryPartiallyConfirmed
        : EscrowStatus.refunded;
    final intermediate = acceptedRatio >= 1
        ? EscrowStatus.deliveryConfirmed
        : acceptedRatio >= 0.5
        ? EscrowStatus.deliveryPartiallyConfirmed
        : EscrowStatus.refundPending;
    _stateMachine.validate(escrow.status, intermediate);
    if (status == EscrowStatus.released) {
      _stateMachine.validate(intermediate, EscrowStatus.releasePending);
      _stateMachine.validate(
        EscrowStatus.releasePending,
        EscrowStatus.released,
      );
    } else if (status == EscrowStatus.refunded) {
      _stateMachine.validate(intermediate, EscrowStatus.refunded);
    }
    final updated = _withHash(
      escrow.copyWith(
        status: status,
        deliveredEnergyKwh: verification.deliveredEnergyKwh,
        completedAt: _now,
        releasedAt: sellerRelease > 0 ? _now : null,
        refundedAt: buyerRefund > 0 ? _now : null,
        version: escrow.version + 1,
      ),
    );
    _replaceEscrow(updated);
    _audit(
      escrow.id,
      'meter_verification_received',
      'Mock meter verification received',
    );
    _audit(escrow.id, 'settlement_calculated', 'Escrow settlement calculated');
    if (sellerRelease > 0) {
      _audit(escrow.id, 'funds_released', 'Seller funds released');
    }
    if (buyerRefund > 0) {
      _audit(escrow.id, 'buyer_refunded', 'Buyer refund recorded');
    }
    TradeDefaultCase? defaultCase;
    if (acceptedRatio < 0.98) {
      defaultCase = _defaultCase(
        escrow: updated,
        reason: acceptedRatio >= 0.5
            ? DefaultReason.partialDelivery
            : DefaultReason.sellerNonDelivery,
        resolution: acceptedRatio >= 0.5
            ? DefaultResolution.proportionalRelease
            : DefaultResolution.fullRefundToBuyer,
        financialImpactPaise: buyerRefund,
        delivered: verification.deliveredEnergyKwh,
        status: DefaultCaseStatus.resolved,
        notes: 'Deterministic mock policy applied.',
      );
    }
    final result = EscrowSettlementResult(
      escrow: updated,
      sellerReleasePaise: sellerRelease.toInt(),
      buyerRefundPaise: buyerRefund,
      platformFeeRetainedPaise: platformFee.toInt(),
      frozenPaise: frozen.toInt(),
      idempotencyKey: idempotencyKey,
      defaultCase: defaultCase,
    );
    _settlementsByKey[idempotencyKey] = result;
    _operation(
      escrowId: escrow.id,
      transactionId: escrow.purchaseId,
      idempotencyKey: idempotencyKey,
      type: EscrowOperationType.settlement,
      status: EscrowOperationStatus.completed,
      note: 'Settlement completed',
      completedAt: _now,
    );
    return result;
  }

  Future<EscrowSettlementResult> cancelByBuyer({
    required String escrowId,
    required String idempotencyKey,
  }) async {
    final escrow = await escrowById(escrowId);
    if (_settlementsByKey.containsKey(idempotencyKey)) {
      return _settlementsByKey[idempotencyKey]!;
    }
    _stateMachine.validate(escrow.status, EscrowStatus.cancelled);
    _stateMachine.validate(EscrowStatus.cancelled, EscrowStatus.refundPending);
    final updated = _withHash(
      escrow.copyWith(
        status: EscrowStatus.refunded,
        refundedAt: _now,
        failureReason: DefaultReason.buyerCancellation.label,
        version: escrow.version + 1,
      ),
    );
    _replaceEscrow(updated);
    final defaultCase = _defaultCase(
      escrow: updated,
      reason: DefaultReason.buyerCancellation,
      resolution: DefaultResolution.fullRefundToBuyer,
      financialImpactPaise: escrow.totalHeldPaise,
      delivered: 0,
      status: DefaultCaseStatus.resolved,
      notes: 'Buyer cancellation before verified delivery. Full mock refund.',
    );
    _audit(escrow.id, 'buyer_refunded', 'Buyer cancellation refund recorded');
    final result = EscrowSettlementResult(
      escrow: updated,
      sellerReleasePaise: 0,
      buyerRefundPaise: escrow.amountHeldPaise,
      platformFeeRetainedPaise: 0,
      frozenPaise: escrow.platformFeePaise,
      idempotencyKey: idempotencyKey,
      defaultCase: defaultCase,
    );
    _settlementsByKey[idempotencyKey] = result;
    return result;
  }

  Future<EscrowAgreement> simulateCrash({
    required String escrowId,
    required EscrowCrashScenario scenario,
  }) async {
    final escrow = await escrowById(escrowId);
    final status = switch (scenario) {
      EscrowCrashScenario.afterFundsReserved => EscrowStatus.funded,
      EscrowCrashScenario.afterSellerCredit => EscrowStatus.frozen,
    };
    final updated = _withHash(
      escrow.copyWith(
        status: status,
        failureReason: scenario.name,
        version: escrow.version + 1,
      ),
    );
    _replaceEscrow(updated);
    _operation(
      escrowId: escrow.id,
      transactionId: escrow.purchaseId,
      idempotencyKey: 'crash-${escrow.id}-${scenario.name}',
      type: scenario == EscrowCrashScenario.afterFundsReserved
          ? EscrowOperationType.funding
          : EscrowOperationType.settlement,
      status: EscrowOperationStatus.interrupted,
      note: scenario.name,
    );
    _audit(escrow.id, 'system_failure', 'Crash simulation: ${scenario.name}');
    return updated;
  }

  Future<List<String>> reconcile() async {
    final notes = <String>[];
    for (var index = 0; index < _operations.length; index++) {
      final operation = _operations[index];
      if (operation.status == EscrowOperationStatus.interrupted) {
        _operations[index] = operation.copyWith(
          status: EscrowOperationStatus.reviewRequired,
          note: 'Marked for safe mock recovery review',
        );
        notes.add(
          '${operation.escrowId}: interrupted ${operation.type.label} marked for review',
        );
        _audit(
          operation.escrowId,
          'reconciliation_review',
          'Interrupted operation detected',
        );
      }
    }
    for (final escrow in _escrows) {
      if (escrow.status == EscrowStatus.awaitingFunding &&
          escrow.createdAt.isBefore(
            _now.subtract(const Duration(minutes: 5)),
          )) {
        notes.add('${escrow.id}: funding incomplete, marked for review');
        _audit(
          escrow.id,
          'reconciliation_review',
          'Incomplete funding detected',
        );
      }
    }
    return notes;
  }

  bool validateMoneyConservation(EscrowSettlementResult result) {
    return result.conservesMoney &&
        result.sellerReleasePaise >= 0 &&
        result.buyerRefundPaise >= 0 &&
        result.platformFeeRetainedPaise >= 0 &&
        result.frozenPaise >= 0;
  }

  bool verifyHash(EscrowAgreement escrow) {
    return escrow.integrityHash == _hashFor(escrow);
  }

  EscrowAgreement _withHash(EscrowAgreement escrow) {
    return escrow.copyWith(integrityHash: _hashFor(escrow));
  }

  String _hashFor(EscrowAgreement escrow) {
    final canonical = jsonEncode({
      'id': escrow.id,
      'purchaseId': escrow.purchaseId,
      'listingId': escrow.listingId,
      'buyerId': escrow.buyerId,
      'sellerId': escrow.sellerId,
      'energy': escrow.energyQuantityKwh,
      'amount': escrow.amountHeldPaise,
      'fee': escrow.platformFeePaise,
      'total': escrow.totalHeldPaise,
      'delivered': escrow.deliveredEnergyKwh,
      'status': escrow.status.name,
      'version': escrow.version,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  void _replaceEscrow(EscrowAgreement escrow) {
    for (var index = 0; index < _escrows.length; index++) {
      if (_escrows[index].id == escrow.id) {
        _escrows[index] = escrow;
        return;
      }
    }
    _escrows.add(escrow);
  }

  TradeDefaultCase _defaultCase({
    required EscrowAgreement escrow,
    required DefaultReason reason,
    required DefaultResolution resolution,
    required int financialImpactPaise,
    required double delivered,
    required DefaultCaseStatus status,
    required String notes,
  }) {
    final existing = _defaults.where(
      (item) => item.escrowId == escrow.id && item.reason == reason,
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final item = TradeDefaultCase(
      id: 'DEF-${_defaults.length + 601}',
      escrowId: escrow.id,
      defaultingParty: reason == DefaultReason.buyerCancellation
          ? escrow.buyerId
          : escrow.sellerId,
      reason: reason,
      expectedEnergyKwh: escrow.energyQuantityKwh,
      deliveredEnergyKwh: delivered,
      financialImpactPaise: financialImpactPaise,
      resolution: resolution,
      status: status,
      createdAt: _now,
      resolvedAt: status == DefaultCaseStatus.resolved ? _now : null,
      evidenceReferences: ['${escrow.id}-verification', '${escrow.id}-audit'],
      notes: notes,
    );
    _defaults.add(item);
    _audit(escrow.id, 'default_detected', reason.label);
    return item;
  }

  void _audit(String escrowId, String type, String description) {
    final key = '$escrowId-$type-${_auditEvents.length + 1}';
    final hash = sha256.convert(utf8.encode('$key|$description')).toString();
    _auditEvents.add(
      EscrowAuditEvent(
        id: 'AUD-${_auditEvents.length + 1}',
        escrowId: escrowId,
        type: type,
        description: description,
        integrityHash: hash,
        createdAt: _now,
        idempotencyKey: key,
      ),
    );
  }

  void _operation({
    required String escrowId,
    required String transactionId,
    required String idempotencyKey,
    required EscrowOperationType type,
    required EscrowOperationStatus status,
    String? note,
    DateTime? completedAt,
  }) {
    _operations.add(
      EscrowOperationRecord(
        id: 'OP-${_operations.length + 1}',
        escrowId: escrowId,
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        type: type,
        status: status,
        createdAt: _now,
        completedAt: completedAt,
        note: note,
      ),
    );
  }
}

class EscrowException implements Exception {
  const EscrowException(this.message);
  final String message;
  @override
  String toString() => message;
}
