import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/meter_metrics.dart';
import '../providers/meter_provider.dart';

class ProducerSmartMeterCard extends ConsumerWidget {
  const ProducerSmartMeterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meterState = ref.watch(producerMeterProvider);
    final theme = Theme.of(context);

    return meterState.when(
      data: (metrics) => _buildMeterContent(context, ref, theme, metrics),
      loading: () => _buildConnectingCard(context, ref, theme),
      error: (error, _) =>
          _buildErrorCard(context, ref, theme, error.toString()),
    );
  }

  Widget _buildMeterContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    MeterMetrics metrics,
  ) {
    if (metrics.status == MeterConnectionStatus.connecting &&
        metrics.power == null) {
      return _buildConnectingCard(context, ref, theme);
    }

    if (metrics.status == MeterConnectionStatus.offline &&
        metrics.power == null) {
      return _buildErrorCard(
        context,
        ref,
        theme,
        metrics.errorMessage ?? 'Smart meter data is temporarily unavailable.',
      );
    }

    final isLive = metrics.status == MeterConnectionStatus.live;
    final isStale = metrics.status == MeterConnectionStatus.stale;

    final Color statusColor = switch (metrics.status) {
      MeterConnectionStatus.live => const Color(0xFF00E676),
      MeterConnectionStatus.connecting => const Color(0xFFFFB300),
      MeterConnectionStatus.stale => const Color(0xFFFF9100),
      MeterConnectionStatus.offline => const Color(0xFFFF5252),
    };

    final timeStr = _formatTimestamp(metrics.timestamp);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1914),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isStale
              ? const Color(0xFFFF9100).withValues(alpha: 0.5)
              : const Color(0xFF00E676).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isStale ? const Color(0xFFFF9100) : const Color(0xFF00E676))
                .withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF132F24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bolt,
                        color: Color(0xFF00E676),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRODUCER SMART METER',
                          style: TextStyle(
                            color: Color(0xFF80CBC4),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'IoT Telemetry • /meter-metrics/producer',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            metrics.status.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Manual Refresh Button
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      color: const Color(0xFF80CBC4),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Refresh smart meter data',
                      onPressed: () =>
                          ref.read(producerMeterProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Stale Notice Banner (if applicable)
            if (isStale) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9100).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF9100).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFFFF9100),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        metrics.errorMessage ??
                            'Connection interrupted. Showing last valid telemetry.',
                        style: const TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Hero Metric: Active Generation Power
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF07120D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACTIVE GENERATION POWER',
                        style: TextStyle(
                          color: Color(0xFF4DB6AC),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            metrics.power != null
                                ? metrics.power!.toStringAsFixed(1)
                                : '--',
                            style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Watts (W)',
                            style: TextStyle(
                              color: Color(0xFF80CBC4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132F24),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'IN KILOWATTS',
                          style: TextStyle(
                            color: Color(0xFF80CBC4),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          metrics.power != null
                              ? '${(metrics.power! / 1000.0).toStringAsFixed(2)} kW'
                              : '-- kW',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4-Telemetry Sub-Grid
            Row(
              children: [
                Expanded(
                  child: _buildTelemetryTile(
                    label: 'CUMULATIVE ENERGY',
                    value: metrics.energy != null
                        ? metrics.energy!.toStringAsFixed(2)
                        : '--',
                    unit: 'kWh',
                    icon: Icons.energy_savings_leaf_outlined,
                    accentColor: const Color(0xFF26A69A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTelemetryTile(
                    label: 'LINE VOLTAGE',
                    value: metrics.voltage != null
                        ? metrics.voltage!.toStringAsFixed(1)
                        : '--',
                    unit: 'V',
                    icon: Icons.electrical_services_rounded,
                    accentColor: const Color(0xFF42A5F5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTelemetryTile(
                    label: 'LINE CURRENT',
                    value: metrics.current != null
                        ? metrics.current!.toStringAsFixed(2)
                        : '--',
                    unit: 'A',
                    icon: Icons.speed_rounded,
                    accentColor: const Color(0xFFAB47BC),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTelemetryTile(
                    label: 'POWER FACTOR',
                    value: metrics.powerFactor != null
                        ? metrics.powerFactor!.toStringAsFixed(2)
                        : '--',
                    unit: 'PF',
                    icon: Icons.tune_rounded,
                    accentColor: const Color(0xFF66BB6A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Footer info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Last updated: $timeStr',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isLive)
                  const Text(
                    'Auto-polling • 3s',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091611),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1914),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFFFFB300), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'PRODUCER SMART METER',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'CONNECTING',
                  style: TextStyle(
                    color: Color(0xFFFFB300),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connecting to live smart meter hardware endpoint...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    String errorMessage,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF160E0E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFFFF5252), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'PRODUCER SMART METER',
                    style: TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF8A80),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMessage.isNotEmpty
                      ? errorMessage
                      : 'Smart meter data is temporarily unavailable.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8A80),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: const Color(
                    0xFFFF5252,
                  ).withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () =>
                    ref.read(producerMeterProvider.notifier).refresh(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
