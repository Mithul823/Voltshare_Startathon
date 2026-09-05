/// Typed request model for smart-meter consumer-purchase endpoint.
class ConsumerPurchaseMeterRequest {
  const ConsumerPurchaseMeterRequest({required this.kwh});

  /// The purchase quantity in kilowatt-hours.
  final double kwh;

  Map<String, dynamic> toJson() => {'kwh': kwh};
}
