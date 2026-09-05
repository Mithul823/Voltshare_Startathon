import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wallet_transaction.dart';
import 'wallet_provider.dart';

final transactionHistoryQueryProvider = StateProvider<TransactionHistoryQuery>(
  (ref) => const TransactionHistoryQuery(),
);

final transactionHistoryProvider =
    FutureProvider.autoDispose<List<WalletTransaction>>((ref) {
      final repository = ref.watch(walletRepositoryProvider);
      final query = ref.watch(transactionHistoryQueryProvider);
      ref.watch(walletControllerProvider);
      return repository.transactions(query);
    });

final walletTransactionProvider = FutureProvider.autoDispose
    .family<WalletTransaction, String>((ref, id) {
      final repository = ref.watch(walletRepositoryProvider);
      ref.watch(walletControllerProvider);
      return repository.transactionById(id);
    });
