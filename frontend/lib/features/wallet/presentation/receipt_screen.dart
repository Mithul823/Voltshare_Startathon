import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../providers/transaction_history_provider.dart';
import '../widgets/wallet_widgets.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionValue = ref.watch(
      walletTransactionProvider(transactionId),
    );
    return Scaffold(
      body: ResponsivePage(
        child: transactionValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorMessage(message: error.toString()),
          data: (transaction) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPageHeader(
                  title: 'Receipt',
                  fallbackRoute: AppRoutes.walletActivity,
                ),
                const SizedBox(height: 16),
                ReceiptSection(transaction: transaction),
                const SizedBox(height: 18),
                PrimaryActionButton(
                  label: 'Copy reference',
                  icon: Icons.copy_outlined,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: transaction.reference),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reference copied.')),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SecondaryActionButton(
                  label: 'Share placeholder',
                  icon: Icons.ios_share_outlined,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sharing receipts is a placeholder in this phase.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SecondaryActionButton(
                  label: 'Download placeholder',
                  icon: Icons.download_outlined,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'PDF downloads are not enabled in this phase.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
