import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../../wallet/domain/wallet.dart';
import '../providers/escrow_provider.dart';

class ResolutionSummaryScreen extends ConsumerWidget {
  const ResolutionSummaryScreen({required this.escrowId, super.key});

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
                title: 'Resolution summary',
                fallbackRoute: AppRoutes.escrowDetails(escrowId),
              ),
              const SizedBox(height: 16),
              Text(
                'Current status: ${escrow.status.label}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Expected: ${escrow.energyQuantityKwh.toStringAsFixed(1)} kWh',
              ),
              Text(
                'Delivered: ${escrow.deliveredEnergyKwh.toStringAsFixed(1)} kWh',
              ),
              Text('Held: ${formatPaise(escrow.totalHeldPaise)}'),
              if (escrow.failureReason != null)
                Text('Reason: ${escrow.failureReason}'),
              const SizedBox(height: 12),
              const Text(
                'This deterministic demo policy may release funds, refund funds, or freeze the escrow for review.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
