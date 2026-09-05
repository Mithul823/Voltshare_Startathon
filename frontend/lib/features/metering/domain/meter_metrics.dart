import 'package:flutter/foundation.dart';

enum MeterConnectionStatus {
  live,
  connecting,
  stale,
  offline;

  String get label => switch (this) {
    MeterConnectionStatus.live => 'LIVE',
    MeterConnectionStatus.connecting => 'CONNECTING',
    MeterConnectionStatus.stale => 'STALE',
    MeterConnectionStatus.offline => 'OFFLINE',
  };
}

@immutable
class MeterMetrics {
  const MeterMetrics({
    this.power,
    this.energy,
    this.voltage,
    this.current,
    this.powerFactor,
    this.meterType,
    required this.timestamp,
    this.status = MeterConnectionStatus.live,
    this.errorMessage,
    this.isColdStarting = false,
  });

  /// Active Power in Watts (W)
  final double? power;

  /// Cumulative Energy in kWh
  final double? energy;

  /// AC Line Voltage in Volts (V)
  final double? voltage;

  /// Line Current in Amperes (A)
  final double? current;

  /// Power Factor (unitless, usually 0.0 - 1.0)
  final double? powerFactor;

  /// Identifier / Role of meter, e.g. 'producer'
  final String? meterType;

  /// Time when reading was fetched or reported by meter
  final DateTime timestamp;

  /// Current telemetry connection status
  final MeterConnectionStatus status;

  /// User-friendly error or diagnostic detail
  final String? errorMessage;

  /// Indicates if service may be experiencing a cold-start delay
  final bool isColdStarting;

  /// Safe parsing from external smart meter JSON response
  /// Handles both direct and nested shapes, integer/double numbers, and strings.
  factory MeterMetrics.fromJson(
    Map<String, dynamic> json, {
    DateTime? timestamp,
    MeterConnectionStatus status = MeterConnectionStatus.live,
  }) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final parsedPower = _toDouble(payload['power'] ?? payload['watts']);
    final parsedEnergy = _toDouble(
      payload['energy'] ?? payload['energy_kwh'] ?? payload['energyKwh'],
    );
    final parsedVoltage = _toDouble(payload['voltage']);
    final parsedPf = _toDouble(
      payload['powerFactor'] ?? payload['power_factor'] ?? payload['pf'],
    );

    // Line Current: use explicit value if provided, or derive I = P / (V * PF)
    double? parsedCurrent = _toDouble(
      payload['current'] ?? payload['current_a'] ?? payload['currentA'],
    );
    if (parsedCurrent == null &&
        parsedPower != null &&
        parsedVoltage != null &&
        parsedVoltage > 0) {
      final pf = (parsedPf != null && parsedPf > 0) ? parsedPf : 1.0;
      parsedCurrent = parsedPower / (parsedVoltage * pf);
    }

    final meter =
        payload['meter']?.toString() ?? payload['meter_type']?.toString();

    DateTime readingTime = timestamp ?? DateTime.now();
    if (payload['timestamp'] != null) {
      final parsed = DateTime.tryParse(payload['timestamp'].toString());
      if (parsed != null) {
        readingTime = parsed;
      }
    }

    return MeterMetrics(
      power: parsedPower,
      energy: parsedEnergy,
      voltage: parsedVoltage,
      current: parsedCurrent,
      powerFactor: parsedPf,
      meterType: meter,
      timestamp: readingTime,
      status: status,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  MeterMetrics copyWith({
    double? power,
    double? energy,
    double? voltage,
    double? current,
    double? powerFactor,
    String? meterType,
    DateTime? timestamp,
    MeterConnectionStatus? status,
    String? errorMessage,
    bool? isColdStarting,
  }) {
    return MeterMetrics(
      power: power ?? this.power,
      energy: energy ?? this.energy,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      powerFactor: powerFactor ?? this.powerFactor,
      meterType: meterType ?? this.meterType,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isColdStarting: isColdStarting ?? this.isColdStarting,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeterMetrics &&
          runtimeType == other.runtimeType &&
          power == other.power &&
          energy == other.energy &&
          voltage == other.voltage &&
          current == other.current &&
          powerFactor == other.powerFactor &&
          meterType == other.meterType &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    power,
    energy,
    voltage,
    current,
    powerFactor,
    meterType,
    status,
    errorMessage,
  );
}
