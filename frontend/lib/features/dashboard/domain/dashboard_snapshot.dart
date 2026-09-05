import 'ai_insight.dart';
import 'energy_data_point.dart';

enum BatteryStatus { charging, discharging, idle, reserve }

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.solarGenerationTodayKwh,
    required this.currentSolarPowerKw,
    required this.consumptionTodayKwh,
    required this.currentConsumptionKw,
    required this.availableToSellKwh,
    required this.batteryPercentage,
    required this.batteryHealthPercentage,
    required this.batteryStatus,
    required this.walletBalance,
    required this.gridSavings,
    required this.co2AvoidedKg,
    required this.sustainabilityScore,
    required this.lastUpdated,
    required this.solarHistory,
    required this.consumptionHistory,
    required this.aiInsights,
  });

  final double solarGenerationTodayKwh;
  final double currentSolarPowerKw;
  final double consumptionTodayKwh;
  final double currentConsumptionKw;
  final double availableToSellKwh;
  final int batteryPercentage;
  final int batteryHealthPercentage;
  final BatteryStatus batteryStatus;
  final double walletBalance;
  final double gridSavings;
  final double co2AvoidedKg;
  final int sustainabilityScore;
  final DateTime lastUpdated;
  final List<EnergyDataPoint> solarHistory;
  final List<EnergyDataPoint> consumptionHistory;
  final List<AiInsight> aiInsights;

  DashboardSnapshot copyWith({
    double? solarGenerationTodayKwh,
    double? currentSolarPowerKw,
    double? consumptionTodayKwh,
    double? currentConsumptionKw,
    double? availableToSellKwh,
    int? batteryPercentage,
    int? batteryHealthPercentage,
    BatteryStatus? batteryStatus,
    double? walletBalance,
    double? gridSavings,
    double? co2AvoidedKg,
    int? sustainabilityScore,
    DateTime? lastUpdated,
    List<EnergyDataPoint>? solarHistory,
    List<EnergyDataPoint>? consumptionHistory,
    List<AiInsight>? aiInsights,
  }) {
    return DashboardSnapshot(
      solarGenerationTodayKwh:
          solarGenerationTodayKwh ?? this.solarGenerationTodayKwh,
      currentSolarPowerKw: currentSolarPowerKw ?? this.currentSolarPowerKw,
      consumptionTodayKwh: consumptionTodayKwh ?? this.consumptionTodayKwh,
      currentConsumptionKw: currentConsumptionKw ?? this.currentConsumptionKw,
      availableToSellKwh: availableToSellKwh ?? this.availableToSellKwh,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      batteryHealthPercentage:
          batteryHealthPercentage ?? this.batteryHealthPercentage,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      walletBalance: walletBalance ?? this.walletBalance,
      gridSavings: gridSavings ?? this.gridSavings,
      co2AvoidedKg: co2AvoidedKg ?? this.co2AvoidedKg,
      sustainabilityScore: sustainabilityScore ?? this.sustainabilityScore,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      solarHistory: solarHistory ?? this.solarHistory,
      consumptionHistory: consumptionHistory ?? this.consumptionHistory,
      aiInsights: aiInsights ?? this.aiInsights,
    );
  }
}
