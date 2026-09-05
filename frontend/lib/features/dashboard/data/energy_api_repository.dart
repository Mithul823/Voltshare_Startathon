import '../../../core/network/api_client.dart';
import '../domain/energy_data_point.dart';

class EnergyApiRepository {
  const EnergyApiRepository(this._client);

  final ApiClient _client;

  Future<List<EnergyDataPoint>> energyHistory({String interval = 'hour'}) async {
    final data = await _client.get(
      '/dashboard/energy-history',
      query: {'interval': interval},
    ) as Map;
    return _points(data['energy'] as List);
  }

  Future<List<EnergyDataPoint>> batteryHistory({String interval = 'hour'}) async {
    final data = await _client.get(
      '/dashboard/battery-history',
      query: {'interval': interval},
    ) as Map;
    return (data['battery'] as List)
        .map(
          (item) => EnergyDataPoint(
            time: DateTime.parse((item as Map)['time'].toString()),
            value: (item['battery_percent'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<Map<String, Object?>>> activity() async {
    final data = await _client.get('/dashboard/activity') as Map;
    return (data['activity'] as List)
        .map((item) => (item as Map).cast<String, Object?>())
        .toList();
  }

  List<EnergyDataPoint> _points(List data) {
    return data
        .map(
          (item) => EnergyDataPoint(
            time: DateTime.parse((item as Map)['time'].toString()),
            value: (item['value'] as num).toDouble(),
          ),
        )
        .toList();
  }
}
