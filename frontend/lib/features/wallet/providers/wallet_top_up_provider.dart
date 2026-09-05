import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wallet_mock_repository.dart';
import '../domain/wallet_transaction.dart';
import 'transaction_history_provider.dart';
import 'wallet_provider.dart';

final walletTopUpControllerProvider =
    StateNotifierProvider<TopUpController, AsyncValue<WalletTransaction?>>(
      (ref) => TopUpController(ref),
    );

class TopUpController extends StateNotifier<AsyncValue<WalletTransaction?>> {
  TopUpController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<WalletTransaction?> addFunds({
    required int amountPaise,
    required FundingMethod method,
    required String label,
  }) async {
    state = const AsyncValue.loading();
    try {
      final role = await _ref.read(walletRoleProvider.future);
      final transaction = await _ref
          .read(walletRepositoryProvider)
          .addFunds(
            amountPaise: amountPaise,
            method: method,
            label: label,
            role: role,
          );
      await _ref.read(walletControllerProvider.notifier).refresh();
      _ref.invalidate(transactionHistoryProvider);
      state = AsyncValue.data(transaction);
      return transaction;
    } catch (error, stackTrace) {
      final message = error is WalletException
          ? error
          : const WalletException('Could not add simulated funds.');
      state = AsyncValue.error(message, stackTrace);
      return null;
    }
  }
}
