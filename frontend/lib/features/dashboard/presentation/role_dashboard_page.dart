import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart' show PrimaryActionButton;
import '../../authentication/domain/user_profile.dart';
import '../../authentication/domain/user_role.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../realtime/providers/realtime_provider.dart';
import '../data/dashboard_mock_repository.dart';
import '../domain/dashboard_snapshot.dart' hide BatteryStatus;
import '../widgets/battery_status.dart';
import '../widgets/energy_gauge.dart';
import '../widgets/metric_card.dart';

class RoleDashboardPage extends StatelessWidget {
  const RoleDashboardPage({
    required this.profile,
    required this.snapshot,
    required this.onRefresh,
    super.key,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoleHeader(profile: profile, snapshot: snapshot, onRefresh: onRefresh),
        const SizedBox(height: 18),
        switch (profile.role) {
          UserRole.consumer => ConsumerDashboard(
            profile: profile,
            snapshot: snapshot,
          ),
          UserRole.producer => ProducerDashboard(
            profile: profile,
            snapshot: snapshot,
          ),
          UserRole.prosumer => ProsumerDashboard(
            profile: profile,
            snapshot: snapshot,
          ),
          UserRole.technician => TechnicianDashboard(
            profile: profile,
            snapshot: snapshot,
          ),
          UserRole.gridOperator => GridOperatorDashboard(
            profile: profile,
            snapshot: snapshot,
          ),
          UserRole.admin => AdminDashboard(
            profile: profile,
            snapshot: snapshot,
          ),
          UserRole.unsupported => const _RoleProblem(
            title: 'Unsupported role',
            message:
                'This account role is not supported by this app build. Contact an administrator.',
          ),
        },
      ],
    );
  }
}

class ConsumerDashboard extends StatelessWidget {
  const ConsumerDashboard({
    required this.profile,
    required this.snapshot,
    super.key,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _RoleLayout(
      lead: _EnergyPanel(
        value: '${snapshot.consumptionTodayKwh.toStringAsFixed(1)} kWh',
        label: 'Consumed today',
        progress: snapshot.consumptionTodayKwh / 28,
        battery: snapshot,
        actions: [
          _Action(
            'Buy Energy',
            Icons.shopping_bag_outlined,
            () => context.go(AppRoutes.marketplace),
          ),
          _Action(
            'View Purchases',
            Icons.receipt_long_outlined,
            () => context.go(AppRoutes.purchases),
          ),
          _Action(
            'Add Funds',
            Icons.add_card_outlined,
            () => context.go(AppRoutes.addFunds),
          ),
        ],
      ),
      metrics: [
        _Metric(
          "Today's consumption",
          '${snapshot.consumptionTodayKwh.toStringAsFixed(1)} kWh',
          Icons.home_outlined,
        ),
        _Metric(
          "Today's spending",
          'Rs ${(snapshot.consumptionTodayKwh * 9.4).toStringAsFixed(0)}',
          Icons.payments_outlined,
        ),
        _Metric('Recommended listings', 'Available', Icons.storefront_outlined),
        _Metric(
          'Battery',
          '${snapshot.batteryPercentage}%',
          Icons.battery_5_bar_outlined,
        ),
        _Metric(
          'Carbon saved',
          '${snapshot.co2AvoidedKg.toStringAsFixed(1)} kg',
          Icons.eco_outlined,
        ),
        _Metric(
          'Recent purchases',
          'Development data',
          Icons.shopping_cart_outlined,
        ),
      ],
    );
  }
}

class ProducerDashboard extends StatelessWidget {
  const ProducerDashboard({
    required this.profile,
    required this.snapshot,
    super.key,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _RoleLayout(
      lead: _EnergyPanel(
        value: '${snapshot.solarGenerationTodayKwh.toStringAsFixed(1)} kWh',
        label: 'Generated today',
        progress:
            snapshot.solarGenerationTodayKwh /
            DashboardMockRepository.dailyGenerationTargetKwh,
        battery: snapshot,
        actions: [
          _Action(
            'Create Listing',
            Icons.add_circle_outline,
            () => context.go(AppRoutes.createListing),
          ),
          _Action(
            'Manage Listings',
            Icons.inventory_2_outlined,
            () => context.go(AppRoutes.myListings),
          ),
          _Action(
            'View Sales',
            Icons.receipt_long_outlined,
            () => context.go(AppRoutes.sales),
          ),
          _Action(
            'Withdraw Earnings',
            Icons.account_balance_outlined,
            () => context.go(AppRoutes.withdraw),
          ),
        ],
      ),
      metrics: [
        _Metric(
          'Current generation',
          '${snapshot.currentSolarPowerKw.toStringAsFixed(1)} kW',
          Icons.wb_sunny_outlined,
        ),
        _Metric(
          'Available energy',
          '${snapshot.availableToSellKwh.toStringAsFixed(1)} kWh',
          Icons.flash_on_outlined,
        ),
        _Metric(
          'Exported energy',
          '${(snapshot.solarGenerationTodayKwh - snapshot.consumptionTodayKwh).clamp(0, 999).toStringAsFixed(1)} kWh',
          Icons.upload_outlined,
        ),
        _Metric(
          'Active listings',
          'Development data',
          Icons.inventory_2_outlined,
        ),
        _Metric(
          'Pending settlements',
          'Development data',
          Icons.lock_clock_outlined,
        ),
        _Metric(
          'Today earnings',
          'Rs ${(snapshot.availableToSellKwh * 8.2).toStringAsFixed(0)}',
          Icons.trending_up_outlined,
        ),
        _Metric(
          'Monthly earnings',
          'Rs ${(snapshot.availableToSellKwh * 8.2 * 30).toStringAsFixed(0)}',
          Icons.calendar_month_outlined,
        ),
        _Metric(
          'Production efficiency',
          '${snapshot.sustainabilityScore}%',
          Icons.speed_outlined,
        ),
      ],
    );
  }
}

class ProsumerDashboard extends StatelessWidget {
  const ProsumerDashboard({
    required this.profile,
    required this.snapshot,
    super.key,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final net = snapshot.solarGenerationTodayKwh - snapshot.consumptionTodayKwh;
    return _RoleLayout(
      lead: _EnergyPanel(
        value: '${net.toStringAsFixed(1)} kWh',
        label: 'Net energy',
        progress: (net.abs() / DashboardMockRepository.dailyGenerationTargetKwh)
            .clamp(0, 1),
        battery: snapshot,
        actions: [
          _Action(
            'Buy Energy',
            Icons.shopping_bag_outlined,
            () => context.go(AppRoutes.marketplace),
          ),
          _Action(
            'Sell Energy',
            Icons.bolt,
            () => context.go(AppRoutes.createListing),
          ),
          _Action(
            'View Trade History',
            Icons.swap_horiz_outlined,
            () => context.go(AppRoutes.trade),
          ),
        ],
      ),
      metrics: [
        _Metric(
          'Generation',
          '${snapshot.solarGenerationTodayKwh.toStringAsFixed(1)} kWh',
          Icons.wb_sunny_outlined,
        ),
        _Metric(
          'Consumption',
          '${snapshot.consumptionTodayKwh.toStringAsFixed(1)} kWh',
          Icons.home_outlined,
        ),
        _Metric(
          'Grid import',
          '${net < 0 ? net.abs().toStringAsFixed(1) : '0.0'} kWh',
          Icons.download_outlined,
        ),
        _Metric(
          'Grid export',
          '${net > 0 ? net.toStringAsFixed(1) : '0.0'} kWh',
          Icons.upload_outlined,
        ),
        _Metric(
          'Sales',
          'Rs ${(snapshot.availableToSellKwh * 8.2).toStringAsFixed(0)}',
          Icons.trending_up_outlined,
        ),
        _Metric(
          'Purchases',
          'Rs ${(snapshot.consumptionTodayKwh * 9.4).toStringAsFixed(0)}',
          Icons.payments_outlined,
        ),
        _Metric(
          'Listings',
          '${snapshot.availableToSellKwh.toStringAsFixed(1)} kWh',
          Icons.inventory_2_outlined,
        ),
        _Metric(
          'Battery',
          '${snapshot.batteryPercentage}%',
          Icons.battery_5_bar_outlined,
        ),
        _Metric(
          'Carbon',
          '${snapshot.co2AvoidedKg.toStringAsFixed(1)} kg',
          Icons.eco_outlined,
        ),
      ],
    );
  }
}

class TechnicianDashboard extends StatelessWidget {
  const TechnicianDashboard({
    required this.profile,
    required this.snapshot,
    super.key,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _OperationalDashboard(
      title: 'Technician workspace',
      note:
          'Maintenance and diagnostic values are development data until operations APIs are connected.',
      actions: [
        _Action(
          'View Tasks',
          Icons.task_alt_outlined,
          () => context.go(AppRoutes.tasks),
        ),
        _Action(
          'Run Diagnostics',
          Icons.build_circle_outlined,
          () => context.go(AppRoutes.diagnostics),
        ),
        _Action(
          'Report Fault',
          Icons.report_outlined,
          () => context.go(AppRoutes.reportFault),
        ),
      ],
      metrics: [
        _Metric(
          'Assigned devices',
          'Development data',
          Icons.assignment_outlined,
        ),
        _Metric(
          'Maintenance',
          '${snapshot.batteryHealthPercentage}%',
          Icons.health_and_safety_outlined,
        ),
        _Metric('Faults', 'Development data', Icons.report_problem_outlined),
        _Metric(
          'Alerts',
          'Development data',
          Icons.notifications_active_outlined,
        ),
      ],
    );
  }
}

class GridOperatorDashboard extends StatelessWidget {
  const GridOperatorDashboard({
    required this.profile,
    required this.snapshot,
    super.key,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _OperationalDashboard(
      title: 'Grid operations',
      note:
          'Aggregate grid metrics are derived from the dashboard feed until grid APIs are connected.',
      actions: [
        _Action(
          'View Grid Status',
          Icons.grid_view_outlined,
          () => context.go(AppRoutes.gridStatus),
        ),
        _Action(
          'Inspect Alerts',
          Icons.report_problem_outlined,
          () => context.go(AppRoutes.alerts),
        ),
        _Action(
          'Review Suspended Listings',
          Icons.block_outlined,
          () => context.go(AppRoutes.suspendedListings),
        ),
      ],
      metrics: [
        _Metric(
          'Demand',
          '${snapshot.currentConsumptionKw.toStringAsFixed(1)} kW',
          Icons.electrical_services_outlined,
        ),
        _Metric(
          'Supply',
          '${snapshot.currentSolarPowerKw.toStringAsFixed(1)} kW',
          Icons.wb_sunny_outlined,
        ),
        _Metric(
          'Congestion',
          '${(snapshot.currentSolarPowerKw - snapshot.currentConsumptionKw).abs().toStringAsFixed(1)} kW',
          Icons.balance_outlined,
        ),
        _Metric(
          'Grid health',
          '${snapshot.sustainabilityScore}%',
          Icons.monitor_heart_outlined,
        ),
        _Metric('Alerts', 'Development data', Icons.report_problem_outlined),
      ],
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({
    required this.profile,
    required this.snapshot,
    super.key,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _OperationalDashboard(
      title: 'Admin overview',
      note:
          'Platform administration metrics use development mappings until admin APIs are connected.',
      actions: [
        _Action(
          'Manage Users',
          Icons.groups_outlined,
          () => context.go(AppRoutes.adminUsers),
        ),
        _Action(
          'Review Listings',
          Icons.inventory_2_outlined,
          () => context.go(AppRoutes.adminListings),
        ),
        _Action(
          'View Reports',
          Icons.assessment_outlined,
          () => context.go(AppRoutes.adminReports),
        ),
        _Action(
          'Open Security',
          Icons.security_outlined,
          () => context.go(AppRoutes.auditLogs),
        ),
      ],
      metrics: [
        _Metric('User statistics', 'Development data', Icons.groups_outlined),
        _Metric('Users', 'Development data', Icons.person_search_outlined),
        _Metric('Listings', 'Development data', Icons.inventory_2_outlined),
        _Metric('Reports', 'Ready', Icons.assessment_outlined),
        _Metric(
          'Transactions',
          'Development data',
          Icons.receipt_long_outlined,
        ),
        _Metric('Disputes', 'Development data', Icons.forum_outlined),
        _Metric('Security', 'Development data', Icons.security_outlined),
        _Metric(
          'Platform health',
          '${snapshot.sustainabilityScore}%',
          Icons.monitor_heart_outlined,
        ),
      ],
    );
  }
}

class _RoleHeader extends ConsumerWidget {
  const _RoleHeader({
    required this.profile,
    required this.snapshot,
    required this.onRefresh,
  });

  final UserProfile profile;
  final DashboardSnapshot snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = profile.fullName.trim().split(RegExp(r'\s+')).first;
    ref.watch(webSocketProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleFor(profile.role),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${firstName.isEmpty ? 'Hi' : 'Hi $firstName'} - ${_roleLabel(profile.role)}',
              ),
              const SizedBox(height: 8),
              Text(
                'Updated ${TimeOfDay.fromDateTime(snapshot.lastUpdated).format(context)}',
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        const NotificationBell(),
      ],
    );
  }

  String _titleFor(UserRole role) {
    return switch (role) {
      UserRole.consumer => 'Consumer Home',
      UserRole.producer => 'Producer Home',
      UserRole.prosumer => 'Prosumer Home',
      UserRole.technician => 'Technician Home',
      UserRole.gridOperator => 'Grid Operator Home',
      UserRole.admin => 'Admin Home',
      UserRole.unsupported => 'Account Role',
    };
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.gridOperator => 'Grid Operator',
      UserRole.unsupported => 'Unsupported Role',
      _ => role.name[0].toUpperCase() + role.name.substring(1),
    };
  }
}

class _RoleLayout extends StatelessWidget {
  const _RoleLayout({required this.lead, required this.metrics});

  final Widget lead;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _MetricGrid(metrics: metrics);
        if (constraints.maxWidth < 640) {
          return Column(children: [lead, const SizedBox(height: 18), grid]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: lead),
            const SizedBox(width: 18),
            Expanded(child: grid),
          ],
        );
      },
    );
  }
}

class _EnergyPanel extends StatelessWidget {
  const _EnergyPanel({
    required this.value,
    required this.label,
    required this.progress,
    required this.battery,
    required this.actions,
  });

  final String value;
  final String label;
  final double progress;
  final DashboardSnapshot battery;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            EnergyGauge(value: value, label: label, progress: progress),
            BatteryStatus(
              percentage: battery.batteryPercentage,
              healthPercentage: battery.batteryHealthPercentage,
              status: battery.batteryStatus,
            ),
            const SizedBox(height: 18),
            for (final action in actions) ...[
              PrimaryActionButton(
                label: action.label,
                icon: action.icon,
                onPressed: action.onPressed,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _OperationalDashboard extends StatelessWidget {
  const _OperationalDashboard({
    required this.title,
    required this.note,
    required this.actions,
    required this.metrics,
  });

  final String title;
  final String note;
  final List<_Action> actions;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(note),
                const SizedBox(height: 14),
                for (final action in actions) ...[
                  PrimaryActionButton(
                    label: action.label,
                    icon: action.icon,
                    onPressed: action.onPressed,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _MetricGrid(metrics: metrics),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        for (final metric in metrics)
          MetricCard(
            title: metric.title,
            value: metric.value,
            icon: metric.icon,
          ),
      ],
    );
  }
}

class _RoleProblem extends StatelessWidget {
  const _RoleProblem({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class _Action {
  const _Action(this.label, this.icon, this.onPressed);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}
