import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/wallet.dart';
import '../domain/wallet_summary.dart';
import '../domain/wallet_transaction.dart';

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    required this.wallet,
    required this.isHidden,
    required this.onToggleHidden,
    super.key,
  });

  final Wallet wallet;
  final bool isHidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = isHidden
        ? 'Rs •••••'
        : formatPaise(wallet.availableBalancePaise, currency: wallet.currency);
    return Semantics(
      label: 'Simulated wallet balance $balance',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Simulated wallet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isHidden ? 'Show balance' : 'Hide balance',
                    onPressed: onToggleHidden,
                    color: colorScheme.onPrimary,
                    icon: Icon(
                      isHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                balance,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pending: ${isHidden ? 'Rs •••••' : formatPaise(wallet.pendingBalancePaise, currency: wallet.currency)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Escrow held: ${isHidden ? 'Rs *****' : formatPaise(wallet.escrowHeldBalancePaise, currency: wallet.currency)}',
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${TimeOfDay.fromDateTime(wallet.updatedAt).format(context)}',
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;

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
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    required this.transaction,
    required this.onTap,
    super.key,
  });

  final WalletTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCredit = switch (transaction.type) {
      WalletTransactionType.energySale ||
      WalletTransactionType.walletTopUp ||
      WalletTransactionType.refund ||
      WalletTransactionType.reward => true,
      _ => false,
    };
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        minLeadingWidth: 36,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(_iconFor(transaction.type), color: colorScheme.primary),
        ),
        title: Text(transaction.type.label),
        subtitle: Text(
          '${transaction.status.label} • ${transaction.reference}',
        ),
        trailing: Semantics(
          label: 'Transaction amount ${formatPaise(transaction.amountPaise)}',
          child: Text(
            '${isCredit ? '+' : '-'}${formatPaise(transaction.amountPaise)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isCredit ? colorScheme.primary : colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionFilterBar extends StatelessWidget {
  const TransactionFilterBar({
    required this.query,
    required this.onChanged,
    super.key,
  });

  final TransactionHistoryQuery query;
  final ValueChanged<TransactionHistoryQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search transactions',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => onChanged(query.copyWith(search: value)),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in TransactionFilter.values) ...[
                FilterChip(
                  label: Text(filter.label),
                  selected: query.filter == filter,
                  onSelected: (_) => onChanged(query.copyWith(filter: filter)),
                  showCheckmark: false,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<TransactionSort>(
          initialValue: query.sort,
          decoration: const InputDecoration(labelText: 'Sort'),
          items: [
            for (final sort in TransactionSort.values)
              DropdownMenuItem(value: sort, child: Text(sort.label)),
          ],
          onChanged: (sort) {
            if (sort != null) {
              onChanged(query.copyWith(sort: sort));
            }
          },
        ),
      ],
    );
  }
}

class EarningsChart extends StatelessWidget {
  const EarningsChart({required this.summary, super.key});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final income = summary.incomeThisWeekPaise / 100;
    final spending = summary.spendingThisWeekPaise / 100;
    final maxY = [income, spending, 100.0].reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.25,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value == 0 ? 'Income' : 'Spent');
                },
              ),
            ),
          ),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: income,
                  color: colorScheme.primary,
                  width: 32,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: spending,
                  color: colorScheme.tertiary,
                  width: 32,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptSection extends StatelessWidget {
  const ReceiptSection({required this.transaction, super.key});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VoltShare Receipt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _line('Reference', transaction.reference),
            _line('Type', transaction.type.label),
            _line('Status', transaction.status.label),
            if (transaction.counterpartyName != null)
              _line('Counterparty', transaction.counterpartyName!),
            if (transaction.energyQuantityKwh != null)
              _line(
                'Energy',
                '${transaction.energyQuantityKwh!.toStringAsFixed(1)} kWh',
              ),
            if (transaction.unitPricePaise != null)
              _line(
                'Unit price',
                '${formatPaise(transaction.unitPricePaise!)}/kWh',
              ),
            _line('Subtotal', formatPaise(transaction.subtotalPaise)),
            _line('Platform fee', formatPaise(transaction.platformFeePaise)),
            _line('Total', formatPaise(transaction.amountPaise)),
            const SizedBox(height: 12),
            const Text(
              'This is a simulated receipt for the VoltShare hackathon wallet.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(WalletTransactionType type) {
  return switch (type) {
    WalletTransactionType.energyPurchase => Icons.shopping_bag_outlined,
    WalletTransactionType.energySale => Icons.bolt,
    WalletTransactionType.platformFee => Icons.percent,
    WalletTransactionType.walletTopUp => Icons.add_card,
    WalletTransactionType.withdrawal => Icons.account_balance_outlined,
    WalletTransactionType.refund => Icons.replay,
    WalletTransactionType.adjustment => Icons.tune,
    WalletTransactionType.reward => Icons.emoji_events_outlined,
  };
}
