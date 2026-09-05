class EscrowAuditEvent {
  const EscrowAuditEvent({
    required this.id,
    required this.escrowId,
    required this.type,
    required this.description,
    required this.integrityHash,
    required this.createdAt,
    required this.idempotencyKey,
  });

  final String id;
  final String escrowId;
  final String type;
  final String description;
  final String integrityHash;
  final DateTime createdAt;
  final String idempotencyKey;
}
