import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../domain/wallet.dart';
import '../domain/withdrawal_request.dart';
import '../providers/wallet_provider.dart';
import '../providers/withdrawal_provider.dart';

class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '250');
  final _accountLabel = TextEditingController(text: 'Demo settlement account');
  WithdrawalMethod _method = WithdrawalMethod.demoSettlement;

  @override
  void dispose() {
    _amount.dispose();
    _accountLabel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletControllerProvider).valueOrNull?.wallet;
    final state = ref.watch(withdrawalControllerProvider);
    final request = state.valueOrNull;
    return Scaffold(
      body: ResponsivePage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Withdraw',
                subtitle: 'Create a simulated settlement request',
                fallbackRoute: AppRoutes.wallet,
              ),
              const SizedBox(height: 16),
              Text(
                'Available: ${wallet == null ? 'Loading...' : formatPaise(wallet.availableBalancePaise)}',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rs ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    _validateAmount(value, wallet?.availableBalancePaise),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WithdrawalMethod>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Withdrawal method',
                ),
                items: [
                  for (final method in WithdrawalMethod.values)
                    DropdownMenuItem(value: method, child: Text(method.label)),
                ],
                onChanged: (method) =>
                    setState(() => _method = method ?? _method),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountLabel,
                decoration: const InputDecoration(labelText: 'Account label'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Account label is required';
                  }
                  return null;
                },
              ),
              if (state.hasError) ...[
                const SizedBox(height: 12),
                ErrorMessage(message: state.error.toString()),
              ],
              if (request != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Withdrawal ${request.status.label.toLowerCase()}: ${formatPaise(request.amountPaise)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(withdrawalControllerProvider.notifier)
                      .completePending(),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Debug complete settlement'),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: state.isLoading
                    ? 'Requesting...'
                    : 'Request simulated withdrawal',
                icon: Icons.account_balance_outlined,
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
        .read(withdrawalControllerProvider.notifier)
        .withdraw(
          amountPaise: rupeesToPaise(double.parse(_amount.text)),
          method: _method,
          accountLabel: _accountLabel.text,
        );
  }

  String? _validateAmount(String? value, int? availablePaise) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Enter a positive amount';
    }
    final paise = rupeesToPaise(parsed);
    if (availablePaise != null && paise > availablePaise) {
      return 'Amount exceeds available balance';
    }
    return null;
  }
}
