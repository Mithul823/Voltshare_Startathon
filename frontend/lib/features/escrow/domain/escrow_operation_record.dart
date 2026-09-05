enum EscrowOperationType {
  funding('Funding'),
  settlement('Settlement'),
  refund('Refund'),
  reconciliation('Reconciliation');

  const EscrowOperationType(this.label);
  final String label;
}

enum EscrowOperationStatus {
  started('Started'),
  walletMoved('Wallet moved'),
  escrowUpdated('Escrow updated'),
  completed('Completed'),
  interrupted('Interrupted'),
  reviewRequired('Review required');

  const EscrowOperationStatus(this.label);
  final String label;
}

enum EscrowCrashScenario { afterFundsReserved, afterSellerCredit }

class EscrowOperationRecord {
  const EscrowOperationRecord({
    required this.id,
    required this.escrowId,
    required this.transactionId,
    required this.idempotencyKey,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.note,
  });

  final String id;
  final String escrowId;
  final String transactionId;
  final String idempotencyKey;
  final EscrowOperationType type;
  final EscrowOperationStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? note;

  EscrowOperationRecord copyWith({
    EscrowOperationStatus? status,
    DateTime? completedAt,
    String? note,
  }) {
    return EscrowOperationRecord(
      id: id,
      escrowId: escrowId,
      transactionId: transactionId,
      idempotencyKey: idempotencyKey,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }
}
