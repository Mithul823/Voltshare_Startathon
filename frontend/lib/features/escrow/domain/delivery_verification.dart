import 'escrow_agreement.dart';

enum DeliveryVerificationStatus {
  complete('Complete'),
  partial('Partial'),
  failed('Failed'),
  blocked('Blocked');

  const DeliveryVerificationStatus(this.label);
  final String label;
}

class DeliveryVerificationInput {
  const DeliveryVerificationInput({
    required this.escrow,
    required this.simulatedMeterReadingKwh,
    required this.deliveryStart,
    required this.deliveryEnd,
    required this.meterIdentifier,
    required this.integrityOk,
  });

  final EscrowAgreement escrow;
  final double simulatedMeterReadingKwh;
  final DateTime deliveryStart;
  final DateTime deliveryEnd;
  final String meterIdentifier;
  final bool integrityOk;
}

class DeliveryVerificationResult {
  const DeliveryVerificationResult({
    required this.expectedEnergyKwh,
    required this.deliveredEnergyKwh,
    required this.deliveryPercentage,
    required this.meterMatched,
    required this.withinDeliveryWindow,
    required this.tamperingDetected,
    required this.verificationStatus,
    required this.verifiedAt,
  });

  final double expectedEnergyKwh;
  final double deliveredEnergyKwh;
  final double deliveryPercentage;
  final bool meterMatched;
  final bool withinDeliveryWindow;
  final bool tamperingDetected;
  final DeliveryVerificationStatus verificationStatus;
  final DateTime verifiedAt;
}
