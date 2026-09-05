import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../domain/wallet_transaction.dart';
import '../providers/transaction_history_provider.dart';
import '../widgets/wallet_widgets.dart';

class WalletActivityScreen extends ConsumerWidget {
  const WalletActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(transactionHistoryQueryProvider);
    final transactions = ref.watch(transactionHistoryProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(transactionHistoryProvider),
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Wallet activity',
                fallbackRoute: AppRoutes.wallet,
              ),
              const SizedBox(height: 14),
              TransactionFilterBar(
                query: query,
                onChanged: (next) {
                  ref.read(transactionHistoryQueryProvider.notifier).state =
                      next;
                },
              ),
              const SizedBox(height: 16),
              transactions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorMessage(message: error.toString()),
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptyActivity();
                  }
                  final grouped = _groupByDate(items);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6),
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        for (final transaction in entry.value)
                          TransactionListItem(
                            transaction: transaction,
                            onTap: () => context.push(
                              AppRoutes.transactionDetails(transaction.id),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<WalletTransaction>> _groupByDate(
    List<WalletTransaction> transactions,
  ) {
    final grouped = <String, List<WalletTransaction>>{};
    for (final transaction in transactions) {
      final date = transaction.createdAt;
      final label = '${date.day}/${date.month}/${date.year}';
      grouped.putIfAbsent(label, () => []).add(transaction);
    }
    return grouped;
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text('No transactions match these filters.'),
          ],
        ),
      ),
    );
  }
}
