import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../providers/escrow_provider.dart';

class RaiseDisputeScreen extends ConsumerStatefulWidget {
  const RaiseDisputeScreen({required this.escrowId, super.key});

  final String escrowId;

  @override
  ConsumerState<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends ConsumerState<RaiseDisputeScreen> {
  final _description = TextEditingController(
    text: 'Energy delivery looks incorrect.',
  );
  String _category = 'Incorrect delivered quantity';

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Raise dispute',
              subtitle: 'Deterministic mock review only',
              fallbackRoute: AppRoutes.escrowDetails(widget.escrowId),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(
                  value: 'Energy not delivered',
                  child: Text('Energy not delivered'),
                ),
                DropdownMenuItem(
                  value: 'Incorrect delivered quantity',
                  child: Text('Incorrect delivered quantity'),
                ),
                DropdownMenuItem(
                  value: 'Meter mismatch',
                  child: Text('Meter mismatch'),
                ),
                DropdownMenuItem(
                  value: 'Unexpected deduction',
                  child: Text('Unexpected deduction'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 18),
            PrimaryActionButton(
              label: 'Submit mock dispute',
              icon: Icons.report_problem_outlined,
              onPressed: () async {
                final dispute = await ref
                    .read(escrowControllerProvider.notifier)
                    .raiseDispute(
                      escrowId: widget.escrowId,
                      raisedBy: 'current-user',
                      category: _category,
                      description: _description.text,
                    );
                if (context.mounted && dispute != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${dispute.status.label}: ${dispute.id}'),
                    ),
                  );
                  context.go(AppRoutes.escrowDetails(widget.escrowId));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
