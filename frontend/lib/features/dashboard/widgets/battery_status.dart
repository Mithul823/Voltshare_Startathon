import 'package:flutter/material.dart';

import '../domain/dashboard_snapshot.dart' as domain;

class BatteryStatus extends StatelessWidget {
  const BatteryStatus({
    required this.percentage,
    required this.healthPercentage,
    required this.status,
    super.key,
  });

  final int percentage;
  final int healthPercentage;
  final domain.BatteryStatus status;

  @override
  Widget build(BuildContext context) {
    final statusText = _statusText(status);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label:
          'Battery $percentage percent, health $healthPercentage percent, $statusText',
      child: Column(
        children: [
          Icon(_icon(status), color: colorScheme.primary, size: 42),
          const SizedBox(height: 4),
          Text(
            '$percentage%',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text('$statusText • $healthPercentage% health'),
        ],
      ),
    );
  }

  IconData _icon(domain.BatteryStatus status) {
    return switch (status) {
      domain.BatteryStatus.charging => Icons.battery_charging_full_outlined,
      domain.BatteryStatus.discharging => Icons.battery_5_bar_outlined,
      domain.BatteryStatus.idle => Icons.battery_full_outlined,
      domain.BatteryStatus.reserve => Icons.battery_alert_outlined,
    };
  }

  String _statusText(domain.BatteryStatus status) {
    return switch (status) {
      domain.BatteryStatus.charging => 'Charging',
      domain.BatteryStatus.discharging => 'Discharging',
      domain.BatteryStatus.idle => 'Idle',
      domain.BatteryStatus.reserve => 'Reserve mode',
    };
  }
}
