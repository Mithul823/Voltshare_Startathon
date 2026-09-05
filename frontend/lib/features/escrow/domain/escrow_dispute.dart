enum DisputeStatus {
  submitted('Submitted'),
  evidenceRequested('Evidence requested'),
  underReview('Under review'),
  resolvedForBuyer('Resolved for buyer'),
  resolvedForSeller('Resolved for seller'),
  partiallyResolved('Partially resolved'),
  rejected('Rejected');

  const DisputeStatus(this.label);
  final String label;
}

class EscrowDispute {
  const EscrowDispute({
    required this.id,
    required this.escrowId,
    required this.raisedBy,
    required this.category,
    required this.description,
    required this.status,
    required this.evidence,
    required this.createdAt,
    required this.updatedAt,
    required this.resolution,
  });

  final String id;
  final String escrowId;
  final String raisedBy;
  final String category;
  final String description;
  final DisputeStatus status;
  final List<String> evidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String resolution;
}
