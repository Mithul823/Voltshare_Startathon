import 'package:flutter/material.dart';

import '../../wallet/domain/wallet.dart';
import '../domain/escrow_settlement.dart';

class SettlementBreakdownCard extends StatelessWidget {
  const SettlementBreakdownCard({required this.result, super.key});

  final EscrowSettlementResult result;

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
              'Settlement breakdown',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _row('Seller release', formatPaise(result.sellerReleasePaise)),
            _row('Buyer refund', formatPaise(result.buyerRefundPaise)),
            _row('Platform fee', formatPaise(result.platformFeeRetainedPaise)),
            _row('Frozen amount', formatPaise(result.frozenPaise)),
            const Divider(),
            _row('Money conserved', result.conservesMoney ? 'Yes' : 'Review'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
