import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_profile.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../data/admin_dashboard_models.dart';
import '../providers/admin_dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _selectedRange = '30d';

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(adminDashboardProvider);
    final profileState = ref.watch(currentProfileProvider);
    final profile = profileState.valueOrNull;

    return Scaffold(
      appBar: _buildAppBar(context, profile),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(adminDashboardProvider.notifier).refresh(rangeDays: _rangeToDays(_selectedRange)),
        child: switch (dashboardState) {
          AdminDashboardLoading() => const Center(child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator())),
          AdminDashboardSuccess(:final data) => _buildContent(context, data),
          AdminDashboardError(:final message, :final onRetry) => Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ])),
          ),
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserProfile? profile) {
    final firstName = profile?.fullName.trim().split(RegExp(r'\s+')).first ?? 'Admin';
    return AppBar(
      leading: Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary, size: 22)),
      title: Text('Admin', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      actions: [
        const NotificationBell(),
        Padding(padding: const EdgeInsets.only(right: 4), child: CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(firstName[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)))),
        PopupMenuButton<String>(
          icon: const Icon(Icons.arrow_drop_down),
          onSelected: (value) { if (value == 'logout') ref.read(authRepositoryProvider).signOut(); },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'profile', child: Text(firstName)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Logout')])),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AdminDashboardData data) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildGreeting(context, data),
        const SizedBox(height: 16),
        _buildRangeSelector(context),
        const SizedBox(height: 16),
        _buildKpiGrid(context, data.metrics),
        const SizedBox(height: 20),
        _buildExtendedKpiGrid(context, data.metrics),
        const SizedBox(height: 20),
        _buildEnergyChart(context, data),
        const SizedBox(height: 20),
        _buildMarketplaceSummary(context, data.marketplaceSummary),
        const SizedBox(height: 20),
        _buildRecentActivities(context, data.recentActivities),
      ]),
    );
  }

  Widget _buildGreeting(BuildContext context, AdminDashboardData data) {
    final firstName = ref.watch(currentProfileProvider).valueOrNull?.fullName.trim().split(RegExp(r'\s+')).first ?? 'Admin';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Welcome back, $firstName', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text('Admin Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text('Overview of VoltShare platform', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }

  Widget _buildRangeSelector(BuildContext context) {
    final ranges = ['1d', '7d', '30d', '90d'];
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      for (final range in ranges) ...[
        ChoiceChip(label: Text(_rangeLabel(range)), selected: _selectedRange == range,
          onSelected: (selected) { if (selected) { setState(() => _selectedRange = range); ref.read(adminDashboardProvider.notifier).refresh(rangeDays: _rangeToDays(range)); }}, showCheckmark: false),
        const SizedBox(width: 8),
      ],
    ]));
  }

  String _rangeLabel(String range) => switch (range) { '1d' => 'Today', '7d' => '7 days', '30d' => '30 days', '90d' => '90 days', _ => range };
  int _rangeToDays(String range) => switch (range) { '1d' => 1, '7d' => 7, '30d' => 30, '90d' => 90, _ => 30 };

  Widget _buildKpiGrid(BuildContext context, AdminMetrics metrics) {
    final cards = [
      _KpiCardData(icon: Icons.people_outline, title: 'Total Users', value: '${metrics.totalUsers}', trend: metrics.totalUsersTrend, trendIsGood: true),
      _KpiCardData(icon: Icons.bolt_outlined, title: 'Energy Traded', value: formatEnergyCompact(metrics.energyTradedKwh), trend: metrics.energyTradedTrend, trendIsGood: true),
      _KpiCardData(icon: Icons.payments_outlined, title: 'Total Revenue', value: formatIndianCurrency(metrics.totalRevenue), trend: metrics.revenueTrend, trendIsGood: true),
      _KpiCardData(icon: Icons.inventory_2_outlined, title: 'Active Listings', value: '${metrics.activeListings}', trend: metrics.listingsTrend, trendIsGood: true),
      _KpiCardData(icon: Icons.forum_outlined, title: 'Pending Disputes', value: '${metrics.pendingDisputes}', trend: metrics.disputesTrend, trendIsGood: false),
    ];
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final card in cards) SizedBox(width: _calcCardWidth(context), child: _KpiCard(card: card)),
    ]);
  }

  Widget _buildExtendedKpiGrid(BuildContext context, AdminMetrics metrics) {
    final cards = [
      _KpiCardData(icon: Icons.verified_user_outlined, title: 'Verified Consumers', value: '${metrics.verifiedConsumers}', trend: 0, trendIsGood: true),
      _KpiCardData(icon: Icons.verified_outlined, title: 'Verified Producers', value: '${metrics.verifiedProducers}', trend: 0, trendIsGood: true),
      _KpiCardData(icon: Icons.hourglass_empty_outlined, title: 'Pending KYC', value: '${metrics.pendingKyc}', trend: 0, trendIsGood: false),
      _KpiCardData(icon: Icons.shopping_cart_outlined, title: 'Sold Out Listings', value: '${metrics.soldOutListings}', trend: 0, trendIsGood: false),
      _KpiCardData(icon: Icons.energy_savings_leaf_outlined, title: 'Total Energy Sold', value: formatEnergyCompact(metrics.totalEnergySoldKwh), trend: 0, trendIsGood: true),
      _KpiCardData(icon: Icons.block_outlined, title: 'Suspended Users', value: '${metrics.suspendedUsers}', trend: 0, trendIsGood: false),
      _KpiCardData(icon: Icons.emergency_outlined, title: 'Emergency Requests', value: '${metrics.emergencyRequests}', trend: 0, trendIsGood: false),
      _KpiCardData(icon: Icons.support_agent_outlined, title: 'Support Tickets', value: '${metrics.supportTickets}', trend: 0, trendIsGood: false),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Platform KPIs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final card in cards) SizedBox(width: _calcCardWidth(context), child: _KpiCard(card: card)),
      ]),
    ]);
  }

  double _calcCardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 32;
    return width > 380 ? (width - 10) / 2 : width;
  }

  Widget _buildEnergyChart(BuildContext context, AdminDashboardData data) {
    final points = data.energySeries;
    return _SectionCard(icon: Icons.show_chart_outlined, title: 'Energy Overview', child: Column(children: [
      _CompactLegend(items: [_LegendItem('Traded', Theme.of(context).colorScheme.primary), _LegendItem('Generated', Colors.orange.shade600), _LegendItem('Consumed', Colors.teal.shade700)]),
      const SizedBox(height: 12),
      SizedBox(height: 200, child: points.isEmpty ? const Center(child: Text('No energy data available')) : AdminEnergyLineChart(points: points)),
    ]));
  }

  Widget _buildMarketplaceSummary(BuildContext context, MarketplaceSummaryData summary) {
    return _SectionCard(icon: Icons.storefront_outlined, title: 'Marketplace Summary', child: Column(children: [
      _KpiRow(label: 'Active Listings', value: '${summary.activeListings}'),
      _KpiRow(label: 'New Today', value: '${summary.newListingsToday}'),
      _KpiRow(label: 'Completed Trades', value: '${summary.completedTrades}'),
      _KpiRow(label: 'Cancelled', value: '${summary.cancelledListings}'),
    ]));
  }

  Widget _buildRecentActivities(BuildContext context, List<ActivityData> activities) {
    return _SectionCard(icon: Icons.history_outlined, title: 'Recent Activities', child: activities.isEmpty
      ? const Padding(padding: EdgeInsets.all(12), child: Text('No recent activities.'))
      : Column(children: activities.take(5).map((a) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_activityIcon(a.type), size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(a.title, style: const TextStyle(fontSize: 13))),
          Text(_formatShortDate(a.createdAt), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      )).toList()));
  }

  IconData _activityIcon(String type) => switch (type) { 'purchase' => Icons.shopping_bag_outlined, 'kyc' => Icons.verified_outlined, 'listing' => Icons.inventory_2_outlined, 'user' => Icons.person_outlined, _ => Icons.info_outlined };
  String _formatShortDate(DateTime dt) { final diff = DateTime.now().difference(dt); if (diff.inMinutes < 60) return '${diff.inMinutes}m'; if (diff.inHours < 24) return '${diff.inHours}h'; return '${diff.inDays}d'; }
}

class _KpiCardData {
  final IconData icon; final String title; final String value; final double trend; final bool trendIsGood;
  const _KpiCardData({required this.icon, required this.title, required this.value, required this.trend, required this.trendIsGood});
}

class _KpiCard extends StatelessWidget {
  final _KpiCardData card;
  const _KpiCard({required this.card});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
            child: Icon(card.icon, size: 20, color: theme.colorScheme.primary)),
          const Spacer(),
          if (card.trend != 0) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: (card.trendIsGood ? Colors.green : Colors.red).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('${card.trend >= 0 ? '+' : ''}${card.trend.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: card.trendIsGood ? Colors.green : Colors.red))),
        ]),
        const SizedBox(height: 10),
        Text(card.value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(card.title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
      ])),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final String label; final String value;
  const _KpiRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(fontSize: 13)), Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  ]));
}

class _SectionCard extends StatelessWidget {
  final IconData icon; final String title; final Widget child;
  const _SectionCard({required this.icon, required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 12), child,
      ])));
  }
}

class _CompactLegend extends StatelessWidget {
  final List<_LegendItem> items;
  const _CompactLegend({required this.items});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: items.map((item) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(item.label, style: const TextStyle(fontSize: 11)),
  ]))).toList());
}

class _LegendItem { final String label; final Color color; const _LegendItem(this.label, this.color); }

class AdminEnergyLineChart extends StatelessWidget {
  final List<EnergySeriesPoint> points;
  const AdminEnergyLineChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawHorizontalLine: true, drawVerticalLine: false,
        horizontalInterval: 25, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
      titlesData: FlTitlesData(show: true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (value, meta) {
        final idx = value.toInt();
        if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(top: 4), child: Text(points[idx].label.length > 3 ? points[idx].label.substring(0, 3) : points[idx].label, style: const TextStyle(fontSize: 9)));
      })), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
        return Text('${value.toInt()}', style: const TextStyle(fontSize: 9));
      })), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: math.max((points.length - 1).toDouble(), 1.0),
      minY: 0,
      maxY: math.max(
        points.map((p) => [p.tradedKwh, p.generatedKwh, p.consumedKwh].reduce((a, b) => a > b ? a : b)).reduce((a, b) => a > b ? a : b) * 1.2,
        10.0,
      ),
      lineBarsData: [
        _line(points.map((p) => FlSpot(points.indexOf(p).toDouble(), p.tradedKwh)).toList(), Theme.of(context).colorScheme.primary),
        _line(points.map((p) => FlSpot(points.indexOf(p).toDouble(), p.generatedKwh)).toList(), Colors.orange.shade600),
        _line(points.map((p) => FlSpot(points.indexOf(p).toDouble(), p.consumedKwh)).toList(), Colors.teal.shade700),
      ],
      lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)} kWh', TextStyle(color: s.bar.color, fontWeight: FontWeight.w600, fontSize: 12))).toList())),
    ));
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 2,
    dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.05)));
}
