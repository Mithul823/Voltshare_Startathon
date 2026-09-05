import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../../wallet/domain/wallet.dart';
import '../providers/escrow_provider.dart';

class DefaultCaseDetailsScreen extends ConsumerWidget {
  const DefaultCaseDetailsScreen({required this.caseId, super.key});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseValue = ref.watch(defaultCaseProvider(caseId));
    return Scaffold(
      body: ResponsivePage(
        child: caseValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorMessage(message: error.toString()),
          data: (item) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                title: 'Default case',
                subtitle: item.id,
                fallbackRoute: AppRoutes.wallet,
              ),
              const SizedBox(height: 16),
              Text('Reason: ${item.reason.label}'),
              Text('Status: ${item.status.label}'),
              Text('Resolution: ${item.resolution.label}'),
              Text(
                'Financial impact: ${formatPaise(item.financialImpactPaise)}',
              ),
              Text('Evidence: ${item.evidenceReferences.join(', ')}'),
              const SizedBox(height: 12),
              Text(item.notes),
            ],
          ),
        ),
      ),
    );
  }
}
