import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../providers/escrow_provider.dart';
import '../widgets/settlement_breakdown_card.dart';

class DeliveryVerificationScreen extends ConsumerStatefulWidget {
  const DeliveryVerificationScreen({required this.escrowId, super.key});

  final String escrowId;

  @override
  ConsumerState<DeliveryVerificationScreen> createState() =>
      _DeliveryVerificationScreenState();
}

class _DeliveryVerificationScreenState
    extends ConsumerState<DeliveryVerificationScreen> {
  final _delivered = TextEditingController(text: '1.0');
  final _meter = TextEditingController(text: 'MTR-DEMO-001');
  bool _integrityOk = true;

  @override
  void dispose() {
    _delivered.dispose();
    _meter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(escrowControllerProvider);
    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Mock Delivery Verification',
              fallbackRoute: AppRoutes.escrowDetails(widget.escrowId),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _delivered,
              decoration: const InputDecoration(
                labelText: 'Delivered energy kWh',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meter,
              decoration: const InputDecoration(labelText: 'Meter identifier'),
            ),
            SwitchListTile(
              title: const Text('Integrity check passed'),
              value: _integrityOk,
              onChanged: (value) => setState(() => _integrityOk = value),
            ),
            if (state.hasError)
              Text(
                state.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (state.valueOrNull != null) ...[
              const SizedBox(height: 12),
              Text(
                'Settlement result: ${state.valueOrNull!.escrow.status.label}',
              ),
              const SizedBox(height: 8),
              SettlementBreakdownCard(result: state.valueOrNull!),
            ],
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: state.isLoading ? 'Verifying...' : 'Run mock verification',
              icon: Icons.task_alt,
              onPressed: state.isLoading
                  ? null
                  : () async {
                      final result = await ref
                          .read(escrowControllerProvider.notifier)
                          .verifyAndSettle(
                            escrowId: widget.escrowId,
                            deliveredKwh: double.tryParse(_delivered.text) ?? 0,
                            integrityOk: _integrityOk,
                            meterIdentifier: _meter.text,
                          );
                      if (context.mounted && result != null) {
                        context.push(
                          AppRoutes.resolutionSummary(widget.escrowId),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
