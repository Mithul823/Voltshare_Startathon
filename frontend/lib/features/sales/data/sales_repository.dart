import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../authentication/data/auth_repository.dart';
import '../../marketplace/data/mock_backend_store.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../marketplace/domain/marketplace_filter.dart';

/// Producer sale summary with aggregated financial data.
class ProducerSaleSummary {
  const ProducerSaleSummary({
    this.totalSales = 0,
    this.completedSales = 0,
    this.pendingSales = 0,
    this.cancelledOrFailedSales = 0,
    this.energySoldKwh = 0.0,
    this.grossRevenuePaise = 0,
    this.platformFeesPaise = 0,
    this.netRevenuePaise = 0,
    this.pendingSettlementPaise = 0,
    this.settledAmountPaise = 0,
  });

  factory ProducerSaleSummary.fromJson(Map<String, Object?> json) {
    return ProducerSaleSummary(
      totalSales: _int(json['total_sales']),
      completedSales: _int(json['completed_sales']),
      pendingSales: _int(json['pending_sales']),
      cancelledOrFailedSales: _int(json['cancelled_or_failed_sales']),
      energySoldKwh: _dbl(json['energy_sold_kwh']),
      grossRevenuePaise: _int(json['gross_revenue_paise']),
      platformFeesPaise: _int(json['platform_fees_paise']),
      netRevenuePaise: _int(json['net_revenue_paise']),
      pendingSettlementPaise: _int(json['pending_settlement_paise']),
      settledAmountPaise: _int(json['settled_amount_paise']),
    );
  }

  final int totalSales;
  final int completedSales;
  final int pendingSales;
  final int cancelledOrFailedSales;
  final double energySoldKwh;
  final int grossRevenuePaise;
  final int platformFeesPaise;
  final int netRevenuePaise;
  final int pendingSettlementPaise;
  final int settledAmountPaise;

  String get grossRevenueInr =>
      '\u20b9${(grossRevenuePaise / 100).toStringAsFixed(2)}';
  String get netRevenueInr =>
      '\u20b9${(netRevenuePaise / 100).toStringAsFixed(2)}';
  String get pendingSettlementInr =>
      '\u20b9${(pendingSettlementPaise / 100).toStringAsFixed(2)}';
  String get settledAmountInr =>
      '\u20b9${(settledAmountPaise / 100).toStringAsFixed(2)}';

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
  static double _dbl(Object? v) => (v is num) ? v.toDouble() : 0.0;
}

/// Paginated sales response.
class ProducerSalesPage {
  const ProducerSalesPage({
    this.items = const [],
    this.summary = const ProducerSaleSummary(),
    this.page = 1,
    this.pageSize = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  factory ProducerSalesPage.fromJson(Map<String, Object?> json) {
    final itemsList =
        (json['items'] as List<Object?>?)
            ?.map((e) => _parsePurchase(e as Map<String, Object?>))
            .toList() ??
        [];
    return ProducerSalesPage(
      items: itemsList,
      summary: ProducerSaleSummary.fromJson(
        (json['summary'] as Map<String, Object?>?) ?? const {},
      ),
      page: _int(json['page']),
      pageSize: _int(json['page_size']),
      total: _int(json['total']),
      totalPages: _int(json['total_pages']),
    );
  }

  final List<EnergyPurchase> items;
  final ProducerSaleSummary summary;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty && total == 0;

  static int _int(Object? v) => (v is num) ? v.toInt() : 0;
}

EnergyPurchase _parsePurchase(Map data) {
  final statusName = data['status']?.toString() ?? 'confirmed';
  final parsedStatus = PurchaseStatus.values.firstWhere(
    (s) => s.name.toLowerCase() == statusName.toLowerCase(),
    orElse: () => PurchaseStatus.completed,
  );
  return EnergyPurchase(
    id: data['id']?.toString() ?? '',
    listingId:
        data['listingId']?.toString() ?? data['listing_id']?.toString() ?? '',
    buyerId:
        data['buyerId']?.toString() ??
        data['buyer_id']?.toString() ??
        data['consumerId']?.toString() ??
        data['consumer_id']?.toString() ??
        '',
    sellerId:
        data['sellerId']?.toString() ??
        data['seller_id']?.toString() ??
        data['producerId']?.toString() ??
        data['producer_id']?.toString() ??
        '',
    sellerName:
        data['sellerName']?.toString() ??
        data['seller_name']?.toString() ??
        'Energy Producer',
    listingTitle:
        data['listingTitle']?.toString() ??
        data['listing_title']?.toString() ??
        'Clean Energy',
    quantityKwh: (data['quantityKwh'] ?? data['quantity_kwh'] ?? 0).toDouble(),
    unitPrice: (data['unitPrice'] ?? data['unit_price'] ?? 0).toDouble(),
    platformFee: (data['platformFee'] ?? data['platform_fee'] ?? 0).toDouble(),
    totalAmount: (data['totalAmount'] ?? data['total_amount'] ?? 0).toDouble(),
    estimatedSavings:
        (data['estimatedSavings'] ?? data['estimated_savings'] ?? 0).toDouble(),
    co2ImpactKg: (data['co2ImpactKg'] ?? data['co2_impact_kg'] ?? 0).toDouble(),
    purchasedAt:
        DateTime.tryParse(
          data['purchasedAt']?.toString() ??
              data['purchased_at']?.toString() ??
              data['createdAt']?.toString() ??
              data['created_at']?.toString() ??
              '',
        ) ??
        DateTime.now(),
    status: parsedStatus,
  );
}

/// Repository for producer sales operations.
abstract class SalesRepository {
  Future<ProducerSalesPage> getSales({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<EnergyPurchase> getSaleDetails(String saleId);
}

/// Provider that selects mock or live repository.
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  ref.watch(currentProfileProvider);
  ref.watch(currentSessionProvider);
  if (ref.watch(appConfigProvider).isLiveMode) {
    return SalesApiRepository(ref.watch(apiClientProvider));
  }
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  final session = ref.watch(currentSessionProvider);
  final userId = profile?.id ?? session?.user.id ?? 'producer-1';
  return SalesMockRepository(sellerId: userId);
});

/// Live API implementation.
class SalesApiRepository implements SalesRepository {
  SalesApiRepository(this._client);

  final ApiClient _client;

  @override
  Future<ProducerSalesPage> getSales({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final data = await _client.get('/users/me/sales', query: queryParams);
    return ProducerSalesPage.fromJson(data as Map<String, Object?>);
  }

  @override
  Future<EnergyPurchase> getSaleDetails(String saleId) async {
    final data = await _client.get('/users/me/sales/$saleId');
    return _parsePurchase(data as Map<String, Object?>);
  }
}

/// Deterministic mock implementation backed by centralized [MockBackendStore].
class SalesMockRepository implements SalesRepository {
  SalesMockRepository({this.sellerId = '', MockBackendStore? store})
    : _store = store ?? MockBackendStore();

  final String sellerId;
  final MockBackendStore _store;

  @override
  Future<ProducerSalesPage> getSales({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _store.seed();
    final raw = sellerId.isNotEmpty
        ? _store.getPurchasesBySeller(sellerId)
        : _store.purchases;
    final all = raw.map((item) => _parsePurchase(item)).toList();
    var filtered = all;

    if (status != null) {
      final filterStatus = PurchaseStatus.values.firstWhere(
        (s) => s.name == status || s.name.toLowerCase() == status.toLowerCase(),
        orElse: () => PurchaseStatus.completed,
      );
      filtered = all.where((s) => s.status == filterStatus).toList();
    }
    if (search != null && search.isNotEmpty) {
      final lower = search.toLowerCase();
      filtered = all
          .where(
            (s) =>
                (s.listingTitle?.toLowerCase().contains(lower) ?? false) ||
                s.id.toLowerCase().contains(lower) ||
                (s.buyerName?.toLowerCase().contains(lower) ?? false) ||
                s.buyerId.toLowerCase().contains(lower),
          )
          .toList();
    }

    final total = filtered.length;
    final totalPages = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();

    final totalKwh = filtered.fold(0.0, (sum, s) => sum + s.quantityKwh);
    final totalRevenue = filtered.fold(0.0, (sum, s) => sum + s.totalAmount);
    final gross = (totalRevenue * 100).round();
    final fees = (gross * 0.03).round();

    return ProducerSalesPage(
      items: items,
      summary: ProducerSaleSummary(
        totalSales: total,
        completedSales: filtered
            .where((s) => s.status == PurchaseStatus.completed)
            .length,
        pendingSales: filtered
            .where(
              (s) =>
                  s.status == PurchaseStatus.confirmed ||
                  s.status == PurchaseStatus.pending,
            )
            .length,
        cancelledOrFailedSales: filtered
            .where(
              (s) =>
                  s.status == PurchaseStatus.cancelled ||
                  s.status == PurchaseStatus.failed,
            )
            .length,
        energySoldKwh: totalKwh,
        grossRevenuePaise: gross,
        platformFeesPaise: fees,
        netRevenuePaise: gross - fees,
        pendingSettlementPaise: (gross * 0.3).round(),
        settledAmountPaise: (gross * 0.7).round(),
      ),
      page: page,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<EnergyPurchase> getSaleDetails(String saleId) async {
    await Future.delayed(const Duration(milliseconds: 80));
    _store.seed();
    final raw = _store.purchases.where((s) => s['id'] == saleId).firstOrNull;
    if (raw == null) {
      throw ApiException(code: 'HTTP_404', message: 'Sale not found');
    }
    return _parsePurchase(raw);
  }
}
