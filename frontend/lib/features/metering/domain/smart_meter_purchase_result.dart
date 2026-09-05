/// Status of the external smart meter purchase synchronization.
enum SmartMeterSyncStatus {
  success,
  failed,
  timeout,
  skipped,
}

/// Represents the result of sending a consumer energy purchase signal to the smart meter.
class SmartMeterPurchaseResult {
  const SmartMeterPurchaseResult({
    required this.status,
    this.message,
    this.kwh,
    this.storedAt,
    this.errorMessage,
    this.statusCode,
  });

  factory SmartMeterPurchaseResult.fromJson(
    Map<String, dynamic> json, {
    int statusCode = 200,
  }) {
    final kwhVal = json['kwh'];
    final double? parsedKwh = kwhVal is num
        ? kwhVal.toDouble()
        : double.tryParse(kwhVal?.toString() ?? '');
    DateTime? parsedStoredAt;
    if (json['storedAt'] != null) {
      parsedStoredAt = DateTime.tryParse(json['storedAt'].toString());
    }
    return SmartMeterPurchaseResult(
      status: SmartMeterSyncStatus.success,
      message: json['message']?.toString() ?? 'Consumer purchase kWh stored',
      kwh: parsedKwh,
      storedAt: parsedStoredAt,
      statusCode: statusCode,
    );
  }

  factory SmartMeterPurchaseResult.failure({
    required String errorMessage,
    SmartMeterSyncStatus status = SmartMeterSyncStatus.failed,
    int? statusCode,
  }) {
    return SmartMeterPurchaseResult(
      status: status,
      errorMessage: errorMessage,
      statusCode: statusCode,
    );
  }

  final SmartMeterSyncStatus status;
  final String? message;
  final double? kwh;
  final DateTime? storedAt;
  final String? errorMessage;
  final int? statusCode;

  bool get isSuccess => status == SmartMeterSyncStatus.success;
}
