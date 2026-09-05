enum DefaultReason {
  sellerNonDelivery('Seller non-delivery'),
  partialDelivery('Partial delivery'),
  buyerCancellation('Buyer cancellation'),
  insufficientBuyerBalance('Insufficient buyer balance'),
  deliveryTimeout('Delivery timeout'),
  meterMismatch('Meter mismatch'),
  duplicateSettlementAttempt('Duplicate settlement attempt'),
  suspectedTampering('Suspected tampering'),
  systemFailure('System failure'),
  policyViolation('Policy violation');

  const DefaultReason(this.label);
  final String label;
}

enum DefaultResolution {
  fullReleaseToSeller('Full release to seller'),
  proportionalRelease('Proportional release'),
  fullRefundToBuyer('Full refund to buyer'),
  partialRefund('Partial refund'),
  retryDelivery('Retry delivery'),
  manualReview('Manual review'),
  accountRestriction('Account restriction'),
  transactionCancelled('Transaction cancelled');

  const DefaultResolution(this.label);
  final String label;
}

enum DefaultCaseStatus {
  detected('Detected'),
  fundsFrozen('Funds frozen'),
  underReview('Under review'),
  resolved('Resolved'),
  rejected('Rejected'),
  escalated('Escalated');

  const DefaultCaseStatus(this.label);
  final String label;
}

class TradeDefaultCase {
  const TradeDefaultCase({
    required this.id,
    required this.escrowId,
    required this.defaultingParty,
    required this.reason,
    required this.expectedEnergyKwh,
    required this.deliveredEnergyKwh,
    required this.financialImpactPaise,
    required this.resolution,
    required this.status,
    required this.createdAt,
    required this.evidenceReferences,
    required this.notes,
    this.resolvedAt,
  });

  final String id;
  final String escrowId;
  final String defaultingParty;
  final DefaultReason reason;
  final double expectedEnergyKwh;
  final double deliveredEnergyKwh;
  final int financialImpactPaise;
  final DefaultResolution resolution;
  final DefaultCaseStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final List<String> evidenceReferences;
  final String notes;
}
