// ignore_for_file: annotate_overrides

import '../../authentication/domain/user_role.dart';
import '../../marketplace/domain/energy_listing.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../domain/wallet.dart';
import '../domain/wallet_summary.dart';
import '../domain/wallet_transaction.dart';
import '../domain/withdrawal_request.dart';

abstract class WalletRepository {
  Future<Wallet> loadWallet();
  Future<List<WalletTransaction>> transactions(TransactionHistoryQuery query);
  Future<WalletTransaction> transactionById(String id);
  WalletSummary summary();
  Future<WalletTransaction> addFunds({
    required int amountPaise,
    required FundingMethod method,
    required String label,
    required UserRole role,
  });
  Future<WithdrawalRequest> withdraw({
    required int amountPaise,
    required WithdrawalMethod method,
    required String accountLabel,
    required UserRole role,
  });
  Future<void> completePendingWithdrawals();
  Future<WalletTransaction> recordPurchase({
    required EnergyPurchase purchase,
    required EnergyListing listing,
    required UserRole role,
    String? escrowId,
  });
  Future<WalletTransaction> recordSale({
    required EnergyListing listing,
    required double quantityKwh,
  });
  Future<void> settlePendingSales();
  Future<void> applyEscrowSettlement({
    required String escrowId,
    required String idempotencyKey,
    required int buyerRefundPaise,
    required int sellerReleasePaise,
    required int platformFeeRetainedPaise,
    required int frozenPaise,
  });
  Future<WalletTransaction> refund(String transactionId);
}

class WalletMockRepository implements WalletRepository {
  WalletMockRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _wallet = Wallet(
      userId: currentUserId,
      availableBalancePaise: 125000,
      pendingBalancePaise: 32000,
      escrowHeldBalancePaise: 0,
      totalEarnedPaise: 486000,
      totalSpentPaise: 293000,
      totalWithdrawnPaise: 84000,
      totalAddedPaise: 200000,
      currency: 'Rs',
      updatedAt: _now,
    );
    _transactions = _seedTransactions(_now);
  }

  static const currentUserId = 'current-user';
  static const maximumTopUpPaise = 500000;
  static const minimumWithdrawalPaise = 10000;

  final DateTime _now;
  late Wallet _wallet;
  late List<WalletTransaction> _transactions;
  final List<WithdrawalRequest> _withdrawals = [];
  final Set<String> _recordedPurchaseIds = {};
  final Set<String> _refundedTransactionIds = {};
  final Set<String> _appliedEscrowSettlementKeys = {};

  Future<Wallet> loadWallet() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _wallet;
  }

  Future<List<WalletTransaction>> transactions(
    TransactionHistoryQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return applyQuery(_transactions, query);
  }

  Future<WalletTransaction> transactionById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _transactions.firstWhere(
      (item) => item.id == id,
      orElse: () => throw const WalletException('Transaction not found.'),
    );
  }

  WalletSummary summary() => calculateSummary(_transactions, now: _now);

  Future<WalletTransaction> addFunds({
    required int amountPaise,
    required FundingMethod method,
    required String label,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _ensureCanTransact(role, allowConsumer: true);
    if (amountPaise <= 0) {
      throw const WalletException('Enter a positive amount.');
    }
    if (amountPaise > maximumTopUpPaise) {
      throw const WalletException('Demo top-up limit is Rs 5,000.00.');
    }
    _wallet = _wallet.copyWith(
      availableBalancePaise: _wallet.availableBalancePaise + amountPaise,
      totalAddedPaise: _wallet.totalAddedPaise + amountPaise,
      updatedAt: _now,
    );
    final transaction = _transaction(
      type: WalletTransactionType.walletTopUp,
      status: WalletTransactionStatus.completed,
      amountPaise: amountPaise,
      description:
          'Simulated ${method.label} top-up${label.trim().isEmpty ? '' : ' for ${label.trim()}'}',
      completedAt: _now,
    );
    _transactions = [transaction, ..._transactions];
    return transaction;
  }

  Future<WithdrawalRequest> withdraw({
    required int amountPaise,
    required WithdrawalMethod method,
    required String accountLabel,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (role != UserRole.producer && role != UserRole.prosumer) {
      throw const WalletException('This role cannot withdraw demo earnings.');
    }
    if (amountPaise < minimumWithdrawalPaise) {
      throw const WalletException('Minimum demo withdrawal is Rs 100.00.');
    }
    if (accountLabel.trim().isEmpty) {
      throw const WalletException('Add an account label.');
    }
    _ensureAvailable(amountPaise);
    _wallet = _wallet.copyWith(
      availableBalancePaise: _wallet.availableBalancePaise - amountPaise,
      totalWithdrawnPaise: _wallet.totalWithdrawnPaise + amountPaise,
      updatedAt: _now,
    );
    final request = WithdrawalRequest(
      id: 'WDR-${_withdrawals.length + 501}',
      userId: currentUserId,
      amountPaise: amountPaise,
      method: method,
      accountLabel: accountLabel.trim(),
      status: WithdrawalStatus.pending,
      requestedAt: _now,
    );
    _withdrawals.add(request);
    _transactions = [
      _transaction(
        id: request.id,
        type: WalletTransactionType.withdrawal,
        status: WalletTransactionStatus.pending,
        amountPaise: amountPaise,
        description: 'Simulated withdrawal to ${method.label}',
      ),
      ..._transactions,
    ];
    return request;
  }

  Future<void> completePendingWithdrawals() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (var index = 0; index < _withdrawals.length; index++) {
      final request = _withdrawals[index];
      if (request.status == WithdrawalStatus.pending) {
        _withdrawals[index] = request.copyWith(
          status: WithdrawalStatus.completed,
          processedAt: _now.add(const Duration(minutes: 15)),
        );
        _transactions = [
          for (final item in _transactions)
            if (item.id == request.id)
              item.copyWith(
                status: WalletTransactionStatus.completed,
                completedAt: _now.add(const Duration(minutes: 15)),
              )
            else
              item,
        ];
      }
    }
  }

  Future<WalletTransaction> recordPurchase({
    required EnergyPurchase purchase,
    required EnergyListing listing,
    required UserRole role,
    String? escrowId,
  }) async {
    if (role != UserRole.consumer && role != UserRole.prosumer) {
      throw const WalletException('This role cannot buy energy.');
    }
    if (_recordedPurchaseIds.contains(purchase.id)) {
      return _transactions.firstWhere(
        (item) => item.energyPurchaseId == purchase.id,
      );
    }
    final totalPaise = rupeesToPaise(purchase.totalAmount);
    _ensureAvailable(totalPaise);
    _wallet = _wallet.copyWith(
      availableBalancePaise: _wallet.availableBalancePaise - totalPaise,
      escrowHeldBalancePaise: _wallet.escrowHeldBalancePaise + totalPaise,
      totalSpentPaise: _wallet.totalSpentPaise + totalPaise,
      updatedAt: purchase.purchasedAt,
    );
    final transaction = _transaction(
      id: 'TXN-${purchase.id}',
      type: WalletTransactionType.energyPurchase,
      status: WalletTransactionStatus.completed,
      amountPaise: totalPaise,
      energyQuantityKwh: purchase.quantityKwh,
      unitPricePaise: rupeesToPaise(purchase.unitPrice),
      platformFeePaise: rupeesToPaise(purchase.platformFee),
      counterpartyId: listing.sellerId,
      counterpartyName: listing.sellerName,
      marketplaceListingId: listing.id,
      energyPurchaseId: purchase.id,
      escrowId: escrowId,
      escrowStatusLabel: escrowId == null ? null : 'Awaiting energy delivery',
      description:
          'Purchased ${purchase.quantityKwh.toStringAsFixed(1)} kWh from ${listing.sellerName}',
      createdAt: purchase.purchasedAt,
      completedAt: purchase.purchasedAt,
    );
    _recordedPurchaseIds.add(purchase.id);
    _transactions = [transaction, ..._transactions];
    return transaction;
  }

  Future<WalletTransaction> recordSale({
    required EnergyListing listing,
    required double quantityKwh,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final grossPaise = rupeesToPaise(quantityKwh * listing.pricePerKwh);
    final feePaise = (grossPaise * 0.03).round();
    final netPaise = grossPaise - feePaise;
    _wallet = _wallet.copyWith(
      pendingBalancePaise: _wallet.pendingBalancePaise + netPaise,
      totalEarnedPaise: _wallet.totalEarnedPaise + netPaise,
      updatedAt: _now,
    );
    final transaction = _transaction(
      type: WalletTransactionType.energySale,
      status: WalletTransactionStatus.pending,
      amountPaise: netPaise,
      energyQuantityKwh: quantityKwh,
      unitPricePaise: rupeesToPaise(listing.pricePerKwh),
      platformFeePaise: feePaise,
      counterpartyName: 'Community buyer',
      marketplaceListingId: listing.id,
      description:
          'Pending settlement for ${quantityKwh.toStringAsFixed(1)} kWh sale',
    );
    _transactions = [transaction, ..._transactions];
    return transaction;
  }

  Future<void> settlePendingSales() async {
    final pending = _transactions
        .where(
          (item) =>
              item.type == WalletTransactionType.energySale &&
              item.status == WalletTransactionStatus.pending,
        )
        .toList();
    final total = pending.fold<int>(0, (sum, item) => sum + item.amountPaise);
    if (total == 0) {
      return;
    }
    _wallet = _wallet.copyWith(
      pendingBalancePaise: (_wallet.pendingBalancePaise - total).clamp(
        0,
        1 << 62,
      ),
      availableBalancePaise: _wallet.availableBalancePaise + total,
      updatedAt: _now.add(const Duration(hours: 2)),
    );
    _transactions = [
      for (final item in _transactions)
        if (pending.any((pendingItem) => pendingItem.id == item.id))
          item.copyWith(
            status: WalletTransactionStatus.completed,
            completedAt: _now.add(const Duration(hours: 2)),
          )
        else
          item,
    ];
  }

  Future<void> applyEscrowSettlement({
    required String escrowId,
    required String idempotencyKey,
    required int buyerRefundPaise,
    required int sellerReleasePaise,
    required int platformFeeRetainedPaise,
    required int frozenPaise,
  }) async {
    if (_appliedEscrowSettlementKeys.contains(idempotencyKey)) {
      return;
    }
    _appliedEscrowSettlementKeys.add(idempotencyKey);
    final removedFromEscrow =
        buyerRefundPaise + sellerReleasePaise + platformFeeRetainedPaise;
    _wallet = _wallet.copyWith(
      escrowHeldBalancePaise:
          (_wallet.escrowHeldBalancePaise - removedFromEscrow).clamp(
            0,
            1 << 62,
          ),
      availableBalancePaise: _wallet.availableBalancePaise + buyerRefundPaise,
      pendingBalancePaise: _wallet.pendingBalancePaise + sellerReleasePaise,
      totalEarnedPaise: _wallet.totalEarnedPaise + sellerReleasePaise,
      updatedAt: _now,
    );
    if (buyerRefundPaise > 0) {
      _transactions = [
        _transaction(
          type: WalletTransactionType.refund,
          status: WalletTransactionStatus.completed,
          amountPaise: buyerRefundPaise,
          description: 'Escrow refund for $escrowId',
          escrowId: escrowId,
          escrowStatusLabel: frozenPaise > 0 ? 'Funds frozen' : 'Refunded',
          completedAt: _now,
        ),
        ..._transactions,
      ];
    }
    _transactions = [
      for (final item in _transactions)
        if (item.escrowId == escrowId)
          WalletTransaction(
            id: item.id,
            userId: item.userId,
            type: item.type,
            status: item.status,
            amountPaise: item.amountPaise,
            energyQuantityKwh: item.energyQuantityKwh,
            unitPricePaise: item.unitPricePaise,
            platformFeePaise: item.platformFeePaise,
            counterpartyId: item.counterpartyId,
            counterpartyName: item.counterpartyName,
            marketplaceListingId: item.marketplaceListingId,
            energyPurchaseId: item.energyPurchaseId,
            escrowId: item.escrowId,
            escrowStatusLabel: frozenPaise > 0
                ? 'Funds frozen'
                : buyerRefundPaise > 0
                ? 'Partially refunded'
                : 'Funds released',
            reference: item.reference,
            description: item.description,
            createdAt: item.createdAt,
            completedAt: item.completedAt,
            refundedTransactionId: item.refundedTransactionId,
          )
        else
          item,
    ];
  }

  Future<WalletTransaction> refund(String transactionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final original = await transactionById(transactionId);
    if (!original.canRefund) {
      throw const WalletException(
        'This transaction is not eligible for refund.',
      );
    }
    if (_refundedTransactionIds.contains(transactionId)) {
      throw const WalletException(
        'This transaction has already been refunded.',
      );
    }
    _refundedTransactionIds.add(transactionId);
    _wallet = _wallet.copyWith(
      availableBalancePaise:
          _wallet.availableBalancePaise + original.amountPaise,
      totalSpentPaise: (_wallet.totalSpentPaise - original.amountPaise).clamp(
        0,
        1 << 62,
      ),
      updatedAt: _now,
    );
    _transactions = [
      _transaction(
        type: WalletTransactionType.refund,
        status: WalletTransactionStatus.completed,
        amountPaise: original.amountPaise,
        counterpartyName: original.counterpartyName,
        marketplaceListingId: original.marketplaceListingId,
        energyPurchaseId: original.energyPurchaseId,
        description: 'Refund for ${original.reference}',
        completedAt: _now,
        refundedTransactionId: original.id,
      ),
      for (final item in _transactions)
        if (item.id == transactionId)
          item.copyWith(status: WalletTransactionStatus.refunded)
        else
          item,
    ];
    return _transactions.first;
  }

  List<WalletTransaction> applyQuery(
    List<WalletTransaction> source,
    TransactionHistoryQuery query,
  ) {
    Iterable<WalletTransaction> result = source;
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      result = result.where(
        (item) =>
            item.reference.toLowerCase().contains(search) ||
            item.description.toLowerCase().contains(search) ||
            (item.counterpartyName ?? '').toLowerCase().contains(search),
      );
    }
    result = switch (query.filter) {
      TransactionFilter.all => result,
      TransactionFilter.purchases => result.where(
        (item) => item.type == WalletTransactionType.energyPurchase,
      ),
      TransactionFilter.sales => result.where(
        (item) => item.type == WalletTransactionType.energySale,
      ),
      TransactionFilter.topUps => result.where(
        (item) => item.type == WalletTransactionType.walletTopUp,
      ),
      TransactionFilter.withdrawals => result.where(
        (item) => item.type == WalletTransactionType.withdrawal,
      ),
      TransactionFilter.refunds => result.where(
        (item) => item.type == WalletTransactionType.refund,
      ),
      TransactionFilter.rewards => result.where(
        (item) => item.type == WalletTransactionType.reward,
      ),
      TransactionFilter.pending => result.where(
        (item) => item.status == WalletTransactionStatus.pending,
      ),
      TransactionFilter.completed => result.where(
        (item) => item.status == WalletTransactionStatus.completed,
      ),
      TransactionFilter.failed => result.where(
        (item) => item.status == WalletTransactionStatus.failed,
      ),
    };
    if (query.fromDate != null) {
      result = result.where(
        (item) => !item.createdAt.isBefore(query.fromDate!),
      );
    }
    if (query.toDate != null) {
      result = result.where((item) => !item.createdAt.isAfter(query.toDate!));
    }
    final list = result.toList();
    list.sort((a, b) {
      return switch (query.sort) {
        TransactionSort.newestFirst => b.createdAt.compareTo(a.createdAt),
        TransactionSort.oldestFirst => a.createdAt.compareTo(b.createdAt),
        TransactionSort.highestAmount => b.amountPaise.compareTo(a.amountPaise),
        TransactionSort.lowestAmount => a.amountPaise.compareTo(b.amountPaise),
      };
    });
    return list;
  }

  WalletSummary calculateSummary(
    List<WalletTransaction> source, {
    required DateTime now,
  }) {
    final dayStart = DateTime(now.year, now.month, now.day);
    final weekStart = dayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    int incomeSince(DateTime date) => _income(source, date);
    int spendingSince(DateTime date) => _spending(source, date);
    final incomeMonth = incomeSince(monthStart);
    final spendingMonth = spendingSince(monthStart);
    return WalletSummary(
      incomeTodayPaise: incomeSince(dayStart),
      incomeThisWeekPaise: incomeSince(weekStart),
      incomeThisMonthPaise: incomeMonth,
      spendingTodayPaise: spendingSince(dayStart),
      spendingThisWeekPaise: spendingSince(weekStart),
      spendingThisMonthPaise: spendingMonth,
      netBalanceChangePaise: incomeMonth - spendingMonth,
      energyBoughtKwh: source
          .where((item) => item.type == WalletTransactionType.energyPurchase)
          .fold<double>(0, (sum, item) => sum + (item.energyQuantityKwh ?? 0)),
      energySoldKwh: source
          .where((item) => item.type == WalletTransactionType.energySale)
          .fold<double>(0, (sum, item) => sum + (item.energyQuantityKwh ?? 0)),
    );
  }

  void _ensureAvailable(int amountPaise) {
    if (amountPaise > _wallet.availableBalancePaise) {
      throw const WalletException('Insufficient simulated wallet balance.');
    }
  }

  void _ensureCanTransact(UserRole role, {required bool allowConsumer}) {
    if (role == UserRole.producer || role == UserRole.prosumer) {
      return;
    }
    if (allowConsumer && role == UserRole.consumer) {
      return;
    }
    throw const WalletException('This wallet is read-only for your role.');
  }

  WalletTransaction _transaction({
    String? id,
    required WalletTransactionType type,
    required WalletTransactionStatus status,
    required int amountPaise,
    String? reference,
    String? description,
    DateTime? createdAt,
    DateTime? completedAt,
    double? energyQuantityKwh,
    int? unitPricePaise,
    int platformFeePaise = 0,
    String? counterpartyId,
    String? counterpartyName,
    String? marketplaceListingId,
    String? energyPurchaseId,
    String? escrowId,
    String? escrowStatusLabel,
    String? refundedTransactionId,
  }) {
    final next = _transactions.length + 1001;
    return WalletTransaction(
      id: id ?? 'TXN-$next',
      userId: currentUserId,
      type: type,
      status: status,
      amountPaise: amountPaise,
      energyQuantityKwh: energyQuantityKwh,
      unitPricePaise: unitPricePaise,
      platformFeePaise: platformFeePaise,
      counterpartyId: counterpartyId,
      counterpartyName: counterpartyName,
      marketplaceListingId: marketplaceListingId,
      energyPurchaseId: energyPurchaseId,
      escrowId: escrowId,
      escrowStatusLabel: escrowStatusLabel,
      reference: reference ?? 'VS-$next',
      description: description ?? type.label,
      createdAt: createdAt ?? _now,
      completedAt: completedAt,
      refundedTransactionId: refundedTransactionId,
    );
  }

  int _income(List<WalletTransaction> source, DateTime since) {
    return source
        .where(
          (item) =>
              !item.createdAt.isBefore(since) &&
              (item.type == WalletTransactionType.energySale ||
                  item.type == WalletTransactionType.walletTopUp ||
                  item.type == WalletTransactionType.refund ||
                  item.type == WalletTransactionType.reward),
        )
        .fold<int>(0, (sum, item) => sum + item.amountPaise);
  }

  int _spending(List<WalletTransaction> source, DateTime since) {
    return source
        .where(
          (item) =>
              !item.createdAt.isBefore(since) &&
              (item.type == WalletTransactionType.energyPurchase ||
                  item.type == WalletTransactionType.withdrawal ||
                  item.type == WalletTransactionType.platformFee),
        )
        .fold<int>(0, (sum, item) => sum + item.amountPaise);
  }

  List<WalletTransaction> _seedTransactions(DateTime now) {
    return [
      WalletTransaction(
        id: 'TXN-SEED-1',
        userId: currentUserId,
        type: WalletTransactionType.energySale,
        status: WalletTransactionStatus.pending,
        amountPaise: 32000,
        energyQuantityKwh: 4,
        unitPricePaise: 825,
        platformFeePaise: 990,
        counterpartyName: 'Anjali Nair',
        marketplaceListingId: 'mine-seed',
        reference: 'VS-4860',
        description: 'Pending settlement for community solar sale',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      WalletTransaction(
        id: 'TXN-SEED-2',
        userId: currentUserId,
        type: WalletTransactionType.energyPurchase,
        status: WalletTransactionStatus.completed,
        amountPaise: 8450,
        energyQuantityKwh: 1,
        unitPricePaise: 820,
        platformFeePaise: 25,
        counterpartyName: 'Ravi Solar Hub',
        marketplaceListingId: 'ravi',
        energyPurchaseId: 'PUR-SEED',
        reference: 'VS-2930',
        description: 'Purchased 1.0 kWh from Ravi Solar Hub',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        completedAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      WalletTransaction(
        id: 'TXN-SEED-3',
        userId: currentUserId,
        type: WalletTransactionType.walletTopUp,
        status: WalletTransactionStatus.completed,
        amountPaise: 50000,
        reference: 'VS-2000',
        description: 'Simulated demo balance top-up',
        createdAt: now.subtract(const Duration(days: 3)),
        completedAt: now.subtract(const Duration(days: 3)),
      ),
      WalletTransaction(
        id: 'TXN-SEED-4',
        userId: currentUserId,
        type: WalletTransactionType.withdrawal,
        status: WalletTransactionStatus.completed,
        amountPaise: 25000,
        reference: 'VS-0840',
        description: 'Completed demo settlement withdrawal',
        createdAt: now.subtract(const Duration(days: 5)),
        completedAt: now.subtract(const Duration(days: 5, minutes: -15)),
      ),
      WalletTransaction(
        id: 'TXN-SEED-5',
        userId: currentUserId,
        type: WalletTransactionType.reward,
        status: WalletTransactionStatus.completed,
        amountPaise: 7500,
        reference: 'VS-REWARD',
        description: 'Clean-energy sharing reward',
        createdAt: now.subtract(const Duration(days: 6)),
        completedAt: now.subtract(const Duration(days: 6)),
      ),
    ];
  }
}

class WalletException implements Exception {
  const WalletException(this.message);
  final String message;
  @override
  String toString() => message;
}
