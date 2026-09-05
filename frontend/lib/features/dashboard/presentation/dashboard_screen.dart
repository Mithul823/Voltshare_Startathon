import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart'
    show PrimaryActionButton, ResponsivePage, SecondaryActionButton;
import '../../../core/errors/app_exception.dart';
import '../../admin_dashboard/presentation/admin_dashboard_screen.dart';
import '../../ai/presentation/ai_widgets.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../domain/dashboard_snapshot.dart' show DashboardSnapshot;
import '../providers/dashboard_provider.dart';
import 'role_dashboard_page.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/dashboard_state_views.dart';
import '../widgets/energy_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentProfileProvider);
    final role = profileState.valueOrNull?.role;

    // Admin role gets the full admin dashboard
    if (role == UserRole.admin) {
      return const AdminDashboardScreen();
    }

    return const _UserDashboardScreen();
  }
}

class _UserDashboardScreen extends ConsumerStatefulWidget {
  const _UserDashboardScreen();

  @override
  ConsumerState<_UserDashboardScreen> createState() =>
      _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<_UserDashboardScreen> {
  EnergyChartType _chartType = EnergyChartType.solar;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final snapshot = dashboard.valueOrNull;
    final profileState = ref.watch(currentProfileProvider);

    if (dashboard.isLoading && snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (dashboard.hasError && snapshot == null) {
      final errorMessage = dashboard.error is DashboardError
          ? (dashboard.error as DashboardError).userMessage
          : 'Energy readings are unavailable right now.';
      return Scaffold(
        body: SafeArea(
          child: DashboardErrorView(
            message: errorMessage,
            onRetry: () => ref.read(dashboardProvider.notifier).retry(),
          ),
        ),
      );
    }

    if (snapshot == null) {
      return Scaffold(
        body: SafeArea(
          child: DashboardEmptyView(
            onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
        ),
      );
    }

    if (profileState.isLoading && profileState.valueOrNull == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profileState.hasError) {
      return Scaffold(
        body: SafeArea(
          child: _RoleLoadError(
            message: 'Profile unavailable: ${profileState.error}',
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        ),
      );
    }

    final profile = profileState.valueOrNull;
    if (profile == null) {
      return Scaffold(
        body: SafeArea(
          child: _RoleLoadError(
            message: 'No backend profile found for this session.',
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        ),
      );
    }

    if (!profile.isActive) {
      return const Scaffold(body: SafeArea(child: _InactiveAccountView()));
    }

    final accessDenied = _hasAccessDeniedQuery(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dashboard.isLoading) const LinearProgressIndicator(),
              if (accessDenied) ...[
                const _AccessDeniedBanner(),
                const SizedBox(height: 14),
              ],
              RoleDashboardPage(
                profile: profile,
                snapshot: snapshot,
                onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
              ),
              const SizedBox(height: 18),
              _ChartSection(
                snapshot: snapshot,
                chartType: _chartType,
                onChartTypeChanged: (type) => setState(() => _chartType = type),
              ),
              const SizedBox(height: 18),
              AiInsightCard(
                insights: snapshot.aiInsights,
                onAction: () => context.go(AppRoutes.marketplace),
              ),
              const SizedBox(height: 18),
              RoleAiPanel(roleName: profile.role.name),
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasAccessDeniedQuery(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.queryParameters['accessDenied'] == '1';
  } catch (_) {
    return false;
  }
}

class _AccessDeniedBanner extends StatelessWidget {
  const _AccessDeniedBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.block_outlined, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Access denied. Your role cannot open that page.',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleLoadError extends ConsumerStatefulWidget {
  const _RoleLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  ConsumerState<_RoleLoadError> createState() => _RoleLoadErrorState();
}

class _RoleLoadErrorState extends ConsumerState<_RoleLoadError> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account role unavailable',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(widget.message),
          const SizedBox(height: 18),
          PrimaryActionButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: widget.onRetry,
          ),
          const SizedBox(height: 10),
          SecondaryActionButton(
            label: _isSigningOut ? 'Logging out...' : 'Logout',
            icon: Icons.logout,
            onPressed: _isSigningOut ? null : _logout,
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AppException {
      // Keep the diagnostic error visible; logout failures are rare in this fallback.
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }
}

class _InactiveAccountView extends StatelessWidget {
  const _InactiveAccountView();

  @override
  Widget build(BuildContext context) {
    return const ResponsivePage(
      child: Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Account inactive'),
          subtitle: Text(
            'This account cannot enter VoltShare until an administrator reactivates it.',
          ),
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.snapshot,
    required this.chartType,
    required this.onChartTypeChanged,
  });

  final DashboardSnapshot snapshot;
  final EnergyChartType chartType;
  final ValueChanged<EnergyChartType> onChartTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<EnergyChartType>(
                segments: const [
                  ButtonSegment(
                    value: EnergyChartType.solar,
                    label: Text('Solar'),
                    icon: Icon(Icons.wb_sunny_outlined),
                  ),
                  ButtonSegment(
                    value: EnergyChartType.consumption,
                    label: Text('Consumption'),
                    icon: Icon(Icons.home_outlined),
                  ),
                ],
                selected: {chartType},
                onSelectionChanged: (selected) =>
                    onChartTypeChanged(selected.first),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.electric_meter_outlined),
              tooltip: 'Live Smart Meter',
              onPressed: () => context.push(AppRoutes.smartMeter),
            ),
          ],
        ),
        const SizedBox(height: 12),
        EnergyChart(
          title: chartType == EnergyChartType.solar
              ? 'Solar generation'
              : 'Energy consumption',
          points: chartType == EnergyChartType.solar
              ? snapshot.solarHistory
              : snapshot.consumptionHistory,
          type: chartType,
        ),
      ],
    );
  }
}
