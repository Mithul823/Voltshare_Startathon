enum WalletTransactionType {
  energyPurchase('Energy purchase'),
  energySale('Energy sale'),
  platformFee('Platform fee'),
  walletTopUp('Wallet top-up'),
  withdrawal('Withdrawal'),
  refund('Refund'),
  adjustment('Adjustment'),
  reward('Reward');

  const WalletTransactionType(this.label);
  final String label;
}

enum WalletTransactionStatus {
  pending('Pending'),
  completed('Completed'),
  failed('Failed'),
  refunded('Refunded'),
  cancelled('Cancelled');

  const WalletTransactionStatus(this.label);
  final String label;
}

enum FundingMethod {
  upi('UPI'),
  debitCard('Debit card'),
  bankTransfer('Bank transfer'),
  demoBalance('Demo balance');

  const FundingMethod(this.label);
  final String label;
}

enum TransactionFilter {
  all('All'),
  purchases('Purchases'),
  sales('Sales'),
  topUps('Top-ups'),
  withdrawals('Withdrawals'),
  refunds('Refunds'),
  rewards('Rewards'),
  pending('Pending'),
  completed('Completed'),
  failed('Failed');

  const TransactionFilter(this.label);
  final String label;
}

enum TransactionSort {
  newestFirst('Newest first'),
  oldestFirst('Oldest first'),
  highestAmount('Highest amount'),
  lowestAmount('Lowest amount');

  const TransactionSort(this.label);
  final String label;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.amountPaise,
    required this.reference,
    required this.description,
    required this.createdAt,
    this.energyQuantityKwh,
    this.unitPricePaise,
    this.platformFeePaise = 0,
    this.counterpartyId,
    this.counterpartyName,
    this.marketplaceListingId,
    this.energyPurchaseId,
    this.escrowId,
    this.escrowStatusLabel,
    this.completedAt,
    this.refundedTransactionId,
  });

  final String id;
  final String userId;
  final WalletTransactionType type;
  final WalletTransactionStatus status;
  final int amountPaise;
  final double? energyQuantityKwh;
  final int? unitPricePaise;
  final int platformFeePaise;
  final String? counterpartyId;
  final String? counterpartyName;
  final String? marketplaceListingId;
  final String? energyPurchaseId;
  final String? escrowId;
  final String? escrowStatusLabel;
  final String reference;
  final String description;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? refundedTransactionId;

  int get subtotalPaise {
    final quantity = energyQuantityKwh;
    final unitPrice = unitPricePaise;
    if (quantity == null || unitPrice == null) {
      return amountPaise;
    }
    return (quantity * unitPrice).round();
  }

  bool get canRefund {
    return type == WalletTransactionType.energyPurchase &&
        status == WalletTransactionStatus.completed;
  }

  WalletTransaction copyWith({
    WalletTransactionStatus? status,
    DateTime? completedAt,
  }) {
    return WalletTransaction(
      id: id,
      userId: userId,
      type: type,
      status: status ?? this.status,
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
      reference: reference,
      description: description,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      refundedTransactionId: refundedTransactionId,
    );
  }
}

class TransactionHistoryQuery {
  const TransactionHistoryQuery({
    this.search = '',
    this.filter = TransactionFilter.all,
    this.sort = TransactionSort.newestFirst,
    this.fromDate,
    this.toDate,
  });

  final String search;
  final TransactionFilter filter;
  final TransactionSort sort;
  final DateTime? fromDate;
  final DateTime? toDate;

  TransactionHistoryQuery copyWith({
    String? search,
    TransactionFilter? filter,
    TransactionSort? sort,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return TransactionHistoryQuery(
      search: search ?? this.search,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}
