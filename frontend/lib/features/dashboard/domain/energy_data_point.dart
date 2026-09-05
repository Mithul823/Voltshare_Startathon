class EnergyDataPoint {
  const EnergyDataPoint({required this.time, required this.value});

  final DateTime time;
  final double value;

  EnergyDataPoint copyWith({DateTime? time, double? value}) {
    return EnergyDataPoint(time: time ?? this.time, value: value ?? this.value);
  }
}
