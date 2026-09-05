import '../../authentication/domain/user_role.dart';
import '../../marketplace/domain/energy_listing.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../domain/wallet.dart';
import '../domain/wallet_summary.dart';
import '../domain/wallet_transaction.dart';
import '../domain/withdrawal_request.dart';
import 'wallet_mock_repository.dart';

class WalletApiRepository implements WalletRepository {
  WalletApiRepository(this._client, {IdempotencyKeyGenerator? keys})
    : _keys = keys ?? IdempotencyKeyGenerator();

  final ApiClient _client;
  final IdempotencyKeyGenerator _keys;
  List<WalletTransaction> _latestTransactions = const [];

  @override
  Future<Wallet> loadWallet() async {
    final data = await _client.get('/wallet') as Map;
    return _walletFromResponse(data);
  }

  @override
  Future<List<WalletTransaction>> transactions(
    TransactionHistoryQuery query,
  ) async {
    final data = await _client.get('/wallet/transactions') as List;
    _latestTransactions = data
        .map((item) => _transactionFromResponse(item as Map))
        .toList();
    // Apply client-side query filtering on top of API results
    return _applyQuery(_latestTransactions, query);
  }

  @override
  Future<WalletTransaction> transactionById(String id) async {
    return _transactionFromResponse(
      await _client.get('/wallet/transactions/$id') as Map,
    );
  }

  @override
  WalletSummary summary() {
    // Calculate summary from latest transactions
    return _calculateSummary(_latestTransactions, now: DateTime.now());
  }

  @override
  Future<WalletTransaction> addFunds({
    required int amountPaise,
    required FundingMethod method,
    required String label,
    required UserRole role,
  }) async {
    return _transactionFromResponse(
      await _client.post(
            '/wallet/deposit',
            idempotencyKey: _keys.next('topup'),
            body: {
              'amountPaise': amountPaise,
              'method': method.name,
              'label': label,
            },
          )
          as Map,
    );
  }

  @override
  Future<WithdrawalRequest> withdraw({
    required int amountPaise,
    required WithdrawalMethod method,
    required String accountLabel,
    required UserRole role,
  }) async {
    final tx = _transactionFromResponse(
      await _client.post(
            '/wallet/withdraw',
            idempotencyKey: _keys.next('withdraw'),
            body: {
              'amountPaise': amountPaise,
              'method': method.name,
              'label': accountLabel,
            },
          )
          as Map,
    );
    return WithdrawalRequest(
      id: tx.id,
      userId: tx.userId,
      amountPaise: tx.amountPaise,
      method: method,
      accountLabel: accountLabel,
      status: WithdrawalStatus.pending,
      requestedAt: tx.createdAt,
    );
  }

  @override
  Future<void> completePendingWithdrawals() async {
    // Backend processes pending withdrawals; Flutter just refreshes
    await _client.post('/wallet/withdrawals/complete');
  }

  @override
  Future<WalletTransaction> recordPurchase({
    required EnergyPurchase purchase,
    required EnergyListing listing,
    required UserRole role,
    String? escrowId,
  }) async {
    // Purchase is handled atomically by the backend /purchases endpoint.
    // This method is called in mock mode; in live mode the purchase flow
    // calls the backend directly and skips this method.
    final response = await _client.post(
      '/purchases',
      idempotencyKey: _keys.next('purchase'),
      body: {
        'listingId': listing.id,
        'quantityKwh': purchase.quantityKwh,
      },
    ) as Map;
    final txData = response['purchase'] as Map? ?? response;
    return _transactionFromResponse({
      'id': 'TXN-${txData['id']}',
      'userId': purchase.buyerId,
      'type': 'energyPurchase',
      'status': 'completed',
      'amountPaise': _rupeesToPaise(purchase.totalAmount),
      'reference': txData['id'].toString(),
      'description':
          'Purchased ${purchase.quantityKwh.toStringAsFixed(1)} kWh from ${listing.sellerName}',
      'createdAt': txData['purchasedAt'].toString(),
      'completedAt': txData['purchasedAt'].toString(),
      'energyQuantityKwh': purchase.quantityKwh,
      'unitPricePaise': _rupeesToPaise(purchase.unitPrice),
      'platformFeePaise': _rupeesToPaise(purchase.platformFee),
      'counterpartyId': listing.sellerId,
      'counterpartyName': listing.sellerName,
      'marketplaceListingId': listing.id,
      'energyPurchaseId': txData['id'].toString(),
      'escrowId': escrowId ?? (response['escrowId']?.toString()),
      'escrowStatusLabel':
          escrowId == null ? null : 'Awaiting energy delivery',
    });
  }

  @override
  Future<WalletTransaction> recordSale({
    required EnergyListing listing,
    required double quantityKwh,
  }) async {
    // Sales are recorded by the backend through the settlement flow
    final data = await _client.post(
      '/settlements',
      idempotencyKey: _keys.next('settle'),
      body: {
        'listingId': listing.id,
        'quantityKwh': quantityKwh,
        'sellerId': listing.sellerId,
      },
    ) as Map;
    return _transactionFromResponse({
      'id': 'TXN-${data['settlementId'] ?? data['id']}',
      'userId': listing.sellerId,
      'type': 'energySale',
      'status': 'pending',
      'amountPaise': _rupeesToPaise(quantityKwh * listing.pricePerKwh),
      'reference': data['id'].toString(),
      'description': 'Sale of ${quantityKwh.toStringAsFixed(1)} kWh',
      'createdAt': DateTime.now().toIso8601String(),
      'energyQuantityKwh': quantityKwh,
      'marketplaceListingId': listing.id,
    });
  }

  @override
  Future<void> settlePendingSales() async {
    await _client.post('/settlements/batch',
        idempotencyKey: _keys.next('settle-batch'));
  }

  @override
  Future<void> applyEscrowSettlement({
    required String escrowId,
    required String idempotencyKey,
    required int buyerRefundPaise,
    required int sellerReleasePaise,
    required int platformFeeRetainedPaise,
    required int frozenPaise,
  }) async {
    await _client.post(
      '/escrows/$escrowId/settle',
      idempotencyKey: idempotencyKey,
      body: {
        'deliveredEnergyKwh': (sellerReleasePaise + buyerRefundPaise) / 100.0,
        'meterMatched': true,
        'tamperingDetected': false,
        'withinDeliveryWindow': true,
      },
    );
  }

  @override
  Future<WalletTransaction> refund(String transactionId) async {
    return _transactionFromResponse(
      await _client.post(
            '/refunds',
            idempotencyKey: _keys.next('refund'),
            body: {'transactionId': transactionId},
          )
          as Map,
    );
  }
}

int _rupeesToPaise(double rupees) => (rupees * 100).round();

List<WalletTransaction> _applyQuery(
    List<WalletTransaction> source, TransactionHistoryQuery query) {
  var result = source;
  if (query.search.trim().isNotEmpty) {
    final search = query.search.trim().toLowerCase();
    result = result.where(
      (item) =>
          item.reference.toLowerCase().contains(search) ||
          item.description.toLowerCase().contains(search) ||
          (item.counterpartyName ?? '').toLowerCase().contains(search),
    ).toList();
  }
  result = switch (query.filter) {
    TransactionFilter.all => result,
    TransactionFilter.purchases => result
        .where((item) => item.type == WalletTransactionType.energyPurchase)
        .toList(),
    TransactionFilter.sales => result
        .where((item) => item.type == WalletTransactionType.energySale)
        .toList(),
    TransactionFilter.topUps => result
        .where((item) => item.type == WalletTransactionType.walletTopUp)
        .toList(),
    TransactionFilter.withdrawals => result
        .where((item) => item.type == WalletTransactionType.withdrawal)
        .toList(),
    TransactionFilter.refunds => result
        .where((item) => item.type == WalletTransactionType.refund)
        .toList(),
    TransactionFilter.rewards => result
        .where((item) => item.type == WalletTransactionType.reward)
        .toList(),
    TransactionFilter.pending => result
        .where((item) => item.status == WalletTransactionStatus.pending)
        .toList(),
    TransactionFilter.completed => result
        .where((item) => item.status == WalletTransactionStatus.completed)
        .toList(),
    TransactionFilter.failed => result
        .where((item) => item.status == WalletTransactionStatus.failed)
        .toList(),
  };
  if (query.fromDate != null) {
    result = result.where((item) => !item.createdAt.isBefore(query.fromDate!)).toList();
  }
  if (query.toDate != null) {
    result = result.where((item) => !item.createdAt.isAfter(query.toDate!)).toList();
  }
  result.sort((a, b) {
    return switch (query.sort) {
      TransactionSort.newestFirst => b.createdAt.compareTo(a.createdAt),
      TransactionSort.oldestFirst => a.createdAt.compareTo(b.createdAt),
      TransactionSort.highestAmount => b.amountPaise.compareTo(a.amountPaise),
      TransactionSort.lowestAmount => a.amountPaise.compareTo(b.amountPaise),
    };
  });
  return result;
}

WalletSummary _calculateSummary(
    List<WalletTransaction> transactions, {DateTime? now}) {
  final nowDt = now ?? DateTime.now();
  final dayStart = DateTime(nowDt.year, nowDt.month, nowDt.day);
  final weekStart = dayStart.subtract(Duration(days: nowDt.weekday - 1));
  final monthStart = DateTime(nowDt.year, nowDt.month);

  int incomeSince(DateTime date) {
    return transactions
        .where(
          (item) =>
              !item.createdAt.isBefore(date) &&
              (item.type == WalletTransactionType.energySale ||
                  item.type == WalletTransactionType.walletTopUp ||
                  item.type == WalletTransactionType.refund ||
                  item.type == WalletTransactionType.reward),
        )
        .fold<int>(0, (sum, item) => sum + item.amountPaise);
  }

  int spendingSince(DateTime date) {
    return transactions
        .where(
          (item) =>
              !item.createdAt.isBefore(date) &&
              (item.type == WalletTransactionType.energyPurchase ||
                  item.type == WalletTransactionType.withdrawal),
        )
        .fold<int>(0, (sum, item) => sum + item.amountPaise);
  }

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
    energyBoughtKwh: transactions
        .where((item) => item.type == WalletTransactionType.energyPurchase)
        .fold<double>(
            0, (sum, item) => sum + (item.energyQuantityKwh ?? 0)),
    energySoldKwh: transactions
        .where((item) => item.type == WalletTransactionType.energySale)
        .fold<double>(
            0, (sum, item) => sum + (item.energyQuantityKwh ?? 0)),
  );
}

Wallet _walletFromResponse(Map data) {
  return Wallet(
    userId: data['userId']?.toString() ?? data['user_id']?.toString() ?? '',
    availableBalancePaise:
        ((data['availableBalancePaise'] ?? data['available_balance_paise']) as num).toInt(),
    pendingBalancePaise:
        ((data['pendingBalancePaise'] ?? data['pending_balance_paise']) as num).toInt(),
    escrowHeldBalancePaise:
        ((data['escrowHeldBalancePaise'] ?? data['escrow_held_balance_paise']) as num).toInt(),
    totalEarnedPaise:
        ((data['totalEarnedPaise'] ?? data['total_earned_paise']) as num).toInt(),
    totalSpentPaise:
        ((data['totalSpentPaise'] ?? data['total_spent_paise']) as num).toInt(),
    totalWithdrawnPaise:
        ((data['totalWithdrawnPaise'] ?? data['total_withdrawn_paise']) as num).toInt(),
    totalAddedPaise:
        ((data['totalAddedPaise'] ?? data['total_added_paise']) as num).toInt(),
    currency: data['currency']?.toString() ?? 'Rs',
    updatedAt: _parseDateTime(
        data['updatedAt'] ?? data['updated_at'] ?? DateTime.now().toIso8601String()),
  );
}

WalletTransaction _transactionFromResponse(Map data) {
  return WalletTransaction(
    id: data['id'].toString(),
    userId: data['userId']?.toString() ?? data['user_id']?.toString() ?? '',
    type: _parseTransactionType(
        data['type']?.toString() ?? 'energyPurchase'),
    status: _parseTransactionStatus(
        data['status']?.toString() ?? 'completed'),
    amountPaise: (data['amountPaise'] ?? data['amount_paise'] ?? 0) as int,
    reference: data['reference']?.toString() ?? '',
    description: data['description']?.toString() ?? '',
    createdAt: _parseDateTime(
        data['createdAt'] ?? data['created_at'] ?? DateTime.now().toIso8601String()),
    completedAt: data['completedAt'] != null
        ? _parseDateTime(data['completedAt'])
        : data['completed_at'] != null
            ? _parseDateTime(data['completed_at'])
            : null,
    energyQuantityKwh:
        (data['energyQuantityKwh'] ?? data['energy_quantity_kwh']) as double?,
    unitPricePaise:
        (data['unitPricePaise'] ?? data['unit_price_paise']) as int?,
    platformFeePaise:
        ((data['platformFeePaise'] ?? data['platform_fee_paise']) as num?)?.toInt() ?? 0,
    counterpartyId: data['counterpartyId']?.toString() ?? data['counterparty_id']?.toString(),
    counterpartyName: data['counterpartyName']?.toString() ?? data['counterparty_name']?.toString(),
    marketplaceListingId: data['marketplaceListingId']?.toString() ?? data['marketplace_listing_id']?.toString(),
    energyPurchaseId: data['energyPurchaseId']?.toString() ?? data['energy_purchase_id']?.toString(),
    escrowId: data['escrowId']?.toString() ?? data['escrow_id']?.toString(),
    escrowStatusLabel: data['escrowStatusLabel']?.toString() ?? data['escrow_status_label']?.toString(),
    refundedTransactionId: data['refundedTransactionId']?.toString() ?? data['refunded_transaction_id']?.toString(),
  );
}

WalletTransactionType _parseTransactionType(String value) {
  for (final type in WalletTransactionType.values) {
    if (type.name == value ||
        type.name.toLowerCase() == value.toLowerCase()) {
      return type;
    }
  }
  return WalletTransactionType.energyPurchase;
}

WalletTransactionStatus _parseTransactionStatus(String value) {
  for (final status in WalletTransactionStatus.values) {
    if (status.name == value ||
        status.name.toLowerCase() == value.toLowerCase()) {
      return status;
    }
  }
  return WalletTransactionStatus.completed;
}

DateTime _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
