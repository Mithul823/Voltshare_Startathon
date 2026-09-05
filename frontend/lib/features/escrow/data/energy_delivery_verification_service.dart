import '../domain/delivery_verification.dart';

abstract class EnergyDeliveryVerificationService {
  DeliveryVerificationResult verify(DeliveryVerificationInput input);
}

class MockEnergyDeliveryVerificationService
    implements EnergyDeliveryVerificationService {
  const MockEnergyDeliveryVerificationService({
    this.expectedMeterPrefix = 'MTR-',
  });

  final String expectedMeterPrefix;

  @override
  DeliveryVerificationResult verify(DeliveryVerificationInput input) {
    final expected = input.escrow.energyQuantityKwh;
    final delivered = input.simulatedMeterReadingKwh.clamp(0, expected);
    final percentage = expected <= 0 ? 0.0 : delivered / expected;
    final meterMatched = input.meterIdentifier.startsWith(expectedMeterPrefix);
    final withinWindow =
        !input.deliveryStart.isAfter(input.escrow.deliveryDeadline) &&
        !input.deliveryEnd.isAfter(
          input.escrow.deliveryDeadline.add(const Duration(minutes: 30)),
        );
    final tamperingDetected = !input.integrityOk;
    final status = !meterMatched || tamperingDetected
        ? DeliveryVerificationStatus.blocked
        : percentage >= 0.98 && withinWindow
        ? DeliveryVerificationStatus.complete
        : percentage >= 0.5 && withinWindow
        ? DeliveryVerificationStatus.partial
        : DeliveryVerificationStatus.failed;
    return DeliveryVerificationResult(
      expectedEnergyKwh: expected,
      deliveredEnergyKwh: delivered.toDouble(),
      deliveryPercentage: percentage.toDouble(),
      meterMatched: meterMatched,
      withinDeliveryWindow: withinWindow,
      tamperingDetected: tamperingDetected,
      verificationStatus: status,
      verifiedAt: input.deliveryEnd,
    );
  }
}
