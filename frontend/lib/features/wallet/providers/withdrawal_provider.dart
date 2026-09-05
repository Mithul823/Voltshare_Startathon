import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wallet_mock_repository.dart';
import '../domain/withdrawal_request.dart';
import 'transaction_history_provider.dart';
import 'wallet_provider.dart';

final withdrawalControllerProvider =
    StateNotifierProvider<WithdrawalController, AsyncValue<WithdrawalRequest?>>(
      (ref) => WithdrawalController(ref),
    );

class WithdrawalController
    extends StateNotifier<AsyncValue<WithdrawalRequest?>> {
  WithdrawalController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<WithdrawalRequest?> withdraw({
    required int amountPaise,
    required WithdrawalMethod method,
    required String accountLabel,
  }) async {
    state = const AsyncValue.loading();
    try {
      final role = await _ref.read(walletRoleProvider.future);
      final request = await _ref
          .read(walletRepositoryProvider)
          .withdraw(
            amountPaise: amountPaise,
            method: method,
            accountLabel: accountLabel,
            role: role,
          );
      await _ref.read(walletControllerProvider.notifier).refresh();
      _ref.invalidate(transactionHistoryProvider);
      state = AsyncValue.data(request);
      return request;
    } catch (error, stackTrace) {
      final message = error is WalletException
          ? error
          : const WalletException('Could not create withdrawal request.');
      state = AsyncValue.error(message, stackTrace);
      return null;
    }
  }

  Future<void> completePending() async {
    await _ref.read(walletRepositoryProvider).completePendingWithdrawals();
    await _ref.read(walletControllerProvider.notifier).refresh();
    _ref.invalidate(transactionHistoryProvider);
  }
}
