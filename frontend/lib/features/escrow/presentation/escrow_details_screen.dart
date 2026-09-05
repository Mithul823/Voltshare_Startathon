import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../../wallet/domain/wallet.dart';
import '../providers/escrow_provider.dart';

class EscrowDetailsScreen extends ConsumerWidget {
  const EscrowDetailsScreen({required this.escrowId, super.key});

  final String escrowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escrowValue = ref.watch(escrowDetailsProvider(escrowId));
    return Scaffold(
      body: ResponsivePage(
        child: escrowValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorMessage(message: error.toString()),
          data: (escrow) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                title: 'Simulated Escrow',
                subtitle: escrow.id,
                fallbackRoute: AppRoutes.wallet,
              ),
              const SizedBox(height: 16),
              _EscrowCard(
                rows: [
                  ('Status', escrow.status.label),
                  ('Held amount', formatPaise(escrow.amountHeldPaise)),
                  ('Platform fee', formatPaise(escrow.platformFeePaise)),
                  ('Total held', formatPaise(escrow.totalHeldPaise)),
                  (
                    'Expected energy',
                    '${escrow.energyQuantityKwh.toStringAsFixed(1)} kWh',
                  ),
                  (
                    'Delivered energy',
                    '${escrow.deliveredEnergyKwh.toStringAsFixed(1)} kWh',
                  ),
                  ('Delivery deadline', '${escrow.deliveryDeadline}'),
                  ('Integrity hash', escrow.integrityHash.substring(0, 12)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Demo escrow only. This is not a regulated escrow service or real money custody.',
              ),
              const SizedBox(height: 18),
              PrimaryActionButton(
                label: 'Verify delivery',
                icon: Icons.electric_meter_outlined,
                onPressed: () =>
                    context.push(AppRoutes.deliveryVerification(escrow.id)),
              ),
              const SizedBox(height: 10),
              SecondaryActionButton(
                label: 'Raise dispute',
                icon: Icons.report_problem_outlined,
                onPressed: () =>
                    context.push(AppRoutes.raiseDispute(escrow.id)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EscrowCard extends StatelessWidget {
  const _EscrowCard({required this.rows});

  final List<(String, String)> rows;

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
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1)),
                    Flexible(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
