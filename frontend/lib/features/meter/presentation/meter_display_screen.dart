import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/widgets/voltshare_ui.dart';

// ============================================================
// METER MODEL
// ============================================================

class MeterData {
  final double energyWh;
  final double voltage;
  final double currentMa;
  final double watts;
  final double cost;
  final String timestamp;
  final bool fallback;

  const MeterData({
    required this.energyWh,
    required this.voltage,
    required this.currentMa,
    required this.watts,
    required this.cost,
    required this.timestamp,
    this.fallback = false,
  });

  factory MeterData.fromJson(Map<String, dynamic> json) {
    return MeterData(
      energyWh: _toDouble(json['energy_wh']),
      voltage: _toDouble(json['voltage']),
      currentMa: _toDouble(json['current_ma']),
      watts: _toDouble(json['watts']),
      cost: _toDouble(json['cost']),
      timestamp: json['timestamp']?.toString() ?? 'N/A',
      fallback: json['fallback'] == true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

// ============================================================
// PUBNUB CLIENT
// ============================================================

class VoltSharePubNub {
  static const String subscribeKey = 'demo';
  static const String channel = 'voltshare-meter';
  static const String userId = 'voltshare-display';
  static const String authKey = 'user-default';
  static const String origin = 'h2.pubnubapi.com';

  bool _subscribed = true;
  String _timetoken = '10000';

  Future<void> subscribe({
    required void Function(Map<String, dynamic>) onMessage,
    required void Function(String) onStatus,
  }) async {
    onStatus('CONNECTING');

    while (_subscribed) {
      try {
        final uri = Uri.https(
          origin,
          '/stream/$subscribeKey/$channel/0/$_timetoken',
          {'auth': authKey, 'uuid': userId},
        );

        final response = await http.get(uri);

        if (response.statusCode != 200) {
          onStatus('OFFLINE');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        final decoded = jsonDecode(response.body);

        if (decoded is! List || decoded.length < 2) {
          continue;
        }

        final messages = decoded[0];

        if (decoded[1] != null) {
          _timetoken = decoded[1].toString();
        }

        if (messages is List) {
          for (final message in messages) {
            if (message is Map<String, dynamic>) {
              onMessage(message);
            }
          }
        }
      } catch (e) {
        onStatus('OFFLINE');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  void unsubscribe() {
    _subscribed = false;
  }
}

// ============================================================
// SEVEN SEGMENT DISPLAY
// ============================================================

class SevenSegmentDisplay extends StatelessWidget {
  final String value;
  final double digitHeight;
  final bool small;
  final Color activeColor;
  final Color inactiveColor;

  const SevenSegmentDisplay({
    super.key,
    required this.value,
    this.digitHeight = 64,
    this.small = false,
    this.activeColor = const Color(0xFF00E676),
    this.inactiveColor = const Color(0xFF132F24),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: value.split('').map((char) {
        if (char == '.') {
          return _DecimalPoint(size: small ? 6 : 10, activeColor: activeColor);
        }

        return _SevenSegmentDigit(
          character: char,
          height: digitHeight,
          small: small,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        );
      }).toList(),
    );
  }
}

class _SevenSegmentDigit extends StatelessWidget {
  final String character;
  final double height;
  final bool small;
  final Color activeColor;
  final Color inactiveColor;

  const _SevenSegmentDigit({
    required this.character,
    required this.height,
    required this.small,
    required this.activeColor,
    required this.inactiveColor,
  });

  static const Map<String, String> segments = {
    '0': 'abcdef',
    '1': 'bc',
    '2': 'abged',
    '3': 'abgcd',
    '4': 'fgbc',
    '5': 'afgcd',
    '6': 'afgecd',
    '7': 'abc',
    '8': 'abcdefg',
    '9': 'abcdfg',
    ' ': '',
    '-': 'g',
  };

  bool isOn(String segment) {
    return segments[character]?.contains(segment) ?? false;
  }

  Widget segment(String name) {
    final active = isOn(name);

    return Container(
      decoration: BoxDecoration(
        color: active ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(2),
        boxShadow: active
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.6),
                  blurRadius: small ? 4 : 8,
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = height * 0.54;
    final thickness = small ? height * 0.10 : height * 0.11;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: small ? 1.5 : 2.5),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            // A - Top
            Positioned(
              top: 0,
              left: thickness,
              right: thickness,
              height: thickness,
              child: segment('a'),
            ),
            // B - Top Right
            Positioned(
              top: thickness,
              right: 0,
              width: thickness,
              height: height / 2 - thickness * 1.5,
              child: segment('b'),
            ),
            // C - Bottom Right
            Positioned(
              bottom: thickness,
              right: 0,
              width: thickness,
              height: height / 2 - thickness * 1.5,
              child: segment('c'),
            ),
            // D - Bottom
            Positioned(
              bottom: 0,
              left: thickness,
              right: thickness,
              height: thickness,
              child: segment('d'),
            ),
            // E - Bottom Left
            Positioned(
              bottom: thickness,
              left: 0,
              width: thickness,
              height: height / 2 - thickness * 1.5,
              child: segment('e'),
            ),
            // F - Top Left
            Positioned(
              top: thickness,
              left: 0,
              width: thickness,
              height: height / 2 - thickness * 1.5,
              child: segment('f'),
            ),
            // G - Middle
            Positioned(
              top: height / 2 - thickness / 2,
              left: thickness,
              right: thickness,
              height: thickness,
              child: segment('g'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecimalPoint extends StatelessWidget {
  final double size;
  final Color activeColor;

  const _DecimalPoint({required this.size, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 2, right: 3, bottom: size * 0.6),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activeColor,
          boxShadow: [
            BoxShadow(color: activeColor.withValues(alpha: 0.7), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MAIN PAGE
// ============================================================

class MeterDisplayPage extends StatefulWidget {
  const MeterDisplayPage({super.key});

  @override
  State<MeterDisplayPage> createState() => _MeterDisplayPageState();
}

class _MeterDisplayPageState extends State<MeterDisplayPage> {
  final VoltSharePubNub _pubnub = VoltSharePubNub();
  MeterData? _data;
  int _messageCount = 0;
  String _connectionStatus = 'CONNECTING';
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _startListening();
    _fallbackTimer = Timer(
      const Duration(seconds: 4),
      _showFallbackIfNecessary,
    );
  }

  void _startListening() {
    _pubnub.subscribe(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _connectionStatus = status;
        });
      },
      onMessage: (message) {
        if (!mounted) return;
        if (message.containsKey('energy_wh') ||
            message.containsKey('voltage')) {
          final meterData = MeterData.fromJson(message);
          setState(() {
            _data = meterData;
            _messageCount++;
            _connectionStatus = 'CONNECTED';
          });
          _fallbackTimer?.cancel();
        }
      },
    );
  }

  void _showFallbackIfNecessary() {
    if (_messageCount != 0 || !mounted) return;

    final demoData = MeterData(
      energyWh: 128.4,
      voltage: 230.0,
      currentMa: 1826,
      watts: 420,
      cost: 0.96,
      timestamp: DateTime.now().toIso8601String(),
      fallback: true,
    );

    setState(() {
      _data = demoData;
      _connectionStatus = 'DEMO STREAM';
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _pubnub.unsubscribe();
    super.dispose();
  }

  String formatEnergy(double value) {
    return value.toStringAsFixed(1).padLeft(6, '0');
  }

  String formatVoltage(double value) {
    return value.toStringAsFixed(1).padLeft(4, '0');
  }

  String formatCurrent(double value) {
    return value.toStringAsFixed(1);
  }

  String formatWatts(double value) {
    return value.round().toString().padLeft(4, '0');
  }

  String formatCost(double value) {
    return value.toStringAsFixed(2).padLeft(5, '0');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    final isConnected = _connectionStatus == 'CONNECTED';

    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Standard App Page Header
            AppPageHeader(
              title: 'Smart Energy Meter',
              subtitle: 'Real-time IoT hardware telemetry stream',
              fallbackRoute: '/dashboard',
              actions: [_buildStatusPill(theme, isConnected)],
            ),
            const SizedBox(height: 16),

            // Main Digital Meter Chassis
            if (data != null)
              _buildMeterChassis(theme, data)
            else
              _buildLoadingChassis(theme),

            const SizedBox(height: 18),

            // 4-Card Telemetry Grid
            if (data != null) _buildTelemetryGrid(theme, data),

            const SizedBox(height: 18),

            // Hardware & Stream Info Footer Card
            _buildHardwareInfoCard(theme, data),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ThemeData theme, bool isConnected) {
    final isDemo = _data?.fallback == true;
    final Color badgeColor = isConnected
        ? const Color(0xFF00866A)
        : (isDemo ? Colors.orange.shade800 : Colors.red.shade700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor,
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _connectionStatus,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterChassis(ThemeData theme, MeterData data) {
    final isConnected = _connectionStatus == 'CONNECTED';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1914),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background subtle grid lines
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(painter: _GridPatternPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hardware Header Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'VOLTSHARE SMART METER',
                            style: TextStyle(
                              color: Color(0xFF80CBC4),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF132F24),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MODBUS IoT',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // LCD Screen Area
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF07120D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL ACTIVE ENERGY',
                          style: TextStyle(
                            color: Color(0xFF4DB6AC),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SevenSegmentDisplay(
                            value: formatEnergy(data.energyWh),
                            digitHeight: 76,
                            activeColor: const Color(0xFF00E676),
                            inactiveColor: const Color(0xFF0C251C),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00E676,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Wh (Watt-Hours)',
                                style: TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status indicators row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLedIndicator(
                        'POWER',
                        true,
                        const Color(0xFF00E676),
                      ),
                      _buildLedIndicator(
                        'LINK',
                        isConnected,
                        const Color(0xFF00E676),
                      ),
                      _buildLedIndicator(
                        'TX/RX',
                        _messageCount > 0,
                        const Color(0xFF29B6F6),
                      ),
                      _buildLedIndicator(
                        'CALIB',
                        true,
                        const Color(0xFFFFB300),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedIndicator(String label, bool active, Color activeColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeColor : const Color(0xFF1E332B),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.6),
                      blurRadius: 5,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFB2DFDB) : Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryGrid(ThemeData theme, MeterData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;

        final cards = [
          _buildMetricCard(
            theme: theme,
            title: 'VOLTAGE',
            value: formatVoltage(data.voltage),
            unit: 'V',
            icon: Icons.electrical_services_rounded,
            accentColor: const Color(0xFF0288D1),
          ),
          _buildMetricCard(
            theme: theme,
            title: 'CURRENT',
            value: formatCurrent(data.currentMa),
            unit: 'mA',
            icon: Icons.speed_rounded,
            accentColor: const Color(0xFF7B1FA2),
          ),
          _buildMetricCard(
            theme: theme,
            title: 'ACTIVE POWER',
            value: formatWatts(data.watts),
            unit: 'W',
            icon: Icons.electric_bolt_rounded,
            accentColor: const Color(0xFFE65100),
          ),
          _buildMetricCard(
            theme: theme,
            title: 'ESTIMATED COST',
            value: formatCost(data.cost),
            unit: 'INR',
            icon: Icons.currency_rupee_rounded,
            accentColor: const Color(0xFF00866A),
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  children: [cards[0], const SizedBox(height: 12), cards[2]],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [cards[1], const SizedBox(height: 12), cards[3]],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            cards[2],
            const SizedBox(height: 12),
            cards[3],
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required ThemeData theme,
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        unit,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareInfoCard(ThemeData theme, MeterData? data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Hardware Connection Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Telemetry Protocol',
            'PubNub Real-Time Streaming (HTTP/2)',
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Stream Channel', VoltSharePubNub.channel),
          const SizedBox(height: 8),
          _buildDetailRow('Packets Received', '$_messageCount packets'),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Mode',
            data?.fallback == true
                ? 'Fallback Simulation (Active)'
                : 'Live Hardware Stream',
          ),
          if (data != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Last Telemetry Sync', data.timestamp),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingChassis(ThemeData theme) {
    return Container(
      height: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1914),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 18),
          const Text(
            'CONNECTING TO SMART METER STREAM...',
            style: TextStyle(
              color: Color(0xFF80CBC4),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 1;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
