enum EscrowStatus {
  awaitingFunding('Awaiting funding'),
  funded('Funds reserved'),
  energyDeliveryPending('Awaiting energy delivery'),
  deliveryPartiallyConfirmed('Delivery partially confirmed'),
  deliveryConfirmed('Delivery confirmed'),
  releasePending('Settlement processing'),
  released('Funds released'),
  refundPending('Refund pending'),
  refunded('Refunded'),
  disputed('Under review'),
  frozen('Funds frozen'),
  expired('Expired'),
  cancelled('Cancelled');

  const EscrowStatus(this.label);
  final String label;
}

class EscrowAgreement {
  const EscrowAgreement({
    required this.id,
    required this.purchaseId,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.energyQuantityKwh,
    required this.amountHeldPaise,
    required this.platformFeePaise,
    required this.totalHeldPaise,
    required this.deliveredEnergyKwh,
    required this.status,
    required this.createdAt,
    required this.deliveryDeadline,
    required this.integrityHash,
    required this.version,
    this.fundedAt,
    this.completedAt,
    this.releasedAt,
    this.refundedAt,
    this.disputedAt,
    this.failureReason,
  });

  final String id;
  final String purchaseId;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final double energyQuantityKwh;
  final int amountHeldPaise;
  final int platformFeePaise;
  final int totalHeldPaise;
  final double deliveredEnergyKwh;
  final EscrowStatus status;
  final DateTime createdAt;
  final DateTime? fundedAt;
  final DateTime deliveryDeadline;
  final DateTime? completedAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;
  final DateTime? disputedAt;
  final String? failureReason;
  final String integrityHash;
  final int version;

  EscrowAgreement copyWith({
    double? deliveredEnergyKwh,
    EscrowStatus? status,
    DateTime? fundedAt,
    DateTime? completedAt,
    DateTime? releasedAt,
    DateTime? refundedAt,
    DateTime? disputedAt,
    String? failureReason,
    String? integrityHash,
    int? version,
  }) {
    return EscrowAgreement(
      id: id,
      purchaseId: purchaseId,
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
      energyQuantityKwh: energyQuantityKwh,
      amountHeldPaise: amountHeldPaise,
      platformFeePaise: platformFeePaise,
      totalHeldPaise: totalHeldPaise,
      deliveredEnergyKwh: deliveredEnergyKwh ?? this.deliveredEnergyKwh,
      status: status ?? this.status,
      createdAt: createdAt,
      fundedAt: fundedAt ?? this.fundedAt,
      deliveryDeadline: deliveryDeadline,
      completedAt: completedAt ?? this.completedAt,
      releasedAt: releasedAt ?? this.releasedAt,
      refundedAt: refundedAt ?? this.refundedAt,
      disputedAt: disputedAt ?? this.disputedAt,
      failureReason: failureReason ?? this.failureReason,
      integrityHash: integrityHash ?? this.integrityHash,
      version: version ?? this.version,
    );
  }
}
