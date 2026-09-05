import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../domain/wallet.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_widgets.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../realtime/providers/realtime_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _isBalanceHidden = false;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletControllerProvider);
    ref.watch(webSocketProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletControllerProvider.notifier).refresh(),
        child: ResponsivePage(
          child: walletState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorMessage(message: error.toString()),
            data: (state) {
              final latest = state.transactions.take(5).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppPageHeader(
                    title: 'Wallet',
                    subtitle: 'Simulated balances, earnings, and settlements',
                    fallbackRoute: AppRoutes.dashboard,
                    actions: [NotificationBell()],
                  ),
                  const SizedBox(height: 16),
                  WalletBalanceCard(
                    wallet: state.wallet,
                    isHidden: _isBalanceHidden,
                    onToggleHidden: () =>
                        setState(() => _isBalanceHidden = !_isBalanceHidden),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Demo only. No real money, banking, UPI, or payment gateway is connected.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.addFunds),
                        icon: const Icon(Icons.add_card),
                        label: const Text('Add Funds'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.withdraw),
                        icon: const Icon(Icons.account_balance_outlined),
                        label: const Text('Withdraw'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.walletActivity),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Activity'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.escrowDebug),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Escrow Debug'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 620;
                      final metrics = _MetricsGrid(state: state);
                      final chart = _ChartCard(state: state);
                      if (!wide) {
                        return Column(
                          children: [
                            metrics,
                            const SizedBox(height: 12),
                            chart,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: metrics),
                          const SizedBox(width: 12),
                          Expanded(child: chart),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent transactions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.walletActivity),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (latest.isEmpty)
                    const Text('No wallet transactions yet.')
                  else
                    for (final transaction in latest)
                      TransactionListItem(
                        transaction: transaction,
                        onTap: () => context.push(
                          AppRoutes.transactionDetails(transaction.id),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.state});

  final WalletState state;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.12,
      children: [
        WalletSummaryCard(
          title: 'Total earned',
          value: formatPaise(state.wallet.totalEarnedPaise),
          icon: Icons.trending_up,
        ),
        WalletSummaryCard(
          title: 'Total spent',
          value: formatPaise(state.wallet.totalSpentPaise),
          icon: Icons.trending_down,
        ),
        WalletSummaryCard(
          title: 'Energy bought',
          value: '${state.summary.energyBoughtKwh.toStringAsFixed(1)} kWh',
          icon: Icons.shopping_bag_outlined,
        ),
        WalletSummaryCard(
          title: 'Energy sold',
          value: '${state.summary.energySoldKwh.toStringAsFixed(1)} kWh',
          icon: Icons.bolt,
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.state});

  final WalletState state;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            EarningsChart(summary: state.summary),
          ],
        ),
      ),
    );
  }
}
