import '../../../core/network/api_client.dart';
import '../domain/ai_insight.dart';
import '../domain/dashboard_snapshot.dart';
import '../domain/energy_data_point.dart';
import 'dashboard_mock_repository.dart';

class DashboardApiRepository implements DashboardRepository {
  DashboardApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<DashboardSnapshot?> fetchInitialSnapshot() => _fetch();

  @override
  Future<DashboardSnapshot?> refreshSnapshot() => _fetch();

  @override
  DashboardSnapshot simulateNextSnapshot(DashboardSnapshot current) {
    // In live mode, real-time updates come via WebSocket or periodic refresh
    return current;
  }

  Future<DashboardSnapshot?> _fetch() async {
    final data = await _client.get('/dashboard') as Map;
    return _snapshot(data);
  }
}

DashboardSnapshot _snapshot(Map data) {
  return DashboardSnapshot(
    solarGenerationTodayKwh:
        _numValue(data['solarGenerationTodayKwh']),
    currentSolarPowerKw:
        _numValue(data['currentSolarPowerKw']),
    consumptionTodayKwh:
        _numValue(data['consumptionTodayKwh']),
    currentConsumptionKw:
        _numValue(data['currentConsumptionKw']),
    availableToSellKwh:
        _numValue(data['availableToSellKwh']),
    batteryPercentage:
        _intValue(data['batteryPercentage'], 50),
    batteryHealthPercentage:
        _intValue(data['batteryHealthPercentage'], 94),
    batteryStatus: _batteryStatusValue(data['batteryStatus']),
    walletBalance: _intValue(data['walletBalancePaise'], 0) / 100,
    gridSavings: _intValue(data['gridSavingsPaise'], 0) / 100,
    co2AvoidedKg: _numValue(data['co2AvoidedKg']),
    sustainabilityScore:
        _intValue(data['sustainabilityScore'], 70),
    lastUpdated: _dateTimeValue(
        data['lastUpdated'], DateTime.now()),
    solarHistory: _pointsSafe(data['solarHistory']),
    consumptionHistory: _pointsSafe(data['consumptionHistory']),
    aiInsights: ((data['aiInsights'] as List?) ?? [])
        .map((item) => _insight(item as Map))
        .toList(),
  );
}

double _numValue(Object? value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  return fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return fallback;
}

DateTime _dateTimeValue(Object? value, DateTime fallback) {
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback;
  }
  if (value is DateTime) return value;
  return fallback;
}

BatteryStatus _batteryStatusValue(Object? value) {
  final name = value?.toString() ?? 'idle';
  return BatteryStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => BatteryStatus.idle,
  );
}

List<EnergyDataPoint> _pointsSafe(Object? data) {
  final list = data as List?;
  if (list == null || list.isEmpty) return const [];
  return list
      .map((item) {
        final map = item as Map?;
        if (map == null) return null;
        return EnergyDataPoint(
          time: _dateTimeValue(map['time'], DateTime.now()),
          value: _numValue(map['value']),
        );
      })
      .whereType<EnergyDataPoint>()
      .toList();
}

AiInsight _insight(Map data) {
  final category = data['category'].toString();
  final priority = data['priority'].toString();
  return AiInsight(
    title: data['title'].toString(),
    message: data['message'].toString(),
    category: AiInsightCategory.values.firstWhere(
      (item) => item.name == category,
      orElse: () => AiInsightCategory.marketplace,
    ),
    priority: AiInsightPriority.values.firstWhere(
      (item) => item.name == priority,
      orElse: () => AiInsightPriority.medium,
    ),
    actionLabel: data['action_label']?.toString(),
  );
}
