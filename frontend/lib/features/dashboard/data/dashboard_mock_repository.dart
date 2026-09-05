import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../domain/ai_insight.dart';
import '../domain/dashboard_snapshot.dart';
import '../domain/energy_data_point.dart';

abstract class DashboardRepository {
  Future<DashboardSnapshot?> fetchInitialSnapshot();
  Future<DashboardSnapshot?> refreshSnapshot();
  DashboardSnapshot simulateNextSnapshot(DashboardSnapshot current);
}

class DashboardMockRepository implements DashboardRepository {
  DashboardMockRepository({
    Random? random,
    DateTime? initialTime,
    this.forceEmpty = false,
    this.forceError = false,
  }) : _random = random ?? Random(42),
       _clock = initialTime ?? DateTime.now();

  final Random _random;
  DateTime _clock;
  final bool forceEmpty;
  final bool forceError;

  static const dailyGenerationTargetKwh = 42.0;

  /// Server endpoint for solar generation data.
  static const _solarEndpoint = 'https://bullpen-unsorted-clad.ngrok-free.dev/api/solar';

  /// Sends a solar generation value to the server (fire-and-forget).
  void _sendSolarGeneration(double value) {
    unawaited(_postGeneration(value));
  }

  Future<void> _postGeneration(double value) async {
    try {
      await http.post(
        Uri.parse(_solarEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: '{"generation": $value}',
      );
    } catch (_) {
      // Silently ignore send failures — don't disrupt the simulation.
    }
  }

  @override
  Future<DashboardSnapshot?> fetchInitialSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (forceError) {
      throw const DashboardRepositoryException(
        'Unable to load dashboard data.',
      );
    }
    if (forceEmpty) {
      return null;
    }
    return _initialSnapshot();
  }

  @override
  Future<DashboardSnapshot?> refreshSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (forceError) {
      throw const DashboardRepositoryException(
        'Unable to refresh dashboard data.',
      );
    }
    if (forceEmpty) {
      return null;
    }
    return simulateNextSnapshot(_initialSnapshot());
  }

  @override
  DashboardSnapshot simulateNextSnapshot(DashboardSnapshot current) {
    _clock = current.lastUpdated.add(const Duration(seconds: 4));
    final hour = _clock.hour + _clock.minute / 60;
    final solarPower = _bounded(
      current.currentSolarPowerKw + _jitter(0.28) + _solarBias(hour),
      1,
      6.8,
    );
    _sendSolarGeneration(solarPower);
    final consumptionPower = _bounded(
      current.currentConsumptionKw +
          _jitter(0.18) +
          _eveningConsumptionBias(hour),
      0.4,
      4.6,
    );
    final generationDelta = solarPower * 4 / 3600;
    final consumptionDelta = consumptionPower * 4 / 3600;
    final generationToday = _bounded(
      current.solarGenerationTodayKwh + generationDelta,
      0,
      65,
    );
    final consumptionToday = _bounded(
      current.consumptionTodayKwh + consumptionDelta,
      0,
      58,
    );
    final available = _availableToSell(
      generationToday: generationToday,
      consumptionToday: consumptionToday,
      batteryPercentage: current.batteryPercentage,
    );
    final batteryDelta = solarPower > consumptionPower ? 1 : -1;
    final batteryPercentage =
        (current.batteryPercentage +
                (batteryDelta == 1 && _random.nextBool()
                    ? 1
                    : batteryDelta == -1
                    ? -1
                    : 0))
            .clamp(0, 100);
    final status = _batteryStatus(
      batteryPercentage: batteryPercentage,
      solarPower: solarPower,
      consumptionPower: consumptionPower,
    );
    final savingsDelta = generationDelta * 7.25;
    final co2Delta = generationDelta * 0.7;

    final snapshot = current.copyWith(
      solarGenerationTodayKwh: generationToday,
      currentSolarPowerKw: solarPower,
      consumptionTodayKwh: consumptionToday,
      currentConsumptionKw: consumptionPower,
      availableToSellKwh: available,
      batteryPercentage: batteryPercentage,
      batteryStatus: status,
      gridSavings: current.gridSavings + savingsDelta,
      co2AvoidedKg: current.co2AvoidedKg + co2Delta,
      sustainabilityScore: _bounded(
        current.sustainabilityScore +
            (generationDelta > consumptionDelta ? 0.02 : 0),
        0,
        100,
      ).round(),
      lastUpdated: _clock,
      solarHistory: _appendPoint(current.solarHistory, solarPower),
      consumptionHistory: _appendPoint(
        current.consumptionHistory,
        consumptionPower,
      ),
    );

    return snapshot.copyWith(aiInsights: _buildInsights(snapshot));
  }

  DashboardSnapshot _initialSnapshot() {
    final solarHistory = _history(base: 3.6, spread: 1.6);
    final consumptionHistory = _history(base: 2.1, spread: 0.9);
    final generationToday = 32.5 + _jitter(1.2);
    final consumptionToday = 18.2 + _jitter(0.9);
    // Send each initial solar history value to the server
    for (final point in solarHistory) {
      _sendSolarGeneration(point.value);
    }

    final snapshot = DashboardSnapshot(
      solarGenerationTodayKwh: _bounded(generationToday, 0, 65),
      currentSolarPowerKw: _bounded(solarHistory.last.value, 1, 6.8),
      consumptionTodayKwh: _bounded(consumptionToday, 0, 58),
      currentConsumptionKw: _bounded(consumptionHistory.last.value, 0.4, 4.6),
      availableToSellKwh: _availableToSell(
        generationToday: generationToday,
        consumptionToday: consumptionToday,
        batteryPercentage: 82,
      ),
      batteryPercentage: 82,
      batteryHealthPercentage: 94,
      batteryStatus: BatteryStatus.charging,
      walletBalance: 845.50,
      gridSavings: 214.00,
      co2AvoidedKg: 18.6,
      sustainabilityScore: 86,
      lastUpdated: _clock,
      solarHistory: solarHistory,
      consumptionHistory: consumptionHistory,
      aiInsights: const [],
    );
    return snapshot.copyWith(aiInsights: _buildInsights(snapshot));
  }

  List<EnergyDataPoint> _history({
    required double base,
    required double spread,
  }) {
    final start = DateTime(_clock.year, _clock.month, _clock.day, 6);
    return [
      for (var i = 0; i < 12; i++)
        EnergyDataPoint(
          time: start.add(Duration(hours: i)),
          value: _bounded(
            base + sin(i / 12 * pi) * spread + _jitter(0.22),
            0,
            7,
          ),
        ),
    ];
  }

  List<EnergyDataPoint> _appendPoint(
    List<EnergyDataPoint> points,
    double value,
  ) {
    final next = [...points, EnergyDataPoint(time: _clock, value: value)];
    if (next.length > 12) {
      return next.sublist(next.length - 12);
    }
    return next;
  }

  List<AiInsight> _buildInsights(DashboardSnapshot snapshot) {
    final targetProgress =
        snapshot.solarGenerationTodayKwh / dailyGenerationTargetKwh;
    final surplusValue = snapshot.availableToSellKwh * 5.8;
    return [
      AiInsight(
        title: targetProgress > 0.75
            ? 'Strong solar output'
            : 'Solar output building',
        message: targetProgress > 0.75
            ? 'Solar generation is ${(targetProgress * 100 - 70).round()}% above the mid-day expectation.'
            : 'Generation is steady; keep monitoring afternoon production.',
        category: AiInsightCategory.generation,
        priority: targetProgress > 0.75
            ? AiInsightPriority.medium
            : AiInsightPriority.low,
      ),
      AiInsight(
        title: 'Battery reserve',
        message: snapshot.batteryPercentage < 35
            ? 'Keep at least 30% battery reserve before selling more energy.'
            : 'Battery reserve is healthy for evening demand.',
        category: AiInsightCategory.battery,
        priority: snapshot.batteryPercentage < 35
            ? AiInsightPriority.high
            : AiInsightPriority.medium,
      ),
      AiInsight(
        title: 'Best selling window',
        message:
            'Best estimated selling window: 6:00 PM-8:00 PM. Current surplus could earn approximately Rs ${surplusValue.toStringAsFixed(0)}.',
        category: AiInsightCategory.marketplace,
        priority: AiInsightPriority.high,
        actionLabel: 'View market',
      ),
      if (snapshot.currentConsumptionKw > 3.2)
        const AiInsight(
          title: 'Consumption is elevated',
          message:
              'Consumption is higher than usual; delay non-essential loads.',
          category: AiInsightCategory.consumption,
          priority: AiInsightPriority.high,
        ),
    ];
  }

  BatteryStatus _batteryStatus({
    required int batteryPercentage,
    required double solarPower,
    required double consumptionPower,
  }) {
    if (batteryPercentage <= 30) {
      return BatteryStatus.reserve;
    }
    if (solarPower > consumptionPower + 0.3) {
      return BatteryStatus.charging;
    }
    if (consumptionPower > solarPower + 0.4) {
      return BatteryStatus.discharging;
    }
    return BatteryStatus.idle;
  }

  double _availableToSell({
    required double generationToday,
    required double consumptionToday,
    required int batteryPercentage,
  }) {
    final reserveBuffer = batteryPercentage < 45 ? 4.0 : 1.4;
    return _bounded(generationToday - consumptionToday - reserveBuffer, 0, 24);
  }

  double _solarBias(double hour) {
    if (hour < 7 || hour > 18) {
      return -0.18;
    }
    if (hour >= 10 && hour <= 14) {
      return 0.08;
    }
    return -0.02;
  }

  double _eveningConsumptionBias(double hour) {
    if (hour >= 18 && hour <= 22) {
      return 0.08;
    }
    return 0;
  }

  double _jitter(double amplitude) {
    return (_random.nextDouble() * 2 - 1) * amplitude;
  }

  double _bounded(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }
}

class DashboardRepositoryException implements Exception {
  const DashboardRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
