import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
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

  String get grossRevenueInr => '\u20b9${(grossRevenuePaise / 100).toStringAsFixed(2)}';
  String get netRevenueInr => '\u20b9${(netRevenuePaise / 100).toStringAsFixed(2)}';
  String get pendingSettlementInr => '\u20b9${(pendingSettlementPaise / 100).toStringAsFixed(2)}';
  String get settledAmountInr => '\u20b9${(settledAmountPaise / 100).toStringAsFixed(2)}';

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
    final itemsList = (json['items'] as List<Object?>?)
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
    (s) => s.name == statusName || s.name.toLowerCase() == statusName.toLowerCase(),
    orElse: () => PurchaseStatus.completed,
  );
  return EnergyPurchase(
    id: data['id']?.toString() ?? '',
    listingId: data['listingId']?.toString() ?? data['listing_id']?.toString() ?? '',
    buyerId: data['buyerId']?.toString() ?? data['buyer_id']?.toString() ?? '',
    sellerId: data['sellerId']?.toString() ?? data['seller_id']?.toString() ?? '',
    sellerName: data['sellerName']?.toString() ?? data['seller_name']?.toString(),
    listingTitle: data['listingTitle']?.toString() ?? data['listing_title']?.toString(),
    quantityKwh: (data['quantityKwh'] ?? data['quantity_kwh'] ?? 0).toDouble(),
    unitPrice: (data['unitPrice'] ?? data['unit_price'] ?? 0).toDouble(),
    platformFee: (data['platformFee'] ?? data['platform_fee'] ?? 0).toDouble(),
    totalAmount: (data['totalAmount'] ?? data['total_amount'] ?? 0).toDouble(),
    estimatedSavings: (data['estimatedSavings'] ?? data['estimated_savings'] ?? 0).toDouble(),
    co2ImpactKg: (data['co2ImpactKg'] ?? data['co2_impact_kg'] ?? 0).toDouble(),
    purchasedAt: DateTime.tryParse(
      data['purchasedAt']?.toString() ?? data['purchased_at']?.toString() ?? '',
    ) ?? DateTime.now(),
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
  if (ref.watch(appConfigProvider).isLiveMode) {
    return SalesApiRepository(ref.watch(apiClientProvider));
  }
  return SalesMockRepository();
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

/// Deterministic mock implementation.
class SalesMockRepository implements SalesRepository {
  SalesMockRepository();

  @override
  Future<ProducerSalesPage> getSales({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final all = _getMockSales(now);
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
      filtered = all.where((s) =>
        (s.listingTitle?.toLowerCase().contains(lower) ?? false) ||
        s.id.toLowerCase().contains(lower)
      ).toList();
    }

    final total = filtered.length;
    final totalPages = (total + pageSize - 1) ~/ pageSize;
    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();

    final totalKwh = filtered.fold(0.0, (sum, s) => sum + s.quantityKwh);
    final gross = (totalKwh * 7.5 * 100).round();
    final fees = (gross * 0.05).round();

    return ProducerSalesPage(
      items: items,
      summary: ProducerSaleSummary(
        totalSales: total,
        completedSales: filtered.where((s) => s.status == PurchaseStatus.completed).length,
        pendingSales: filtered.where((s) => s.status == PurchaseStatus.confirmed || s.status == PurchaseStatus.pending).length,
        cancelledOrFailedSales: filtered.where((s) => s.status == PurchaseStatus.cancelled || s.status == PurchaseStatus.failed).length,
        energySoldKwh: totalKwh,
        grossRevenuePaise: gross,
        platformFeesPaise: fees,
        netRevenuePaise: gross - fees,
        pendingSettlementPaise: (gross * 0.3).round(),
        settledAmountPaise: (gross * 0.6).round(),
      ),
      page: page,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<EnergyPurchase> getSaleDetails(String saleId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final sale = _getMockSales(DateTime.now()).where((s) => s.id == saleId).firstOrNull;
    if (sale == null) throw ApiException(code: 'HTTP_404', message: 'Sale not found');
    return sale;
  }

  List<EnergyPurchase> _getMockSales(DateTime now) {
    return [
      EnergyPurchase(
        id: 'SALE-MOCK-001', listingId: 'lst-prod-001',
        buyerId: 'consumer-001', sellerId: 'producer-001',
        sellerName: 'Chandra Devi', listingTitle: 'Solar Surplus — Kochi',
        quantityKwh: 12.5, unitPrice: 5.80, platformFee: 3.62, totalAmount: 72.50,
        estimatedSavings: 18.75, co2ImpactKg: 8.75,
        purchasedAt: now.subtract(const Duration(hours: 2)), status: PurchaseStatus.completed,
      ),
      EnergyPurchase(
        id: 'SALE-MOCK-002', listingId: 'lst-prod-001',
        buyerId: 'consumer-002', sellerId: 'producer-001',
        sellerName: 'Chandra Devi', listingTitle: 'Solar Surplus — Kochi',
        quantityKwh: 8.0, unitPrice: 5.80, platformFee: 2.32, totalAmount: 46.40,
        estimatedSavings: 12.00, co2ImpactKg: 5.60,
        purchasedAt: now.subtract(const Duration(hours: 6)), status: PurchaseStatus.completed,
      ),
      EnergyPurchase(
        id: 'SALE-MOCK-003', listingId: 'lst-prod-002',
        buyerId: 'extra-001', sellerId: 'producer-001',
        sellerName: 'Chandra Devi', listingTitle: 'Wind Energy — Idukki',
        quantityKwh: 15.0, unitPrice: 5.20, platformFee: 3.90, totalAmount: 78.00,
        estimatedSavings: 22.50, co2ImpactKg: 10.50,
        purchasedAt: now.subtract(const Duration(days: 1)), status: PurchaseStatus.completed,
      ),
      EnergyPurchase(
        id: 'SALE-MOCK-004', listingId: 'lst-prod-001',
        buyerId: 'consumer-001', sellerId: 'producer-001',
        sellerName: 'Chandra Devi', listingTitle: 'Solar Surplus — Kochi',
        quantityKwh: 5.0, unitPrice: 6.20, platformFee: 1.55, totalAmount: 31.00,
        estimatedSavings: 7.50, co2ImpactKg: 3.50,
        purchasedAt: now.subtract(const Duration(days: 2)), status: PurchaseStatus.confirmed,
      ),
      EnergyPurchase(
        id: 'SALE-MOCK-005', listingId: 'lst-prod-003',
        buyerId: 'consumer-002', sellerId: 'producer-002',
        sellerName: 'Deepak Menon', listingTitle: 'Hydro Power — Thrissur',
        quantityKwh: 20.0, unitPrice: 4.50, platformFee: 4.50, totalAmount: 90.00,
        estimatedSavings: 30.00, co2ImpactKg: 14.00,
        purchasedAt: now.subtract(const Duration(hours: 12)), status: PurchaseStatus.completed,
      ),
      EnergyPurchase(
        id: 'SALE-MOCK-006', listingId: 'lst-prod-003',
        buyerId: 'extra-001', sellerId: 'producer-002',
        sellerName: 'Deepak Menon', listingTitle: 'Hydro Power — Thrissur',
        quantityKwh: 10.0, unitPrice: 4.50, platformFee: 2.25, totalAmount: 45.00,
        estimatedSavings: 15.00, co2ImpactKg: 7.00,
        purchasedAt: now.subtract(const Duration(days: 3)), status: PurchaseStatus.cancelled,
      ),
      EnergyPurchase(
        id: 'SALE-MOCK-007', listingId: 'lst-prod-002',
        buyerId: 'extra-002', sellerId: 'producer-001',
        sellerName: 'Chandra Devi', listingTitle: 'Wind Energy — Idukki',
        quantityKwh: 3.5, unitPrice: 5.20, platformFee: 0.91, totalAmount: 18.20,
        estimatedSavings: 5.25, co2ImpactKg: 2.45,
        purchasedAt: now.subtract(const Duration(days: 5)), status: PurchaseStatus.pending,
      ),
    ];
  }
}
