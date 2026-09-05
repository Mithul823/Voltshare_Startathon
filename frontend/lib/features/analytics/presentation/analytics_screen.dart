import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/widgets/energy_chart.dart';
import '../data/mock_history_data.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final snapshot = dashboard.valueOrNull;

    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'History',
              fallbackRoute: AppRoutes.dashboard,
            ),
            const SizedBox(height: 16),
            if (snapshot == null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly energy trend'),
                      SizedBox(height: 12),
                      WeeklyEnergyChart(values: weeklyEnergyHistory),
                    ],
                  ),
                ),
              )
            else ...[
              EnergyChart(
                title: 'Generation trend',
                points: snapshot.solarHistory,
                type: EnergyChartType.solar,
              ),
              const SizedBox(height: 12),
              EnergyChart(
                title: 'Consumption trend',
                points: snapshot.consumptionHistory,
                type: EnergyChartType.consumption,
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'Recent energy activity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            for (final transaction in mockEnergyTransactions)
              TransactionTimelineItem(
                title: transaction.title,
                date: transaction.date,
                amount:
                    '${transaction.isCredit ? '+' : '-'}Rs ${transaction.amount.toStringAsFixed(2)}',
                isCredit: transaction.isCredit,
              ),
          ],
        ),
      ),
    );
  }
}
