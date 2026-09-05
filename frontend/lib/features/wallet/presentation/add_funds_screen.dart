import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../domain/wallet.dart';
import '../domain/wallet_transaction.dart';
import '../providers/wallet_top_up_provider.dart';

class AddFundsScreen extends ConsumerStatefulWidget {
  const AddFundsScreen({super.key});

  @override
  ConsumerState<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends ConsumerState<AddFundsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '500');
  final _label = TextEditingController(text: 'Demo balance');
  FundingMethod _method = FundingMethod.demoBalance;

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletTopUpControllerProvider);
    final success = state.valueOrNull;
    return Scaffold(
      body: ResponsivePage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Add funds',
                subtitle: 'Simulated wallet funding only',
                fallbackRoute: AppRoutes.wallet,
              ),
              const SizedBox(height: 16),
              const Text(
                'No real UPI, debit card, or bank credentials are collected.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rs ',
                ),
                keyboardType: TextInputType.number,
                validator: _positiveAmount,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FundingMethod>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Funding method'),
                items: [
                  for (final method in FundingMethod.values)
                    DropdownMenuItem(value: method, child: Text(method.label)),
                ],
                onChanged: (method) =>
                    setState(() => _method = method ?? _method),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'Optional label'),
              ),
              if (state.hasError) ...[
                const SizedBox(height: 12),
                ErrorMessage(message: state.error.toString()),
              ],
              if (success != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Simulated top-up complete: ${formatPaise(success.amountPaise)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: state.isLoading
                    ? 'Adding...'
                    : 'Confirm simulated top-up',
                icon: Icons.add_card,
                onPressed: state.isLoading ? null : _submit,
              ),
              const SizedBox(height: 10),
              SecondaryActionButton(
                label: 'Return to wallet',
                icon: Icons.account_balance_wallet_outlined,
                onPressed: () => context.go(AppRoutes.wallet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref
        .read(walletTopUpControllerProvider.notifier)
        .addFunds(
          amountPaise: rupeesToPaise(double.parse(_amount.text)),
          method: _method,
          label: _label.text,
        );
  }

  String? _positiveAmount(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Enter a positive amount';
    }
    return null;
  }
}
