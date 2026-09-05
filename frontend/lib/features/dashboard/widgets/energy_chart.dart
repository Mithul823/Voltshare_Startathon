import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/energy_data_point.dart';

enum EnergyChartType { solar, consumption }

class EnergyChart extends StatelessWidget {
  const EnergyChart({
    required this.title,
    required this.points,
    required this.type,
    super.key,
  });

  final String title;
  final List<EnergyDataPoint> points;
  final EnergyChartType type;

  @override
  Widget build(BuildContext context) {
    final color = type == EnergyChartType.solar
        ? Theme.of(context).colorScheme.primary
        : Colors.teal.shade700;
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];

    final maxVal = points.isEmpty
        ? 0.0
        : points.fold<double>(0.0, (prev, p) => math.max(prev, p.value));
    final safeMaxY = math.max(maxVal * 1.25, 5.0);
    final safeMaxX = math.max((points.length - 1).toDouble(), 1.0);

    return Semantics(
      label: '$title chart with ${points.length} time based readings',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    type == EnergyChartType.solar
                        ? Icons.wb_sunny_outlined
                        : Icons.home_outlined,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (points.isEmpty)
                SizedBox(
                  height: 210,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type == EnergyChartType.solar
                              ? Icons.wb_sunny_outlined
                              : Icons.bolt_outlined,
                          size: 32,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type == EnergyChartType.solar
                              ? 'No solar generation recorded in this window.'
                              : 'No consumption readings recorded in this window.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 210,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: safeMaxX,
                      minY: 0,
                      maxY: safeMaxY,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots
                                .map(
                                  (spot) => LineTooltipItem(
                                    '${spot.y.toStringAsFixed(2)} kW',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                                .toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toStringAsFixed(0),
                                style: Theme.of(context).textTheme.labelSmall,
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 3,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              final hour = points[index].time.hour;
                              return Text(
                                '$hour:00',
                                style: Theme.of(context).textTheme.labelSmall,
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.14),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
